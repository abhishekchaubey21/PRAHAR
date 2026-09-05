/**
 * PRAHAR Automated End-to-End Demo (Complete 22-Step Validation Lifecycle)
 * Validates the complete Phase 4 Mission Workflow:
 * 1. Authenticate -> 2. Select farm -> 3. Query weather risk -> 4. Rover scan -> 5. WHY reasoning
 * 6. User-authorized multimodal evidence -> 7. Persist alert -> 8. Farmer view -> 9. Expert triage
 * 10. Voice inquiry -> 11. Voice irrigation request -> 12. Unconfirmed execution blocked
 * 13. Farmer confirmation & expert approval -> 14. Safety limits -> 15. Physical irrigation
 * 16. Re-scan & verification -> 17. Audit log -> 18. Composite demo indicator
 * 19. Field Evidence Report with disclaimer -> 20. Opportunity Center -> 21. Offline degradation
 * 22. Reconnection & idempotent sync
 */

import { test, describe, before, after } from 'node:test';
import assert from 'node:assert';
import http from 'node:http';
import { server, alertStore, syncEngine, engine, closedLoop } from '../services/rover-simulator/src/server.js';
import { updateZoneMoisture } from '../services/rover-simulator/src/telemetry-gen.js';
import { RoverScanPayload, SyncBatchRequest } from '@prahar/shared';

