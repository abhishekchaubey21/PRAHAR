/**
 * PRAHAR Rover Simulator — HTTP & SSE REST Server
 * Provides standard integration endpoints for the rover gateway, decision engine, and consoles.
 * Built with native Node.js HTTP for zero-dependency reliability.
 */

import http from 'node:http';
import { RoverEngine } from './engine.js';
import { PersistentAlertStore } from './persistent-alert-store.js';
import { SyncEngine } from './sync-engine.js';
import { DecisionEngine } from './decision-engine.js';
import { ClosedLoopCoordinator } from './closed-loop.js';
import { RoverCommand, RoverScanPayload, SyncBatchRequest } from '@prahar/shared';

const PORT = parseInt(process.env.PORT || '3001', 10);

const engine = new RoverEngine({
  roverId: process.env.ROVER_ID || 'ROVER-DEMO-01',
  initialBattery: 96.0,
});

const alertStore = new PersistentAlertStore();
const syncEngine = new SyncEngine();
const decisionEngine = new DecisionEngine(alertStore);
const closedLoop = new ClosedLoopCoordinator(engine, decisionEngine, alertStore);

function parseJsonBody(req: http.IncomingMessage): Promise<any> {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 1e6) {
        req.destroy();
        reject(new Error('Payload too large'));
      }
    });
    req.on('end', () => {
      if (!body) return resolve({});
      try {
        resolve(JSON.parse(body));
      } catch (err) {
        reject(new Error('Invalid JSON payload'));
      }
    });
    req.on('error', reject);
  });
}

