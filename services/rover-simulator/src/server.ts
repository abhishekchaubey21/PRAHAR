/**
 * PRAHAR Rover Simulator — HTTP & SSE REST Server
 * Provides standard integration endpoints for the rover gateway, decision engine, and consoles.
 * Built with native Node.js HTTP for zero-dependency reliability.
 * Aligned with Phase 5A: Real Supabase Auth, JWT Verification, Role Enforcement & Simulator Security Boundary.
 */

import http from 'node:http';
import { RoverEngine } from './engine.js';
import { PersistentAlertStore } from './persistent-alert-store.js';
import { ResilientDataStore } from './resilient-store.js';
import { SyncEngine } from './sync-engine.js';
import { DecisionEngine } from './decision-engine.js';
import { ClosedLoopCoordinator } from './closed-loop.js';
import { WeatherRiskEngine } from './weather-provider.js';
import { ExplainabilityEngine } from './explainability-engine.js';
import { VoiceAssistant } from './voice-assistant.js';
import { MultimodalAssistant } from './multimodal-assistant.js';
import { HistoricalAnalytics } from './historical-analytics.js';
import { FieldEvidenceReportGenerator, OpportunityCenter } from './reports-and-opportunities.js';
import { AuthService } from './auth-service.js';
import { createUserScopedClient, getServiceRoleClient, isSupabaseConfigured } from './supabase-client.js';
import {
  authenticateRequest,
  enforceRole,
  authenticateRoverIngestion,
  extractBearerToken,
  AuthenticatedRequest,
} from './auth-middleware.js';
import {
  loadConfig,
  RoverCommand,
  RoverScanPayload,
  SyncBatchRequest,
  VoiceQuery,
  MultimodalAnalysisRequest,
  RegisterFarmerRequest,
  LoginRequest,
} from '@prahar/shared';

const config = loadConfig();
const PORT = config.port;

const engine = new RoverEngine({
  roverId: process.env.ROVER_ID || 'ROVER-DEMO-01',
  initialBattery: 96.0,
});

const alertStore = new PersistentAlertStore();
const resilientStore = new ResilientDataStore(alertStore);
const authService = new AuthService();
const syncEngine = new SyncEngine();
const decisionEngine = new DecisionEngine(resilientStore);
const closedLoop = new ClosedLoopCoordinator(engine, decisionEngine, resilientStore);
const weatherRiskEngine = new WeatherRiskEngine();
const explainabilityEngine = new ExplainabilityEngine();
const voiceAssistant = new VoiceAssistant(resilientStore, closedLoop);
const multimodalAssistant = new MultimodalAssistant();
const historicalAnalytics = new HistoricalAnalytics(resilientStore);

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

function sendJson(
  res: http.ServerResponse,
  statusCode: number,
  data: any,
  originHeader?: string
): void {
  const payload = JSON.stringify(data, null, 2);
  const corsOrigin =
    originHeader && config.allowedOrigins.includes(originHeader)
      ? originHeader
      : config.allowedOrigins[0] || '*';

  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
    'Access-Control-Allow-Origin': corsOrigin,
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Rover-Api-Key',
  });
  res.end(payload);
}

