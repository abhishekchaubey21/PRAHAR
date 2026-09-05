/**
 * PRAHAR Rover Simulator — HTTP & SSE REST Server
 * Provides standard integration endpoints for the rover gateway and consoles.
 * Built with native Node.js HTTP for zero-dependency reliability.
 */

import http from 'node:http';
import { RoverEngine } from './engine.js';
import { RoverCommand } from '@prahar/shared';

const PORT = parseInt(process.env.PORT || '3001', 10);
const engine = new RoverEngine({
  roverId: process.env.ROVER_ID || 'ROVER-DEMO-01',
  initialBattery: 96.0,
});

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
    // 1. Status
    if (pathname === '/api/rover/status' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        data: engine.getStatus(),
      });
    }

    // 2. Latest Telemetry
    if (pathname === '/api/rover/telemetry/latest' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        data: engine.getTelemetry(),
      });
    }

    // 3. Command Execution (Strict Idempotency)
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

    // 4. Toggle Offline Mode
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

    // 5. Inspect Offline Queue
    if (pathname === '/api/rover/queue' && method === 'GET') {
      return sendJson(res, 200, {
        success: true,
        buffered_count: engine.offlineStore.getCount(),
        events: engine.offlineStore.peekAll(),
      });
    }

    // 6. Flush Offline Queue (Reconnect / Sync)
    if (pathname === '/api/rover/flush-queue' && method === 'POST') {
      const flushed = engine.flushOfflineQueue();
      return sendJson(res, 200, {
        success: true,
        flushed_count: flushed.length,
        events: flushed,
      });
    }

    // 7. Manual Simulated Scan Trigger
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

    // 8. Recharge Battery
    if (pathname === '/api/rover/recharge' && method === 'POST') {
      const body = await parseJsonBody(req);
      const target = body.target_pct !== undefined ? Number(body.target_pct) : 100.0;
      engine.recharge(target);
      return sendJson(res, 200, {
        success: true,
        battery_pct: engine.getBatteryPct(),
      });
    }

    // 9. Server-Sent Events (SSE) Telemetry Stream
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

    // 404
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
  console.log(`[PRAHAR Rover Simulator v0.1] Online`);
  console.log(`Rover ID: ${engine.getRoverId()}`);
  console.log(`HTTP Server listening on http://localhost:${PORT}`);
  console.log(`API Endpoints:`);
  console.log(`  GET  /api/rover/status`);
  console.log(`  GET  /api/rover/telemetry/latest`);
  console.log(`  POST /api/rover/command`);
  console.log(`  POST /api/rover/offline-mode`);
  console.log(`  GET  /api/rover/queue`);
  console.log(`  POST /api/rover/flush-queue`);
  console.log(`  POST /api/rover/simulate-scan`);
  console.log(`  GET  /api/rover/telemetry-stream`);
});

export { server, engine };