function sendJson(res: http.ServerResponse, statusCode: number, data: any): void {
  const payload = JSON.stringify(data, null, 2);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  });
  res.end(payload);
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname;
  const method = req.method?.toUpperCase();

  // Handle CORS Preflight
  if (method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    });
    return res.end();
  }

  try {
    // ------------------------------------------------------------------------
    // Core Simulator Endpoints (Phase 1)
    // ------------------------------------------------------------------------
    if (pathname === '/api/rover/status' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        data: engine.getStatus(),
      });
    }

    if (pathname === '/api/rover/telemetry/latest' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        data: engine.getTelemetry(),
      });
    }

    if (pathname === '/api/rover/command' && method === 'POST') {
      const body = await parseJsonBody(req);
      const command: RoverCommand = {
        command_id: body.command_id || `cmd-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
        rover_id: body.rover_id || engine.getRoverId(),
        command_type: body.command_type,
        payload: body.payload || {},
        issued_at: body.issued_at || new Date().toISOString(),
      };

      const ack = await engine.executeCommand(command);
      const statusCode = ack.status === 'REJECTED' ? 400 : ack.status === 'FAILED' ? 500 : 200;
      return sendJson(res, statusCode, {
        success: ack.status === 'COMPLETED' || ack.status === 'ACKNOWLEDGED',
        data: ack,
      });
    }

    if (pathname === '/api/rover/offline-mode' && method === 'POST') {
      const body = await parseJsonBody(req);
      const enabled = Boolean(body.enabled);
      engine.setOfflineMode(enabled);
      return sendJson(res, 200, {
        success: true,
        message: `Rover offline mode set to: ${enabled}`,
        offline_mode: enabled,
        buffered_count: engine.offlineStore.getCount(),
      });
    }

    if (pathname === '/api/rover/queue' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        buffered_count: engine.offlineStore.getCount(),
        events: engine.offlineStore.peekAll(),
      });
    }

    if (pathname === '/api/rover/flush-queue' && method === 'POST') {
      const flushed = engine.flushOfflineQueue();
      return sendJson(res, 200, {
        success: true,
        flushed_count: flushed.length,
        events: flushed,
      });
    }

    if (pathname === '/api/rover/simulate-scan' && method === 'POST') {
      const body = await parseJsonBody(req);
      const zoneId = body.zone_id || engine.getCurrentZoneId();
      const isReScan = Boolean(body.is_rescan);
      const scanPayload = engine.simulateScanCycle(zoneId, isReScan);
      return sendJson(res, 200, {
        success: true,
        data: scanPayload,
      });
    }

    if (pathname === '/api/rover/recharge' && method === 'POST') {
      const body = await parseJsonBody(req);
      const target = body.target_pct !== undefined ? Number(body.target_pct) : 100.0;
      engine.recharge(target);
      return sendJson(res, 200, {
        success: true,
        battery_pct: engine.getBatteryPct(),
      });
    }

    if (pathname === '/api/rover/telemetry-stream' && method === 'GET') {
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
        'Access-Control-Allow-Origin': '*',
      });
      res.write(': connected\n\n');

      const interval = setInterval(() => {
        const telemetry = engine.getTelemetry();
        res.write(`data: ${JSON.stringify(telemetry)}\n\n`);
      }, 3000);

      req.on('close', () => {
        clearInterval(interval);
        res.end();
      });
      return;
    }

    // ------------------------------------------------------------------------
    // Phase 2: Ingestion & Decision Layer Endpoints
    // ------------------------------------------------------------------------

    // Ingest Scan Payload -> Runs Decision Engine
    if (pathname === '/api/ingest/scan' && method === 'POST') {
      const body = await parseJsonBody(req);
      let payload: RoverScanPayload = body;

      // If no payload passed, trigger simulated scan on requested or current zone
      if (!payload || !payload.scan_id) {
        payload = engine.simulateScanCycle(body.zone_id || engine.getCurrentZoneId(), false);
      }

      const result = await closedLoop.ingestScan(payload);
      return sendJson(res, 200, {
        success: true,
        data: result,
      });
    }

    // List Alerts (with bilingual support & filters)
    if (pathname === '/api/alerts' && method === 'GET') {
      const zoneId = url.searchParams.get('zone_id') || undefined;
      const status = (url.searchParams.get('status') as any) || undefined;
      const alerts = await alertStore.getAlerts({ zone_id: zoneId, status });
      return sendJson(res, 200, {
        success: true,
        count: alerts.length,
        data: alerts,
      });
    }

    // Expert Triage Action on an Alert (Requirement 5)
    if (pathname.startsWith('/api/alerts/') && pathname.endsWith('/triage') && method === 'POST') {
      const parts = pathname.split('/');
      const alertId = parts[3];
      const body = await parseJsonBody(req);

      const alert = await alertStore.getAlertById(alertId);
      if (!alert) {
        return sendJson(res, 404, { success: false, error: `Alert '${alertId}' not found.` });
      }

      const previousState = alert.status;
      const action = body.action || 'CONFIRM'; // 'CONFIRM' | 'CORRECT' | 'ESCALATE'
      const actor = body.actor || 'expert-agronomist-01';
      const expertNote = body.expert_note || 'Expert reviewed diagnosis.';

      if (action === 'CONFIRM') {
        alert.status = 'ACKNOWLEDGED';
      } else if (action === 'CORRECT') {
        if (body.corrected_hazard) {
          alert.message += ` (Corrected to: ${body.corrected_hazard})`;
        }
        alert.status = 'ACKNOWLEDGED';
      } else if (action === 'ESCALATE') {
        alert.severity = 'CRITICAL';
        alert.status = 'ACKNOWLEDGED';
      }

      await alertStore.updateAlert(alert);

      // Audit log
      alertStore.recordAudit({
        audit_id: `audit-${Date.now().toString(36)}`,
        actor,
        timestamp: new Date().toISOString(),
        zone_id: alert.zone_id,
        alert_id: alert.alert_id,
        action,
        previous_state: previousState,
        new_state: alert.status,
        expert_note: expertNote,
      });

      return sendJson(res, 200, {
        success: true,
        message: `Alert '${alertId}' triaged with action '${action}'.`,
        alert,
      });
    }

    // ------------------------------------------------------------------------
    // Phase 2: Closed-Loop Intervention & Verification Endpoints
    // ------------------------------------------------------------------------

    // Approve Intervention (Safety Gate)
    if (pathname === '/api/remediation/approve' && method === 'POST') {
      const body = await parseJsonBody(req);
      try {
        const intervention = closedLoop.approveIntervention({
          zone_id: body.zone_id,
          approved_by: body.approved_by || 'farmer_demo',
          duration_seconds: body.duration_seconds,
          volume_liters: body.volume_liters,
          expert_note: body.expert_note,
        });

        return sendJson(res, 200, {
          success: true,
          message: 'Intervention approved. Ready for execution.',
          data: intervention,
        });
      } catch (err: any) {
        return sendJson(res, 400, {
          success: false,
          error: err.message,
        });
      }
    }

    // Execute Approved Intervention
    if (pathname === '/api/remediation/execute' && method === 'POST') {
      const body = await parseJsonBody(req);
      try {
        const ack = await closedLoop.executeApprovedIntervention(body.action_id);
        const statusCode = ack.status === 'REJECTED' ? 400 : ack.status === 'FAILED' ? 500 : 200;
        return sendJson(res, statusCode, {
          success: ack.status === 'COMPLETED',
          data: ack,
        });
      } catch (err: any) {
        return sendJson(res, 400, {
          success: false,
          error: err.message,
        });
      }
    }

    // Verify Remediation (Re-Scan & Before/After Delta)
    if (pathname === '/api/remediation/verify' && method === 'POST') {
      const body = await parseJsonBody(req);
      try {
        const verification = await closedLoop.verifyIntervention(body.action_id);
        return sendJson(res, 200, {
          success: true,
          data: verification,
        });
      } catch (err: any) {
        return sendJson(res, 400, {
          success: false,
          error: err.message,
        });
      }
    }

    // List All Verifications
    if (pathname === '/api/remediation/verifications' && method === 'GET') {
      const zoneId = url.searchParams.get('zone_id') || undefined;
      const records = closedLoop.getVerificationRecords(zoneId);
      return sendJson(res, 200, {
        success: true,
        count: records.length,
        data: records,
      });
    }

    // Audit Trail
    if (pathname === '/api/audit/history' && method === 'GET') {
      const alertId = url.searchParams.get('alert_id') || undefined;
      const zoneId = url.searchParams.get('zone_id') || undefined;
      const history = alertStore.getAuditHistory({ alert_id: alertId, zone_id: zoneId });
      return sendJson(res, 200, {
        success: true,
        count: history.length,
        data: history,
      });
    }

    // ------------------------------------------------------------------------
    // Phase 3: Production Data Layer & Offline Sync Endpoints
    // ------------------------------------------------------------------------

    // Ingest Offline Sync Batch (Idempotent & Conflict-aware)
    if (pathname === '/api/sync/push' && method === 'POST') {
      const body = await parseJsonBody(req);
      const batch: SyncBatchRequest = {
        client_id: body.client_id || 'ROVER-LOCAL-CLIENT',
        records: body.records || [],
        strategy: body.strategy || 'LAST_WRITE_WINS',
      };
      const result = syncEngine.processBatch(batch);
      return sendJson(res, 200, result);
    }

    // Inspect Sync Queue Status
    if (pathname === '/api/sync/status' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        data: syncEngine.getStatus(),
      });
    }

    // Inspect Failed Sync Events
    if (pathname === '/api/sync/failed' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        failed_events: syncEngine.getFailedEvents(),
      });
    }

    // Manual Retry of Failed Sync Events
    if (pathname === '/api/sync/retry' && method === 'POST') {
      const retriedCount = syncEngine.retryFailed();
      return sendJson(res, 200, {
        success: true,
        retried_count: retriedCount,
        queue_status: syncEngine.getStatus(),
      });
    }

    // Flush/Drain Queue
    if (pathname === '/api/sync/flush' && method === 'POST') {
      const flushResult = await syncEngine.flushQueue();
      return sendJson(res, 200, {
        success: true,
        data: flushResult,
      });
    }

    // Authenticated Profile (Farmer / Expert / Admin)
    if (pathname === '/api/auth/profile' && method === 'GET') {
      const role = url.searchParams.get('role') || 'FARMER';
      const isFarmer = role.toUpperCase() === 'FARMER';
      return sendJson(res, 200, {
        success: true,
        profile: {
          id: isFarmer ? 'usr-demo-farmer-01' : 'usr-demo-expert-01',
          role: isFarmer ? 'FARMER' : 'EXPERT',
          full_name: isFarmer ? 'Ramesh Kumar (रामेश कुमार)' : 'Dr. S. Sharma (KVK Agronomist)',
          farmer_id: isFarmer ? 'farmer-demo-01' : null,
          assigned_cluster: 'CLUSTER-DEMO-01',
          preferred_language: isFarmer ? 'hi' : 'en',
          authorized_farms: ['FARM-DEMO-01'],
          authorized_zones: ['ZONE-A1', 'DEMO-ZONE-02', 'DEMO-ZONE-03', 'DEMO-ZONE-04'],
        },
      });
    }

    // Farms List
    if (pathname === '/api/farms' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        farms: [
          {
            id: 'FARM-DEMO-01',
            farmer_id: 'farmer-demo-01',
            name: 'Kisan Demo Farm Alpha (डेमो खेत अल्फा)',
            crop_type: 'Tomato (टमाटर)',
            area_acres: 3.5,
            zones_count: 4,
            created_at: '2026-09-01T00:00:00Z',
          },
        ],
      });
    }

    // Zones List with Health Status
    if (pathname === '/api/zones' && method === 'GET') {
      const farmId = url.searchParams.get('farm_id') || 'FARM-DEMO-01';
      return sendJson(res, 200, {
        success: true,
        farm_id: farmId,
        zones: [
          {
            id: 'ZONE-A1',
            name: 'Zone 1 (North Plot)',
            soil_type: 'Clay Loam',
            last_moisture: 32.5,
            status: 'OPTIMAL',
            last_scan_at: new Date(Date.now() - 3600000).toISOString(),
          },
          {
            id: 'DEMO-ZONE-02',
            name: 'Zone 2 (East Sector)',
            soil_type: 'Sandy Loam',
            last_moisture: 17.5,
            status: 'WATER_STRESS',
            last_scan_at: new Date(Date.now() - 900000).toISOString(),
          },
          {
            id: 'DEMO-ZONE-03',
            name: 'Zone 3 (South Sector)',
            soil_type: 'Loam',
            last_moisture: 28.0,
            status: 'DISEASE_SUSPECTED',
            last_scan_at: new Date(Date.now() - 2700000).toISOString(),
          },
          {
            id: 'DEMO-ZONE-04',
            name: 'Zone 4 (West Sector)',
            soil_type: 'Loam',
            last_moisture: 34.0,
            status: 'OPTIMAL',
            last_scan_at: new Date(Date.now() - 7200000).toISOString(),
          },
        ],
      });
    }

    // 404 Fallback
    return sendJson(res, 404, {
      success: false,
      error: `Endpoint not found: ${method} ${pathname}`,
    });
  } catch (err: any) {
    return sendJson(res, 500, {
      success: false,
      error: err?.message || 'Internal Server Error',
    });
  }
});

server.listen(PORT, () => {
  console.log(`[PRAHAR Rover Simulator & Decision Gateway v0.3] Online`);
  console.log(`Rover ID: ${engine.getRoverId()}`);
  console.log(`HTTP Server listening on http://localhost:${PORT}`);
  console.log(`Phase 3 Production & Offline Sync Endpoints:`);
  console.log(`  POST /api/sync/push`);
  console.log(`  GET  /api/sync/status`);
  console.log(`  POST /api/sync/retry`);
  console.log(`  GET  /api/auth/profile`);
  console.log(`  GET  /api/farms`);
  console.log(`  GET  /api/zones`);
});

export { server, engine, alertStore, syncEngine, decisionEngine, closedLoop };
