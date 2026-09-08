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
import { FieldAssistantService } from './field-assistant.js';
import { OllamaProvider } from './ollama-provider.js';
import { DemoScenarioEngine } from './demo-scenarios.js';
import { MultimodalAssistant } from './multimodal-assistant.js';
import { HistoricalAnalytics } from './historical-analytics.js';
import { FieldEvidenceReportGenerator, OpportunityCenter } from './reports-and-opportunities.js';
import { AuthService } from './auth-service.js';
import { NotificationService } from './notification-service.js';
import { AnalyticsService } from './analytics-service.js';
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
  AuthenticatedContext,
  AssistantQueryRequest,
} from '@prahar/shared';

const config = loadConfig();
const PORT = config.port;
const HOST = process.env.HOST || '0.0.0.0';

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
const ollamaProvider = new OllamaProvider();
const demoScenarioEngine = new DemoScenarioEngine();
const fieldAssistant = new FieldAssistantService(
  resilientStore,
  closedLoop,
  resilientStore,
  engine,
  ollamaProvider,
  demoScenarioEngine
);
const multimodalAssistant = new MultimodalAssistant();
const historicalAnalytics = new HistoricalAnalytics(resilientStore);
const notificationService = new NotificationService();
const analyticsService = new AnalyticsService();


async function resolveFarmAndUser(zoneId?: string, farmId?: string, callerUserId?: string): Promise<{ farmId: string; userId: string }> {
  if (isSupabaseConfigured()) {
    try {
      const adminClient = getServiceRoleClient();
      if (zoneId && !farmId) {
        const { data: zone } = await adminClient.from('zones').select('farm_id').eq('id', zoneId).maybeSingle();
        if (zone?.farm_id) farmId = zone.farm_id;
      }
      if (farmId) {
        const { data: farm } = await adminClient.from('farms').select('farmer_id').eq('id', farmId).maybeSingle();
        if (farm?.farmer_id) {
          const { data: profile } = await adminClient.from('profiles').select('id').eq('farmer_id', farm.farmer_id).maybeSingle();
          if (profile?.id) {
            return { farmId, userId: profile.id };
          }
        }
      }
    } catch (_) {}
  }

  return {
    farmId: farmId || 'FARM-DEMO-01',
    userId: callerUserId || 'usr-demo-farmer-01',
  };
}

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
    'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
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
      'Access-Control-Allow-Methods': 'GET, POST, PATCH, OPTIONS',
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

    // Phase 7A: Farmer Profile & Onboarding State Endpoints
    if (pathname === '/api/farmer/profile' && method === 'GET') {
      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;

      const profile = resilientStore.getFarmerProfile(auth.user_id) || {
        profile: {
          name: auth.full_name || 'Ramesh Patil',
          state: 'Maharashtra',
          district: 'Amravati',
          village: 'Nandgaon Khandeshwar',
          preferred_language: 'en',
        },
        farm: {
          area_acres: 4.2,
          ownership_type: 'OWNED',
          irrigation_status: 'PARTIAL',
          water_source: 'BOREWELL',
          soil_type: 'Black Cotton Loam',
        },
        crops: {
          main_crops: ['Soybean', 'Wheat'],
          season: 'KHARIF',
          variety: 'JS 335 / GW 322',
          sowing_date: '2026-06-25',
        },
        is_completed: true,
      };

      return sendJson(res, 200, {
        success: true,
        data: profile,
      }, originHeader);
    }

    if (pathname === '/api/farmer/profile' && method === 'POST') {
      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;

      const body = await parseJsonBody(req);
      resilientStore.saveFarmerProfile(auth.user_id, body);

      return sendJson(res, 200, {
        success: true,
        message: 'Farmer profile and onboarding state saved successfully.',
        data: body,
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

      // Phase 6B-1: Generate notifications from meaningful scan events
      try {
        const { farmId, userId } = await resolveFarmAndUser(payload.zone_id);
        if (result.decision?.alerts_to_create) {
          for (const alert of result.decision.alerts_to_create) {
            await notificationService.createNotification({
              user_id: userId,
              farm_id: farmId,
              zone_id: payload.zone_id,
              alert_id: alert.alert_id,
              type: 'ALERT_CREATED',
              severity: alert.severity,
              title: `Hazard Alert: ${alert.type}`,
              title_hi: `जोखिम चेतावनी: ${alert.type}`,
              message: alert.message,
              message_hi: alert.message_hi,
              deduplication_key: `alert:${alert.alert_id}`,
              metadata: { hazard_type: alert.type, source: 'decision_engine' },
            });
          }
        }
        if (result.decision?.action_recommendation) {
          const rec = result.decision.action_recommendation;
          await notificationService.createNotification({
            user_id: userId,
            farm_id: farmId,
            zone_id: payload.zone_id,
            type: 'ACTION_RECOMMENDED',
            severity: 'HIGH',
            title: `Action Recommended: ${rec.action_type}`,
            title_hi: `कार्रवाई अनुशंसित: ${rec.action_type}`,
            message: rec.description_en,
            message_hi: rec.description_hi,
            deduplication_key: `action_rec:${payload.zone_id}:${rec.action_type}`,
            metadata: { action_type: rec.action_type },
          });
        }
      } catch (err: any) {
        console.warn('[Server] Error generating scan notifications:', err.message);
      }

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

        // Phase 6B-1: Generate ACTION_APPROVED notification
        try {
          const { farmId, userId } = await resolveFarmAndUser(body.zone_id, undefined, approvedBy);
          await notificationService.createNotification({
            user_id: userId,
            farm_id: farmId,
            zone_id: body.zone_id,
            action_id: intervention.action_id,
            type: 'ACTION_APPROVED',
            severity: 'MEDIUM',
            title: `Intervention Approved: ${intervention.action_type}`,
            title_hi: `हस्तक्षेप स्वीकृत: ${intervention.action_type}`,
            message: `Action ${intervention.action_id} approved by ${approvedBy} for zone ${body.zone_id}. Ready for execution.`,
            message_hi: `कार्रवाई ${intervention.action_id} क्षेत्र ${body.zone_id} के लिए स्वीकृत।`,
            deduplication_key: `action_approved:${intervention.action_id}`,
            metadata: { approved_by: approvedBy, duration_seconds: intervention.duration_seconds },
          });
        } catch (err: any) {
          console.warn('[Server] Error generating approval notification:', err.message);
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
        const intervention = closedLoop.getPendingIntervention(body.action_id);
        const zoneId = intervention?.zone_id;

        // Phase 6B-1: Generate ACTION_EXECUTED notification
        try {
          const { farmId, userId } = await resolveFarmAndUser(zoneId);
          await notificationService.createNotification({
            user_id: userId,
            farm_id: farmId,
            zone_id: zoneId,
            action_id: body.action_id,
            type: 'ACTION_EXECUTED',
            severity: 'INFO',
            title: 'Intervention Executed',
            title_hi: 'हस्तक्षेप निष्पादित',
            message: `Rover successfully executed remediation for action ${body.action_id}.`,
            message_hi: `रोवर ने कार्रवाई ${body.action_id} का सफलतापूर्वक निष्पादन किया।`,
            deduplication_key: `action_executed:${body.action_id}`,
            metadata: { status: ack.status, result: ack.result },
          });
        } catch (err: any) {
          console.warn('[Server] Error generating execute notification:', err.message);
        }

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

        // Phase 6B-1: Generate VERIFICATION_COMPLETED or VERIFICATION_FAILED notification
        try {
          const { farmId, userId } = await resolveFarmAndUser(verification.zone_id);
          const isResolved = Boolean(verification.resolved);
          await notificationService.createNotification({
            user_id: userId,
            farm_id: farmId,
            zone_id: verification.zone_id,
            action_id: body.action_id,
            type: isResolved ? 'VERIFICATION_COMPLETED' : 'VERIFICATION_FAILED',
            severity: isResolved ? 'INFO' : 'HIGH',
            title: isResolved
              ? `Verification Successful: ${verification.zone_id}`
              : `Verification Target Not Met: ${verification.zone_id}`,
            title_hi: isResolved
              ? `सत्यापन सफल: ${verification.zone_id}`
              : `सत्यापन लक्ष्य पूरा नहीं हुआ: ${verification.zone_id}`,
            message: verification.summary_en,
            message_hi: verification.summary_hi,
            deduplication_key: `verification:${verification.verification_id}`,
            metadata: {
              verification_id: verification.verification_id,
              resolved: isResolved,
              pre_moisture: verification.pre_moisture,
              post_moisture: verification.post_moisture,
            },
          });
        } catch (err: any) {
          console.warn('[Server] Error generating verification notification:', err.message);
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
            farmer_id: '00000000-0000-0000-0000-000000000001',
            name: 'Patil Krishi Farm (पाटील कृषी फार्म)',
            crop_type: 'Soybean + Wheat',
            area_acres: 4.2,
            ownership_type: 'OWNED',
            irrigation_status: 'BOREWELL_AND_RAINFED',
            water_source: 'Borewell + Rainfed',
            soil_type: 'Black Cotton Loam',
            location: 'Amravati, Maharashtra',
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
            id: 'DEMO-ZONE-01',
            name: 'Zone 1 — North Plot (Soybean Healthy)',
            crop: 'Soybean',
            soil_type: 'Black Cotton Loam',
            last_moisture: 32.4,
            temperature_c: 26.2,
            humidity_pct: 58.0,
            ph: 6.8,
            status: 'OPTIMAL',
            severity: 'NONE',
            last_scan_at: new Date(Date.now() - 3600000).toISOString(),
          },
          {
            id: 'DEMO-ZONE-02',
            name: 'Zone 2 — East Sector (Soybean Water Stress)',
            crop: 'Soybean',
            soil_type: 'Sandy Loam',
            last_moisture: 16.8,
            temperature_c: 34.5,
            humidity_pct: 38.0,
            ph: 6.5,
            status: 'WATER_STRESS',
            severity: 'HIGH',
            recommendation: 'Micro-irrigation (30 seconds)',
            last_scan_at: new Date(Date.now() - 900000).toISOString(),
          },
          {
            id: 'DEMO-ZONE-03',
            name: 'Zone 3 — South Sector (Wheat Pest Alert)',
            crop: 'Wheat',
            soil_type: 'Silt Loam',
            last_moisture: 28.5,
            temperature_c: 29.1,
            humidity_pct: 74.0,
            ph: 6.4,
            status: 'PEST_ALERT',
            severity: 'HIGH',
            pest_scenario: 'Fall Armyworm (Demo AI Detection • YOLOv8-compatible scenario)',
            confidence: 0.89,
            recommendation: 'Pheromone traps + biopesticide; expert inspection',
            last_scan_at: new Date(Date.now() - 1800000).toISOString(),
          },
          {
            id: 'DEMO-ZONE-04',
            name: 'Zone 4 — West Sector (Wheat Nutrient Deficiency)',
            crop: 'Wheat',
            soil_type: 'Clay Loam',
            last_moisture: 24.2,
            temperature_c: 28.0,
            humidity_pct: 52.0,
            ph: 7.8,
            status: 'NUTRIENT_DEFICIENCY',
            severity: 'MEDIUM',
            nutrient_scenario: 'Nitrogen deficiency / Chlorosis',
            confidence: 0.82,
            recommendation: 'Split-dose urea foliar spray + gypsum amendment',
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
      const token = extractBearerToken(req);
      let authUser: AuthenticatedContext | undefined;

      if (token) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;
        authUser = auth;
      } else if (!config.allowSimulatorBypass || config.nodeEnv === 'production') {
        res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        return res.end(JSON.stringify({ success: false, error: 'Authentication required for voice interaction.' }));
      }

      const body: VoiceQuery = await parseJsonBody(req);
      const queryWithAuth: VoiceQuery = {
        ...body,
        user_id: authUser ? authUser.user_id : (body.user_id || 'simulated_farmer'),
        role: authUser ? authUser.role : (body.role || 'FARMER'),
      };
      const response = await voiceAssistant.processQuery(queryWithAuth);
      return sendJson(res, 200, {
        success: true,
        response,
      }, originHeader);
    }

    // Phase 7B: PRAHAR Contextual Field Assistant
    if (pathname === '/api/assistant/query' && method === 'POST') {
      const token = extractBearerToken(req);
      let authUser: AuthenticatedContext | undefined;

      if (token) {
        const auth = await authenticateRequest(req, res, authService);
        if (!auth) return;
        authUser = auth;
      } else if (!config.allowSimulatorBypass || config.nodeEnv === 'production') {
        res.writeHead(401, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        return res.end(JSON.stringify({ success: false, error: 'Authentication required for field assistant.' }));
      }

      const body: AssistantQueryRequest = await parseJsonBody(req);
      const queryWithAuth: AssistantQueryRequest = {
        ...body,
        user_id: authUser ? authUser.user_id : (body.user_id || 'simulated_farmer'),
      };
      const response = await fieldAssistant.processQuery(queryWithAuth);
      return sendJson(res, 200, {
        success: true,
        response,
      }, originHeader);
    }

    // Phase 8: Deterministic Demo Scenarios & Judge Mode Endpoints
    if (pathname === '/api/scenarios' && method === 'GET') {
      const scenarios = demoScenarioEngine.getAllScenarios();
      const activeId = demoScenarioEngine.getActiveScenarioId();
      return sendJson(res, 200, {
        success: true,
        data: {
          active_scenario_id: activeId,
          scenarios,
        },
      }, originHeader);
    }

    if (pathname === '/api/scenarios/select' && method === 'POST') {
      const body = await parseJsonBody(req);
      const scenarioId = body.scenario_id;
      if (!scenarioId) {
        return sendJson(res, 400, { success: false, error: 'scenario_id is required' }, originHeader);
      }
      try {
        const scenario = demoScenarioEngine.setScenario(scenarioId);
        const scenarioContext = demoScenarioEngine.getScenarioContext(scenarioId);
        return sendJson(res, 200, {
          success: true,
          data: {
            active_scenario: scenario,
            context: scenarioContext,
          },
        }, originHeader);
      } catch (err: any) {
        return sendJson(res, 400, { success: false, error: err.message }, originHeader);
      }
    }

    if (pathname === '/api/scenarios/reset' && method === 'POST') {
      const defaultScenario = demoScenarioEngine.resetField();
      const defaultContext = demoScenarioEngine.getScenarioContext('WATER_STRESS');
      return sendJson(res, 200, {
        success: true,
        message: 'Field state and active scenario reset to canonical baseline.',
        data: {
          active_scenario: defaultScenario,
          context: defaultContext,
        },
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

    // PRAHAR Field Evidence Report (Phase 6B-3 Authenticated & Authoritative)
    if (pathname === '/api/reports/field-evidence' && method === 'GET') {
      const token = extractBearerToken(req);
      if (!token) {
        if (!config.allowSimulatorBypass || isSupabaseConfigured() || url.searchParams.has('farm_id')) {
          return sendJson(res, 401, { success: false, error: 'Authentication required for field evidence reports.' }, originHeader);
        }
        // Legacy offline demo fallback for Phase 4 backward-compatibility when Supabase is not configured
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
        return sendJson(res, 200, { success: true, report }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;

      const farmId = url.searchParams.get('farm_id');
      if (!farmId) {
        return sendJson(res, 400, { success: false, error: 'farm_id query parameter is required.' }, originHeader);
      }
      const zoneId = url.searchParams.get('zone_id') || undefined;
      const from = url.searchParams.get('from') || undefined;
      const to = url.searchParams.get('to') || undefined;
      const format = url.searchParams.get('format') || (req.headers.accept?.includes('application/pdf') ? 'pdf' : 'json');
      const download = url.searchParams.get('download') === 'true';

      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      try {
        const { report, pdfBuffer } = await FieldEvidenceReportGenerator.generateAuthoritativeReport({
          farmId,
          zoneId,
          from,
          to,
          client: userScopedClient,
          analyticsService,
        });

        if (format === 'pdf' || download) {
          res.writeHead(200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': `attachment; filename="PRAHAR_Field_Evidence_Report_${report.report_id}.pdf"`,
            'Content-Length': pdfBuffer.length,
            'Access-Control-Allow-Origin': originHeader || '*',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
          });
          res.end(pdfBuffer);
          return;
        }

        return sendJson(res, 200, {
          success: true,
          data: report,
          report,
          pdf_base64: report.pdf_base64,
        }, originHeader);
      } catch (err: any) {
        if (
          err?.message?.includes('access denied') ||
          err?.message?.includes('not found') ||
          err?.message?.includes('42501') ||
          err?.message?.includes('Unauthorized')
        ) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // POST /api/reports/field-evidence/generate (Phase 6B-3 Generate Report Action)
    if (pathname === '/api/reports/field-evidence/generate' && method === 'POST') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required to generate field evidence reports.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;

      const body = await parseJsonBody(req);
      const farmId = body.farm_id;
      if (!farmId) {
        return sendJson(res, 400, { success: false, error: 'farm_id is required in request body.' }, originHeader);
      }
      const zoneId = body.zone_id || undefined;
      const from = body.from || undefined;
      const to = body.to || undefined;
      const format = body.format || (req.headers.accept?.includes('application/pdf') ? 'pdf' : 'json');

      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      try {
        const { report, pdfBuffer } = await FieldEvidenceReportGenerator.generateAuthoritativeReport({
          farmId,
          zoneId,
          from,
          to,
          client: userScopedClient,
          analyticsService,
        });

        if (format === 'pdf') {
          res.writeHead(200, {
            'Content-Type': 'application/pdf',
            'Content-Disposition': `attachment; filename="PRAHAR_Field_Evidence_Report_${report.report_id}.pdf"`,
            'Content-Length': pdfBuffer.length,
            'Access-Control-Allow-Origin': originHeader || '*',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept',
          });
          res.end(pdfBuffer);
          return;
        }

        return sendJson(res, 200, {
          success: true,
          data: report,
          report,
          pdf_base64: report.pdf_base64,
        }, originHeader);
      } catch (err: any) {
        if (
          err?.message?.includes('access denied') ||
          err?.message?.includes('not found') ||
          err?.message?.includes('42501') ||
          err?.message?.includes('Unauthorized')
        ) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // ========================================================================
    // Phase 6B-4: Opportunity & Scheme Center Endpoints
    // ========================================================================

    // 1. Check Eligibility (Authenticated, Deterministic guidance)
    if (pathname === '/api/opportunities/check-eligibility' && method === 'POST') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required to evaluate scheme eligibility.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;
      const userId = auth.user_id;

      const body = await parseJsonBody(req);
      const opportunityId = body.opportunity_id;
      if (!opportunityId) {
        return sendJson(res, 400, { success: false, error: 'opportunity_id is required in request body.' }, originHeader);
      }

      const scheme = OpportunityCenter.getSchemeById(opportunityId);
      if (!scheme) {
        return sendJson(res, 404, { success: false, error: `Opportunity '${opportunityId}' not found in authoritative catalogue.` }, originHeader);
      }

      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      try {
        const evaluation = await OpportunityCenter.evaluateEligibility(
          opportunityId,
          {
            userId,
            farmId: body.farm_id,
            landAcres: body.land_acres !== undefined ? Number(body.land_acres) : undefined,
            cropType: body.crop_type,
            state: body.state,
            irrigationStatus: body.irrigation_status,
            ownershipType: body.ownership_type,
          },
          userScopedClient
        );

        return sendJson(res, 200, {
          success: true,
          data: evaluation,
          evaluation,
        }, originHeader);
      } catch (err: any) {
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // 2. Application Tracking - List User Tracking (Authenticated, RLS-enforced)
    if (pathname === '/api/opportunities/tracking' && method === 'GET') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required to access tracking records.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;
      const userId = auth.user_id;
      const role = auth.role;

      const requestedUserId = url.searchParams.get('farmer_user_id');
      let targetUserId = userId;

      if (requestedUserId && requestedUserId !== userId) {
        if (role !== 'EXPERT' && role !== 'ADMIN') {
          return sendJson(res, 403, { success: false, error: 'Access denied: Farmers can only query their own tracking records.' }, originHeader);
        }

        // Enforce expert tenant/farm boundary if caller is EXPERT
        if (role === 'EXPERT' && isSupabaseConfigured()) {
          const admin = getServiceRoleClient();
          const { data: prof } = await admin.from('profiles').select('farmer_id').eq('id', requestedUserId).maybeSingle();
          const farmerId = prof?.farmer_id;
          if (!farmerId) {
            return sendJson(res, 403, { success: false, error: 'Expert access denied: Farmer profile not found.' }, originHeader);
          }
          const { data: farmerFarms } = await admin.from('farms').select('id').eq('farmer_id', farmerId);
          const farmIds = (farmerFarms || []).map((f: any) => f.id);
          if (farmIds.length === 0) {
            return sendJson(res, 403, { success: false, error: 'Expert access denied: No farms associated with this farmer.' }, originHeader);
          }
          const { data: assignment } = await admin
            .from('expert_farm_assignments')
            .select('*')
            .eq('expert_id', userId)
            .in('farm_id', farmIds)
            .limit(1);

          if (!assignment || assignment.length === 0) {
            return sendJson(res, 403, { success: false, error: 'Expert access denied: You are not assigned to this farmer\'s farm.' }, originHeader);
          }
        }

        targetUserId = requestedUserId;
      }

      let trackingClient: any;
      if (isSupabaseConfigured()) {
        if (requestedUserId && requestedUserId !== userId) {
          // Expert/Admin verified boundary check passed above; use service role for cross-user read
          trackingClient = getServiceRoleClient();
        } else {
          // Farmer querying their own records: strictly user-scoped client preserving RLS
          trackingClient = createUserScopedClient(token);
        }
      }

      try {
        const tracking = await OpportunityCenter.getTracking(targetUserId, trackingClient);
        return sendJson(res, 200, {
          success: true,
          count: tracking.length,
          data: tracking,
        }, originHeader);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('Unauthorized')) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // 3. Application Tracking - Update Tracking Record (Authenticated, RLS-enforced)
    if (pathname === '/api/opportunities/tracking' && method === 'POST') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required to update tracking record.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;
      const userId = auth.user_id;

      const body = await parseJsonBody(req);
      const opportunityId = body.opportunity_id;
      const status = body.status;
      const notes = body.notes;

      if (!opportunityId) {
        return sendJson(res, 400, { success: false, error: 'opportunity_id is required in request body.' }, originHeader);
      }
      if (!status) {
        return sendJson(res, 400, { success: false, error: 'status is required in request body.' }, originHeader);
      }

      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      try {
        const updated = await OpportunityCenter.updateTracking(
          userId,
          { opportunity_id: opportunityId, status, notes },
          userScopedClient
        );

        return sendJson(res, 200, {
          success: true,
          data: updated,
        }, originHeader);
      } catch (err: any) {
        if (err?.message?.includes('not found in authoritative catalogue')) {
          return sendJson(res, 404, { success: false, error: err.message }, originHeader);
        }
        if (err?.message?.includes('Invalid status')) {
          return sendJson(res, 400, { success: false, error: err.message }, originHeader);
        }
        if (err?.message?.includes('42501') || err?.message?.includes('Unauthorized')) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // 4. Application Guide for Opportunity
    if (pathname.startsWith('/api/opportunities/') && pathname.endsWith('/application-guide') && method === 'GET') {
      const parts = pathname.split('/');
      const oppId = decodeURIComponent(parts[3] || '');
      const guide = OpportunityCenter.getApplicationGuide(oppId);
      if (!guide) {
        return sendJson(res, 404, { success: false, error: `Application guide for '${oppId}' not found.` }, originHeader);
      }
      return sendJson(res, 200, {
        success: true,
        data: guide,
      }, originHeader);
    }

    // 5. Single Opportunity Detail
    if (pathname.startsWith('/api/opportunities/') && method === 'GET') {
      const parts = pathname.split('/');
      const oppId = decodeURIComponent(parts[3] || '');
      if (oppId && oppId !== 'tracking' && oppId !== 'check-eligibility') {
        const scheme = OpportunityCenter.getSchemeById(oppId);
        if (!scheme) {
          return sendJson(res, 404, { success: false, error: `Opportunity '${oppId}' not found.` }, originHeader);
        }
        return sendJson(res, 200, {
          success: true,
          data: scheme,
          scheme,
        }, originHeader);
      }
    }

    // 6. List Opportunities Catalogue (Public/Authenticated)
    if (pathname === '/api/opportunities' && method === 'GET') {
      const category = url.searchParams.get('category') || undefined;
      const type = url.searchParams.get('type') || undefined;
      const schemes = OpportunityCenter.getSchemes({ category, type });
      return sendJson(res, 200, {
        success: true,
        count: schemes.length,
        data: schemes,
        schemes,
      }, originHeader);
    }

    // ------------------------------------------------------------------------
    // Phase 6B-1: In-App Notification System Endpoints
    // ------------------------------------------------------------------------

    // 1. List Notifications (Authenticated, RLS-enforced)
    if (pathname === '/api/notifications' && method === 'GET') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required for notifications.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;
      const userId = auth.user_id;
      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      try {
        const isReadParam = url.searchParams.get('is_read');
        const isRead = isReadParam !== null ? isReadParam === 'true' : undefined;
        const limit = url.searchParams.get('limit') ? parseInt(url.searchParams.get('limit')!, 10) : undefined;

        const list = await notificationService.listNotifications(
          userId,
          { is_read: isRead, limit },
          userScopedClient
        );

        return sendJson(res, 200, {
          success: true,
          count: list.length,
          data: list,
        }, originHeader);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // 2. Unread Notification Count (Authenticated, RLS-enforced)
    if (pathname === '/api/notifications/unread-count' && method === 'GET') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required for notifications.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;
      const userId = auth.user_id;
      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      try {
        const count = await notificationService.getUnreadCount(userId, userScopedClient);
        return sendJson(res, 200, {
          success: true,
          count,
        }, originHeader);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // 3. Mark Individual Notification Read (Authenticated, RLS-enforced)
    if (pathname.startsWith('/api/notifications/') && pathname.endsWith('/read') && method === 'PATCH') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required to mark notification read.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;
      const userId = auth.user_id;
      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      const parts = pathname.split('/');
      const notifId = parts[3];
      if (!notifId) {
        return sendJson(res, 400, { success: false, error: 'Notification ID required in path.' }, originHeader);
      }

      try {
        const updated = await notificationService.markRead(userId, notifId, userScopedClient);
        if (!updated) {
          return sendJson(res, 404, { success: false, error: `Notification '${notifId}' not found.` }, originHeader);
        }
        return sendJson(res, 200, {
          success: true,
          data: updated,
        }, originHeader);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // 4. Mark All Notifications Read (Authenticated, RLS-enforced)
    if (pathname === '/api/notifications/read-all' && method === 'POST') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required to mark all notifications read.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;
      const userId = auth.user_id;
      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      try {
        const count = await notificationService.markAllRead(userId, userScopedClient);
        return sendJson(res, 200, {
          success: true,
          count,
        }, originHeader);
      } catch (err: any) {
        if (err?.message?.includes('42501') || err?.message?.includes('JWT') || err?.message?.includes('Unauthorized')) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // ------------------------------------------------------------------------
    // Phase 6B-2: Farmer Analytics, Field Health & Historical Trends Endpoints
    // ------------------------------------------------------------------------

    // 1. Current Field / Zone Health Summary (Authenticated, RLS-enforced)
    if (pathname === '/api/analytics/summary' && method === 'GET') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required for analytics.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;

      const farmId = url.searchParams.get('farm_id');
      if (!farmId) {
        return sendJson(res, 400, { success: false, error: 'farm_id query parameter is required.' }, originHeader);
      }
      const zoneId = url.searchParams.get('zone_id') || undefined;

      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      try {
        const summary = await analyticsService.getSummary(farmId, zoneId, userScopedClient);
        return sendJson(res, 200, {
          success: true,
          data: summary,
        }, originHeader);
      } catch (err: any) {
        if (
          err?.message?.includes('access denied') ||
          err?.message?.includes('not found') ||
          err?.message?.includes('42501') ||
          err?.message?.includes('Unauthorized')
        ) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // 2. Historical Sensor & Hazard Trends (Authenticated, RLS-enforced)
    if (pathname === '/api/analytics/trends' && method === 'GET') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required for analytics.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;

      const zoneId = url.searchParams.get('zone_id');
      if (!zoneId) {
        return sendJson(res, 400, { success: false, error: 'zone_id query parameter is required.' }, originHeader);
      }

      const from = url.searchParams.get('from') || undefined;
      const to = url.searchParams.get('to') || undefined;
      const limitParam = url.searchParams.get('limit');
      const limit = limitParam ? parseInt(limitParam, 10) : undefined;

      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      try {
        const trends = await analyticsService.getTrends(zoneId, { from, to, limit }, userScopedClient);
        return sendJson(res, 200, {
          success: true,
          data: trends,
        }, originHeader);
      } catch (err: any) {
        if (
          err?.message?.includes('access denied') ||
          err?.message?.includes('not found') ||
          err?.message?.includes('42501') ||
          err?.message?.includes('Unauthorized')
        ) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
    }

    // 3. Remediation Interventions & Verifications History (Authenticated, RLS-enforced)
    if (pathname === '/api/analytics/interventions' && method === 'GET') {
      const token = extractBearerToken(req);
      if (!token) {
        return sendJson(res, 401, { success: false, error: 'Authentication required for analytics.' }, originHeader);
      }

      const auth = await authenticateRequest(req, res, authService);
      if (!auth) return;

      const farmId = url.searchParams.get('farm_id') || undefined;
      const zoneId = url.searchParams.get('zone_id') || undefined;
      const limitParam = url.searchParams.get('limit');
      const limit = limitParam ? parseInt(limitParam, 10) : undefined;

      let userScopedClient: any;
      if (isSupabaseConfigured()) {
        userScopedClient = createUserScopedClient(token);
      }

      try {
        const interventions = await analyticsService.getInterventions({ farmId, zoneId, limit }, userScopedClient);
        return sendJson(res, 200, {
          success: true,
          data: interventions,
        }, originHeader);
      } catch (err: any) {
        if (
          err?.message?.includes('access denied') ||
          err?.message?.includes('not found') ||
          err?.message?.includes('42501') ||
          err?.message?.includes('Unauthorized')
        ) {
          return sendJson(res, 403, { success: false, error: err.message }, originHeader);
        }
        return sendJson(res, 500, { success: false, error: err.message }, originHeader);
      }
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

server.listen(PORT, HOST, () => {
  console.log(`[PRAHAR Rover Simulator & Decision Gateway v0.5] Online`);
  console.log(`Rover ID: ${engine.getRoverId()}`);
  console.log(`HTTP Server listening on http://${HOST}:${PORT} (Local: http://localhost:${PORT}, LAN: http://192.168.1.8:${PORT})`);
  console.log(`Phase 5A Endpoints:`);
  console.log(`  POST /api/auth/register (Farmer Registration)`);
  console.log(`  POST /api/auth/login (JWT Login)`);
  console.log(`  POST /api/auth/logout`);
  console.log(`  GET  /api/auth/me`);
  console.log(`  POST /api/auth/promote (Admin Only)`);
  console.log(`Phase 6B-1 Endpoints:`);
  console.log(`  GET   /api/notifications`);
  console.log(`  GET   /api/notifications/unread-count`);
  console.log(`  PATCH /api/notifications/:id/read`);
  console.log(`  POST  /api/notifications/read-all`);
  console.log(`Phase 6B-2 Endpoints:`);
  console.log(`  GET   /api/analytics/summary`);
  console.log(`  GET   /api/analytics/trends`);
  console.log(`  GET   /api/analytics/interventions`);
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
  notificationService,
  analyticsService,
  config,
  syncEngine,
  decisionEngine,
  closedLoop,
  weatherRiskEngine,
  explainabilityEngine,
  voiceAssistant,
  fieldAssistant,
  multimodalAssistant,
  historicalAnalytics,
};