const server = http.createServer(async (rawReq, res) => {
  const req = rawReq as AuthenticatedRequest;
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);
  const pathname = url.pathname;
  const method = req.method?.toUpperCase();
  const originHeader = req.headers.origin;

  // Handle CORS Preflight
  if (method === 'OPTIONS') {
    const corsOrigin =
      originHeader && config.allowedOrigins.includes(originHeader)
        ? originHeader
        : config.allowedOrigins[0] || '*';
    res.writeHead(204, {
      'Access-Control-Allow-Origin': corsOrigin,
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Rover-Api-Key',
    });
    return res.end();
  }

  try {
    // ------------------------------------------------------------------------
    // Phase 5A: Supabase Authentication Endpoints
    // ------------------------------------------------------------------------

    // 1. Register Farmer (Public - Strict role assignment to FARMER only)
    if (pathname === '/api/auth/register' && method === 'POST') {
      const body: RegisterFarmerRequest = await parseJsonBody(req);
      try {
        const session = await authService.registerFarmer(body);
        return sendJson(res, 201, {
          success: true,
          message: 'Farmer registration successful.',
          session,
        }, originHeader);
      } catch (err: any) {
        return sendJson(res, 400, {
          success: false,
          error: err.message,
        }, originHeader);
      }
    }

    // 2. Login (Public - Authenticates with Supabase Auth or verified accounts)
    if (pathname === '/api/auth/login' && method === 'POST') {
      const body: LoginRequest = await parseJsonBody(req);
      try {
        const session = await authService.login(body);
        return sendJson(res, 200, {
          success: true,
          message: 'Login successful.',
          session,
        }, originHeader);
      } catch (err: any) {
        return sendJson(res, 401, {
          success: false,
          error: err.message,
        }, originHeader);
      }
    }

    // 3. Logout (Protected - Clears and locks protected user cache)
    if (pathname === '/api/auth/logout' && method === 'POST') {
      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;

      resilientStore.handleLogout(auth.user_id);
      return sendJson(res, 200, {
        success: true,
        message: 'Logged out successfully. Protected cached state cleared.',
      }, originHeader);
    }

    // 4. Me / Current Identity (Protected - Resolves verified user and role)
    if (pathname === '/api/auth/me' && method === 'GET') {
      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;

      return sendJson(res, 200, {
        success: true,
        user: auth,
      }, originHeader);
    }

    // 5. Promote User Role (Privileged - Requires ADMIN role)
    if (pathname === '/api/auth/promote' && method === 'POST') {
      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;
      if (!enforceRole(req, res, ['ADMIN'])) return;

      const body = await parseJsonBody(req);
      try {
        await authService.promoteUserRole(auth, body.target_user_id, body.new_role);
        return sendJson(res, 200, {
          success: true,
          message: `User '${body.target_user_id}' promoted to role '${body.new_role}'.`,
        }, originHeader);
      } catch (err: any) {
        return sendJson(res, 400, {
          success: false,
          error: err.message,
        }, originHeader);
      }
    }

    // ------------------------------------------------------------------------
    // Core Simulator Endpoints (Phase 1)
    // ------------------------------------------------------------------------
    if (pathname === '/api/rover/status' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        data: engine.getStatus(),
      }, originHeader);
    }

    if (pathname === '/api/rover/telemetry/latest' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        data: engine.getTelemetry(),
      }, originHeader);
    }

    if (pathname === '/api/rover/command' && method === 'POST') {
      // Device Boundary Check
      if (!authenticateRoverIngestion(req, res, config)) return;

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
        source: req.roverSource,
      }, originHeader);
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
      }, originHeader);
    }

    if (pathname === '/api/rover/queue' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        buffered_count: engine.offlineStore.getCount(),
        events: engine.offlineStore.peekAll(),
      }, originHeader);
    }

    if (pathname === '/api/rover/flush-queue' && method === 'POST') {
      const flushed = engine.flushOfflineQueue();
      return sendJson(res, 200, {
        success: true,
        flushed_count: flushed.length,
        events: flushed,
      }, originHeader);
    }

    if (pathname === '/api/rover/simulate-scan' && method === 'POST') {
      const body = await parseJsonBody(req);
      const zoneId = body.zone_id || engine.getCurrentZoneId();
      const isReScan = Boolean(body.is_rescan);
      const scanPayload = engine.simulateScanCycle(zoneId, isReScan);
      return sendJson(res, 200, {
        success: true,
        data: scanPayload,
      }, originHeader);
    }

    if (pathname === '/api/rover/recharge' && method === 'POST') {
      const body = await parseJsonBody(req);
      const target = body.target_pct !== undefined ? Number(body.target_pct) : 100.0;
      engine.recharge(target);
      return sendJson(res, 200, {
        success: true,
        battery_pct: engine.getBatteryPct(),
      }, originHeader);
    }

    if (pathname === '/api/rover/telemetry-stream' && method === 'GET') {
      const corsOrigin =
        originHeader && config.allowedOrigins.includes(originHeader)
          ? originHeader
          : config.allowedOrigins[0] || '*';
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
        'Access-Control-Allow-Origin': corsOrigin,
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
      // Device Boundary Check
      if (!authenticateRoverIngestion(req, res, config)) return;

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
        source: req.roverSource,
      }, originHeader);
    }

    // List Alerts (Phase 5B: Supabase authoritative under RLS when online)
    if (pathname === '/api/alerts' && method === 'GET') {
      const token = extractBearerToken(req);

      if (token) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;
        resilientStore.setRequestContext(token);
      } else if (!config.allowSimulatorBypass || config.nodeEnv === 'production') {
        res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        return res.end(JSON.stringify({ success: false, error: 'Authentication required for alerts.' }));
      }

      const zoneId = url.searchParams.get('zone_id') || undefined;
      const status = (url.searchParams.get('status') as any) || undefined;
      try {
        const alerts = await resilientStore.getAlertsAsync({ zone_id: zoneId, status });
        return sendJson(res, 200, {
          success: true,
          count: alerts.length,
          data: alerts,
        }, originHeader);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // Expert Triage Action on an Alert (Role Gated: EXPERT or ADMIN)
    if (pathname.startsWith('/api/alerts/') && pathname.endsWith('/triage') && method === 'POST') {
      const token = extractBearerToken(req);
      let actor = 'dr_sharma_kvk_expert';

      if (token) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;
        if (!enforceRole(req, res, ['EXPERT', 'ADMIN'])) return;
        actor = auth.user_id; // Identity derived from verified token, never trusted from body
      } else if (!config.allowSimulatorBypass || config.nodeEnv === 'production') {
        // Enforce 401 when token missing and not in explicit dev bypass
        res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        return res.end(JSON.stringify({ success: false, error: 'Authentication required for expert triage.' }));
      }

      const parts = pathname.split('/');
      const alertId = parts[3];
      const body = await parseJsonBody(req);

      const alert = await resilientStore.getAlertById(alertId);
      if (!alert) {
        return sendJson(res, 404, { success: false, error: `Alert '${alertId}' not found.` }, originHeader);
      }

      const previousState = alert.status;
      const action = body.action || 'CONFIRM'; // 'CONFIRM' | 'CORRECT' | 'ESCALATE'
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

      await resilientStore.updateAlert(alert);

      // Audit log with verified actor attribution
      await resilientStore.addAuditRecord({
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
      }, originHeader);
    }

    // ------------------------------------------------------------------------
    // Phase 2: Closed-Loop Intervention & Verification Endpoints
    // ------------------------------------------------------------------------

    // Approve Intervention (Safety Gate - Role Gated: FARMER, EXPERT, ADMIN)
    if (pathname === '/api/remediation/approve' && method === 'POST') {
      const token = extractBearerToken(req);
      let approvedBy = 'dr_sharma_kvk_expert';

      if (token) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;
        if (!enforceRole(req, res, ['EXPERT', 'ADMIN'])) return;
        approvedBy = auth.user_id; // Identity derived from verified token, never trusted from body
      } else if (!config.allowSimulatorBypass || config.nodeEnv === 'production') {
        res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        return res.end(JSON.stringify({ success: false, error: 'Authentication required for intervention approval.' }));
      }

      const body = await parseJsonBody(req);
      try {
        const intervention = closedLoop.approveIntervention({
          zone_id: body.zone_id,
          approved_by: approvedBy,
          duration_seconds: body.duration_seconds,
          volume_liters: body.volume_liters,
          expert_note: body.expert_note,
        });

        // Phase 5B: Persist approved action to Supabase under RLS
        if (token && isSupabaseConfigured()) {
          try {
            const client = createUserScopedClient(token);
            await resilientStore.getSupabaseRepo().saveRemediationAction(client, {
              action_id: intervention.action_id,
              zone_id: intervention.zone_id,
              action_type: intervention.action_type,
              duration_seconds: intervention.duration_seconds,
              volume_liters: intervention.volume_liters,
              approved_by: intervention.approved_by,
              approved_at: intervention.approved_at,
              expert_note: intervention.expert_note,
              status: intervention.status,
            });
          } catch (err: any) {
            console.warn('[Server] Failed to persist remediation action to Supabase:', err.message);
          }
        }

        return sendJson(res, 200, {
          success: true,
          message: 'Intervention approved. Ready for execution.',
          data: intervention,
        }, originHeader);
      } catch (err: any) {
        return sendJson(res, 400, {
          success: false,
          error: err.message,
        }, originHeader);
      }
    }

    // Execute Approved Intervention
    if (pathname === '/api/remediation/execute' && method === 'POST') {
      const token = extractBearerToken(req);
      if (token) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;
      } else if (!config.allowSimulatorBypass || config.nodeEnv === 'production') {
        res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        return res.end(JSON.stringify({ success: false, error: 'Authentication required for remediation execution.' }));
      }

      const body = await parseJsonBody(req);
      try {
        const ack = await closedLoop.executeApprovedIntervention(body.action_id);
        const statusCode = ack.status === 'REJECTED' ? 400 : ack.status === 'FAILED' ? 500 : 200;
        return sendJson(res, statusCode, {
          success: ack.status === 'COMPLETED',
          data: ack,
        }, originHeader);
      } catch (err: any) {
        return sendJson(res, 400, {
          success: false,
          error: err.message,
        }, originHeader);
      }
    }

    // Verify Remediation (Re-Scan & Before/After Delta)
    if (pathname === '/api/remediation/verify' && method === 'POST') {
      const token = extractBearerToken(req);
      if (token) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;
      } else if (!config.allowSimulatorBypass || config.nodeEnv === 'production') {
        res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        return res.end(JSON.stringify({ success: false, error: 'Authentication required for remediation verification.' }));
      }

      const body = await parseJsonBody(req);
      try {
        const verification = await closedLoop.verifyIntervention(body.action_id);

        // Phase 5B: Persist verification to Supabase via server-side service role client
        if (isSupabaseConfigured()) {
          try {
            const adminClient = getServiceRoleClient();
            await resilientStore.getSupabaseRepo().saveVerification(adminClient, verification);
          } catch (err: any) {
            console.warn('[Server] Failed to persist verification to Supabase:', err.message);
          }
        }

        return sendJson(res, 200, {
          success: true,
          data: verification,
        }, originHeader);
      } catch (err: any) {
        return sendJson(res, 400, {
          success: false,
          error: err.message,
        }, originHeader);
      }
    }

    // List All Verifications (Phase 5B: Supabase authoritative under RLS when online)
    if (pathname === '/api/remediation/verifications' && method === 'GET') {
      const token = extractBearerToken(req);
      const zoneId = url.searchParams.get('zone_id') || undefined;

      if (token && isSupabaseConfigured()) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;

        try {
          const client = createUserScopedClient(token);
          const records = await resilientStore.getSupabaseRepo().getVerifications(client, zoneId);
          return sendJson(res, 200, {
            success: true,
            count: records.length,
            data: records,
          }, originHeader);
        } catch (err: any) {
          if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
            return sendJson(res, 403, { success: false, error: err.message }, originHeader);
          }
          console.warn('[Server] Supabase getVerifications failed, falling back to local records:', err.message);
        }
      }

      const records = closedLoop.getVerificationRecords(zoneId);
      return sendJson(res, 200, {
        success: true,
        count: records.length,
        data: records,
      }, originHeader);
    }

    // Live Audit History (Phase 5B: Role-gated EXPERT / ADMIN with Supabase RLS)
    if (pathname === '/api/audit/history' && method === 'GET') {
      const token = extractBearerToken(req);
      const zoneId = url.searchParams.get('zone_id') || undefined;
      const alertId = url.searchParams.get('alert_id') || undefined;

      if (token) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;
        if (!enforceRole(req, res, ['EXPERT', 'ADMIN'])) return;

        resilientStore.setRequestContext(token);
      } else if (!config.allowSimulatorBypass || config.nodeEnv === 'production') {
        res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        return res.end(JSON.stringify({ success: false, error: 'Authentication required for audit history.' }));
      }

      try {
        const history = await resilientStore.getAuditHistory({ zone_id: zoneId, alert_id: alertId });
        return sendJson(res, 200, {
          success: true,
          count: history.length,
          data: history,
        }, originHeader);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // ------------------------------------------------------------------------
    // Phase 3: Offline Sync Engine Endpoints
    // ------------------------------------------------------------------------

    // Ingest Sync Batch
    if ((pathname === '/api/sync/batch' || pathname === '/api/sync/push') && method === 'POST') {
      const body: SyncBatchRequest = await parseJsonBody(req);
      if (!body || !Array.isArray(body.records)) {
        return sendJson(res, 400, {
          success: false,
          error: 'Invalid batch request. Must contain client_id and records array.',
        }, originHeader);
      }

      const response = await syncEngine.processBatch(body);
      return sendJson(res, 200, response, originHeader);
    }

    // Queue Status
    if (pathname === '/api/sync/status' && method === 'GET') {
      const status = syncEngine.getStatus();
      return sendJson(res, 200, {
        success: true,
        status,
        data: status,
      }, originHeader);
    }

    // Failed Events
    if (pathname === '/api/sync/failed' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        failed_events: syncEngine.getFailedEvents(),
      }, originHeader);
    }

    // Manual Retry of Failed Sync Events
    if (pathname === '/api/sync/retry' && method === 'POST') {
      const retriedCount = syncEngine.retryFailed();
      return sendJson(res, 200, {
        success: true,
        retried_count: retriedCount,
        queue_status: syncEngine.getStatus(),
      }, originHeader);
    }

    // Flush/Drain Queue
    if (pathname === '/api/sync/flush' && method === 'POST') {
      const flushResult = await syncEngine.flushQueue();
      return sendJson(res, 200, {
        success: true,
        data: flushResult,
      }, originHeader);
    }

    // Authenticated Profile (Backwards Compatible / Dev profile endpoint)
    if (pathname === '/api/auth/profile' && method === 'GET') {
      const token = extractBearerToken(req);
      if (token) {
        const auth = await authService.verifyToken(token);
        if (auth) {
          return sendJson(res, 200, {
            success: true,
            profile: {
              id: auth.user_id,
              role: auth.role,
              full_name: auth.email,
              farmer_id: auth.farmer_id || null,
              assigned_cluster: 'CLUSTER-DEMO-01',
              preferred_language: auth.role === 'FARMER' ? 'hi' : 'en',
              authorized_farms: ['FARM-DEMO-01'],
              authorized_zones: ['ZONE-A1', 'DEMO-ZONE-02', 'DEMO-ZONE-03', 'DEMO-ZONE-04'],
            },
          }, originHeader);
        }
      }

      // Development fallback profile
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
      }, originHeader);
    }

    // Farms List (Phase 5B: User-Scoped Supabase query under RLS)
    if (pathname === '/api/farms' && method === 'GET') {
      const token = extractBearerToken(req);

      if (token && isSupabaseConfigured()) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;

        try {
          const client = createUserScopedClient(token);
          const farms = await resilientStore.getSupabaseRepo().getFarms(client);
          return sendJson(res, 200, {
            success: true,
            farms,
          }, originHeader);
        } catch (err: any) {
          if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
            return sendJson(res, 403, { success: false, error: err.message }, originHeader);
          }
          console.warn('[Server] Supabase getFarms failed, falling back to local fallback:', err.message);
        }
      } else if (!config.allowSimulatorBypass || config.nodeEnv === 'production') {
        res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        return res.end(JSON.stringify({ success: false, error: 'Authentication required for farms.' }));
      }

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
      }, originHeader);
    }

    // Zones List with Health Status (Phase 5B: User-Scoped Supabase query under RLS)
    if (pathname === '/api/zones' && method === 'GET') {
      const token = extractBearerToken(req);
      const farmId = url.searchParams.get('farm_id') || undefined;

      if (token && isSupabaseConfigured()) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;

        try {
          const client = createUserScopedClient(token);
          const zones = await resilientStore.getSupabaseRepo().getZones(client, farmId);
          return sendJson(res, 200, {
            success: true,
            farm_id: farmId,
            zones,
          }, originHeader);
        } catch (err: any) {
          if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
            return sendJson(res, 403, { success: false, error: err.message }, originHeader);
          }
          console.warn('[Server] Supabase getZones failed, falling back to local fallback:', err.message);
        }
      } else if (!config.allowSimulatorBypass || config.nodeEnv === 'production') {
        res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        return res.end(JSON.stringify({ success: false, error: 'Authentication required for zones.' }));
      }

      return sendJson(res, 200, {
        success: true,
        farm_id: farmId || 'FARM-DEMO-01',
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
            last_scan_at: new Date(Date.now() - 1800000).toISOString(),
          },
          {
            id: 'DEMO-ZONE-04',
            name: 'Zone 4 (West Sector)',
            soil_type: 'Silt Loam',
            last_moisture: 30.0,
            status: 'OPTIMAL',
            last_scan_at: new Date(Date.now() - 7200000).toISOString(),
          },
        ],
      }, originHeader);
    }

    // ------------------------------------------------------------------------
    // Phase 4: Intelligence, Risk, Voice & Multimodal Endpoints
    // ------------------------------------------------------------------------

    // Weather & Agricultural Risk Context (Amendment 3)
    if (pathname === '/api/weather/risk' && method === 'GET') {
      const lat = parseFloat(url.searchParams.get('lat') || '26.8467');
      const lng = parseFloat(url.searchParams.get('lng') || '80.9462');
      const fieldMoisture = url.searchParams.get('moisture') ? parseFloat(url.searchParams.get('moisture')!) : 17.5;
      const fieldHumidity = url.searchParams.get('humidity') ? parseFloat(url.searchParams.get('humidity')!) : 48.0;

      const weather = await weatherRiskEngine.getWeather(lat, lng);
      const assessments = weatherRiskEngine.assessRisks(weather, fieldMoisture, fieldHumidity);

      return sendJson(res, 200, {
        success: true,
        weather,
        assessments,
      }, originHeader);
    }

    // Explainable AI / "WHY" Layer (Section 3)
    if (pathname === '/api/intelligence/explain' && method === 'POST') {
      const body = await parseJsonBody(req);
      const zoneId = body.zone_id || 'DEMO-ZONE-02';
      const scan = body.scan || engine.simulateScanCycle(zoneId, false);
      const decision = body.decision || (await decisionEngine.evaluateScan(scan));
      const weather = body.weather || (await weatherRiskEngine.getWeather());

      const report = explainabilityEngine.generateReport({
        zoneId,
        scan,
        decision,
        weather,
      });

      return sendJson(res, 200, {
        success: true,
        report,
      }, originHeader);
    }

    // Voice Interaction Dialog
    if (pathname === '/api/voice/interact' && method === 'POST') {
      const body: VoiceQuery = await parseJsonBody(req);
      const response = await voiceAssistant.processQuery(body);
      return sendJson(res, 200, {
        success: true,
        response,
      }, originHeader);
    }

    // Multimodal Crop Visual Evidence Analysis
    if (pathname === '/api/multimodal/analyze' && method === 'POST') {
      const body: MultimodalAnalysisRequest = await parseJsonBody(req);
      try {
        const result = await multimodalAssistant.analyzeCropEvidence(body);
        return sendJson(res, 200, {
          success: true,
          result,
        }, originHeader);
      } catch (err: any) {
        return sendJson(res, 400, {
          success: false,
          error: err.message,
        }, originHeader);
      }
    }

    // Farm Risk Dashboard & Composite Demo Indicator
    if (pathname === '/api/analytics/farm-risk' && method === 'GET') {
      const farmId = url.searchParams.get('farm_id') || 'FARM-DEMO-01';
      const dashboard = await historicalAnalytics.getFarmRiskDashboard(farmId);
      return sendJson(res, 200, {
        success: true,
        dashboard,
      }, originHeader);
    }

    // Historical Time-Series Intelligence & Verified Deltas
    if (pathname === '/api/analytics/historical' && method === 'GET') {
      const zoneId = url.searchParams.get('zone_id') || 'DEMO-ZONE-02';
      const historical = await historicalAnalytics.getHistoricalIntelligence(zoneId);
      return sendJson(res, 200, {
        success: true,
        historical,
      }, originHeader);
    }

    // PRAHAR Field Evidence Report
    if (pathname === '/api/reports/field-evidence' && method === 'GET') {
      const zoneId = url.searchParams.get('zone_id') || 'DEMO-ZONE-02';
      const farmId = url.searchParams.get('farm_id') || 'FARM-DEMO-01';
      const farmName = url.searchParams.get('farm_name') || 'Kisan Demo Farm Alpha (डेमो खेत अल्फा)';

      const scan = engine.simulateScanCycle(zoneId, false);
      const verifications = (await resilientStore.getVerifications?.(zoneId)) || [];
      const latestVerif = verifications[0];

      const report = FieldEvidenceReportGenerator.generateReport({
        farmId,
        farmName,
        zoneId,
        scan,
        actionExecuted: latestVerif ? '30s Micro-irrigation (~7.5L)' : 'Scheduled Rover Agronomic Scan Cycle',
        approvedBy: latestVerif ? 'dr_sharma_kvk_expert' : undefined,
        verification: latestVerif,
      });

      return sendJson(res, 200, {
        success: true,
        report,
      }, originHeader);
    }

    // Farmer Opportunity Center
    if (pathname === '/api/opportunities' && method === 'GET') {
      const category = url.searchParams.get('category');
      let schemes = OpportunityCenter.getSchemes();
      if (category) {
        schemes = schemes.filter((s) => s.category === category);
      }
      return sendJson(res, 200, {
        success: true,
        count: schemes.length,
        schemes,
      }, originHeader);
    }

    // 404 Fallback
    return sendJson(res, 404, {
      success: false,
      error: `Endpoint not found: ${method} ${pathname}`,
    }, originHeader);
  } catch (err: any) {
    return sendJson(res, 500, {
      success: false,
      error: err?.message || 'Internal Server Error',
    }, originHeader);
  }
});

server.listen(PORT, () => {
  console.log(`[PRAHAR Rover Simulator & Decision Gateway v0.5] Online`);
  console.log(`Rover ID: ${engine.getRoverId()}`);
  console.log(`HTTP Server listening on http://localhost:${PORT}`);
  console.log(`Phase 5A Endpoints:`);
  console.log(`  POST /api/auth/register (Farmer Registration)`);
  console.log(`  POST /api/auth/login (JWT Login)`);
  console.log(`  POST /api/auth/logout`);
  console.log(`  GET  /api/auth/me`);
  console.log(`  POST /api/auth/promote (Admin Only)`);
});

if (process.argv.some((arg) => arg.includes('test'))) {
  server.unref();
}

export {
  server,
  engine,
  alertStore,
  resilientStore,
  authService,
  config,
  syncEngine,
  decisionEngine,
  closedLoop,
  weatherRiskEngine,
  explainabilityEngine,
  voiceAssistant,
  multimodalAssistant,
  historicalAnalytics,
};