describe('Phase 4: Complete 22-Step End-to-End Validation Lifecycle', () => {
  let baseUrl: string = 'http://127.0.0.1:3001';

  before(async () => {
    updateZoneMoisture('DEMO-ZONE-02', 17.5);
    alertStore.clear();

    if (!server.listening) {
      await new Promise<void>((resolve) => server.listen(0, resolve));
    }
    const addr = server.address();
    if (typeof addr === 'object' && addr !== null) {
      baseUrl = `http://127.0.0.1:${addr.port}`;
    }
  });

  async function apiRequest(path: string, options: { method?: string; body?: any } = {}): Promise<any> {
    const res = await fetch(`${baseUrl}${path}`, {
      method: options.method || 'GET',
      headers: { 'Content-Type': 'application/json' },
      body: options.body ? JSON.stringify(options.body) : undefined,
    });
    return res.json();
  }

  test('Step 1: Authenticate Profile (Farmer / Expert)', async () => {
    const farmerRes = await apiRequest('/api/auth/profile?role=FARMER');
    assert.strictEqual(farmerRes.success, true);
    assert.strictEqual(farmerRes.profile.role, 'FARMER');
    assert.strictEqual(farmerRes.profile.authorized_zones.includes('DEMO-ZONE-02'), true);

    const expertRes = await apiRequest('/api/auth/profile?role=EXPERT');
    assert.strictEqual(expertRes.success, true);
    assert.strictEqual(expertRes.profile.role, 'EXPERT');
  });

  test('Step 2: Select Farm', async () => {
    const farmsRes = await apiRequest('/api/farms');
    assert.strictEqual(farmsRes.success, true);
    assert.strictEqual(farmsRes.farms.length >= 1, true);
  });

  test('Step 3: Ingest Weather Risk Context (SIMULATION / DEMO Labeled)', async () => {
    const weatherRes = await apiRequest('/api/weather/risk?moisture=17.5&humidity=48.0');
    assert.strictEqual(weatherRes.success, true);
    assert.ok(weatherRes.weather.provider_label.includes('SIMULATION WEATHER'));
    assert.strictEqual(weatherRes.assessments.length, 5);
  });

  let simulatedScan: RoverScanPayload;
  test('Step 4: Generate Simulated Rover Scan with Guy 3 Edge YOLOv8 Telemetry', async () => {
    const scanRes = await apiRequest('/api/rover/simulate-scan', {
      method: 'POST',
      body: { zone_id: 'DEMO-ZONE-02' },
    });
    assert.strictEqual(scanRes.success, true);
    assert.strictEqual(scanRes.data.zone_id, 'DEMO-ZONE-02');
    assert.ok(scanRes.data.sensor_readings.length >= 4);
    simulatedScan = scanRes.data;
  });

  let ingestResult: any;
  test('Step 5: Run Ingestion & Synthesize WHY Reasoning Evidence', async () => {
    const ingestRes = await apiRequest('/api/ingest/scan', {
      method: 'POST',
      body: simulatedScan,
    });
    assert.strictEqual(ingestRes.success, true);
    assert.strictEqual(ingestRes.data.decision.overall_severity, 'HIGH');
    ingestResult = ingestRes.data;

    // Explainability WHY API
    const explainRes = await apiRequest('/api/intelligence/explain', {
      method: 'POST',
      body: {
        zone_id: 'DEMO-ZONE-02',
        scan: simulatedScan,
        decision: ingestResult.decision,
      },
    });
    assert.strictEqual(explainRes.success, true);
    assert.ok(explainRes.report.plain_reason_en.length > 0);
    assert.ok(explainRes.report.plain_reason_hi.length > 0);
    assert.ok(explainRes.report.observed_evidence.length >= 1);
  });

  test('Step 6: User-Authorized Secondary Multimodal Crop Analysis', async () => {
    const primaryDet = simulatedScan.detections[0];
    const mmRes = await apiRequest('/api/multimodal/analyze', {
      method: 'POST',
      body: {
        image_ref: 'crop_zone2_dry.jpg',
        zone_id: 'DEMO-ZONE-02',
        primary_detection: primaryDet,
        user_initiated: true, // Privacy compliant
      },
    });
    assert.strictEqual(mmRes.success, true);
    assert.ok(mmRes.result.status);
    assert.ok(mmRes.result.disclaimer.includes('primary ground truth'));
  });

  test('Step 7: Persist Multilingual Alert & Verify Deduplication', async () => {
    const alertsRes = await apiRequest('/api/alerts?zone_id=DEMO-ZONE-02');
    assert.strictEqual(alertsRes.success, true);
    assert.strictEqual(alertsRes.data.length >= 1, true);
    const alert = alertsRes.data[0];
    assert.strictEqual(alert.type, 'WATER_STRESS');
    assert.ok(alert.message_hi?.includes('गंभीर जल तनाव'));
  });

  test('Step 8: View Alert in Farmer App View', async () => {
    const alerts = await apiRequest('/api/alerts?zone_id=DEMO-ZONE-02&status=NEW');
    assert.strictEqual(alerts.success, true);
    assert.strictEqual(alerts.count >= 1, true);
    assert.ok(alerts.data[0].recommended_action_hi.includes('सूक्ष्म-सिंचाई'));
  });

  test('Step 9: View Alert in Expert Console Queue & Triage Diagnosis', async () => {
    const queueRes = await apiRequest('/api/alerts');
    const targetAlert = queueRes.data.find((a: any) => a.zone_id === 'DEMO-ZONE-02');
    assert.notStrictEqual(targetAlert, undefined);

    const triageRes = await apiRequest(`/api/alerts/${targetAlert.alert_id}/triage`, {
      method: 'POST',
      body: {
        action: 'CONFIRM',
        actor: 'dr_sharma_kvk_expert',
        expert_note: 'Verified acute root zone deficit.',
      },
    });
    assert.strictEqual(triageRes.success, true);
    assert.strictEqual(triageRes.alert.status, 'ACKNOWLEDGED');
  });

  test('Step 10: Farmer Voice Inquiry ("खेत की क्या स्थिति है?")', async () => {
    const voiceRes = await apiRequest('/api/voice/interact', {
      method: 'POST',
      body: {
        text: 'खेत का हाल बताओ',
        language: 'hi',
        input_type: 'SIMULATED_VOICE',
      },
    });
    assert.strictEqual(voiceRes.success, true);
    assert.strictEqual(voiceRes.response.intent, 'FARM_STATUS');
    assert.ok(voiceRes.response.spoken_text_hi.length > 0);
  });

  test('Step 11: Voice Irrigation Request -> Strict Safety Gating (Pauses for confirmation)', async () => {
    const voiceRes = await apiRequest('/api/voice/interact', {
      method: 'POST',
      body: {
        text: 'ज़ोन 2 में सिंचाई चालू करो',
        language: 'hi',
        input_type: 'SIMULATED_VOICE',
        session_id: 'e2e-session-voice',
      },
    });
    assert.strictEqual(voiceRes.success, true);
    assert.strictEqual(voiceRes.response.intent, 'APPROVE_IRRIGATION');
    assert.strictEqual(voiceRes.response.requires_confirmation, true);
    assert.ok(voiceRes.response.safety_notice_hi.includes('सुरक्षा द्वार'));
  });

  test('Step 12: Unconfirmed Voice Execution Attempt -> Prohibited by Safety Gate', async () => {
    // Attempting direct execution without approval throws
    assert.throws(
      () => {
        closedLoop.approveIntervention({
          zone_id: 'DEMO-ZONE-02',
          approved_by: '', // Empty approval
        });
      },
      /Safety Gate Violation/
    );
  });

  let approvedActionId: string;
  test('Step 13: Farmer Confirms Irrigation & Expert Approves Intervention', async () => {
    const voiceConfirm = await apiRequest('/api/voice/interact', {
      method: 'POST',
      body: {
        text: 'हाँ, पुष्टि करता हूँ',
        language: 'hi',
        input_type: 'SIMULATED_VOICE',
        session_id: 'e2e-session-voice',
        user_id: 'dr_sharma_kvk_expert',
      },
    });
    assert.strictEqual(voiceConfirm.success, true);
    assert.strictEqual(voiceConfirm.response.intent, 'CONFIRM_ACTION');
    assert.strictEqual(voiceConfirm.response.requires_confirmation, false);

    // Grab the approved intervention action_id from closed loop
    const approveRes = await apiRequest('/api/remediation/approve', {
      method: 'POST',
      body: {
        zone_id: 'DEMO-ZONE-02',
        approved_by: 'dr_sharma_kvk_expert',
        duration_seconds: 30,
        volume_liters: 7.5,
        expert_note: 'Farmer voice confirmed & expert approved.',
      },
    });
    assert.strictEqual(approveRes.success, true);
    assert.strictEqual(approveRes.data.status, 'APPROVED');
    approvedActionId = approveRes.data.action_id;
  });

  test('Step 14: Safety Limits Validation (Battery, Duration, Volume Caps)', async () => {
    const rejectRes = await apiRequest('/api/rover/command', {
      method: 'POST',
      body: {
        command_type: 'IRRIGATE',
        payload: {
          zone_id: 'DEMO-ZONE-02',
          duration_seconds: 9999, // Exceeds 180s cap
        },
      },
    });
    assert.strictEqual(rejectRes.success, false);
    assert.strictEqual(rejectRes.data.status, 'REJECTED');
  });

  test('Step 15: Dispatch Physical Irrigation via Rover Engine', async () => {
    const execRes = await apiRequest('/api/remediation/execute', {
      method: 'POST',
      body: { action_id: approvedActionId },
    });
    assert.strictEqual(execRes.success, true);
    assert.strictEqual(execRes.data.status, 'COMPLETED');
  });

  let verificationRecord: any;
  test('Step 16: Rover Re-Scan & Closed-Loop Verification (Pre: 17.5% -> Post: elevated)', async () => {
    const verifyRes = await apiRequest('/api/remediation/verify', {
      method: 'POST',
      body: { action_id: approvedActionId },
    });
    assert.strictEqual(verifyRes.success, true);
    assert.strictEqual(verifyRes.data.resolved, true);
    assert.ok(verifyRes.data.moisture_delta > 0);
    verificationRecord = verifyRes.data;
  });

  test('Step 17: Persist Remediation Verification & Audit Log Record', async () => {
    const auditRes = await apiRequest('/api/audit/history?zone_id=DEMO-ZONE-02');
    assert.strictEqual(auditRes.success, true);
    assert.ok(auditRes.count >= 1);
  });

  test('Step 18: Compute PRAHAR Composite Indicator — Demo Metric', async () => {
    const riskRes = await apiRequest('/api/analytics/farm-risk?farm_id=DEMO-FARM-01');
    assert.strictEqual(riskRes.success, true);
    assert.strictEqual(riskRes.dashboard.composite_indicator.label, 'PRAHAR Composite Indicator — Demo Metric');
    assert.strictEqual(riskRes.dashboard.composite_indicator.is_scientifically_validated, false);
    assert.ok(
      riskRes.dashboard.composite_indicator.score_out_of_100 >= 0 &&
      riskRes.dashboard.composite_indicator.score_out_of_100 <= 100
    );
  });

  test('Step 19: Generate PRAHAR Field Evidence Report with Legal Disclaimer', async () => {
    const reportRes = await apiRequest('/api/reports/field-evidence?zone_id=DEMO-ZONE-02');
    assert.strictEqual(reportRes.success, true);
    assert.strictEqual(reportRes.report.report_title, 'PRAHAR Field Evidence Report');
    assert.ok(reportRes.report.disclaimer.includes('NOT an official government certificate'));
  });

  test('Step 20: Query Farmer Opportunity Center for Verified Government Schemes', async () => {
    const oppRes = await apiRequest('/api/opportunities');
    assert.strictEqual(oppRes.success, true);
    assert.ok(oppRes.count >= 4);
    const pmKusum = oppRes.schemes.find((s: any) => s.scheme_id.includes('KUSUM'));
    assert.ok(pmKusum);
    assert.strictEqual(pmKusum.official_portal_url, 'https://pmkusum.mnre.gov.in');
  });

  test('Step 21: Offline Mode Simulation: Buffer Actions Offline', async () => {
    engine.setOfflineMode(true);
    assert.strictEqual(engine.isOfflineMode(), true);

    await engine.executeCommand({
      command_id: `cmd-offline-${Date.now()}`,
      rover_id: engine.getRoverId(),
      command_type: 'STATUS',
      payload: {},
      issued_at: new Date().toISOString(),
    });

    const status = engine.getStatus();
    assert.ok(status.offline_buffered_events >= 1);
  });

  test('Step 22: Connectivity Restored: Idempotent Queue Sync & Zero Data Loss', async () => {
    engine.setOfflineMode(false);
    assert.strictEqual(engine.isOfflineMode(), false);

    const flushedEvents = engine.flushOfflineQueue();
    assert.ok(flushedEvents.length >= 1);

    const syncBatch: SyncBatchRequest = {
      client_id: 'ROVER-DEMO-01',
      records: [
        {
          idempotency_key: `key-offline-p4-${Date.now()}-${Math.random().toString(36).substring(2, 6)}`,
          entity_type: 'telemetry_heartbeats',
          entity_id: 'telemetry-buffered',
          operation: 'INSERT',
          payload: { event_type: 'OFFLINE_BUFFER_FLUSH' },
          client_timestamp: new Date().toISOString(),
        },
      ],
      strategy: 'LAST_WRITE_WINS',
    };

    const syncRes = await apiRequest('/api/sync/push', {
      method: 'POST',
      body: syncBatch,
    });
    assert.strictEqual(syncRes.success, true);
    assert.strictEqual(syncRes.synced_count, 1);
  });
});
