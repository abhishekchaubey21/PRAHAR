/**
 * PRAHAR Automated End-to-End Demo (20-Step Validation Lifecycle)
 * Validates the complete Phase 3 mission workflow:
 * 1. Authenticate -> 2. Select farm -> 3. View zones -> 4. Ingest scan -> 5. Decision Engine
 * 6. Persist alert -> 7. Farmer view -> 8. Expert console -> 9. Approve -> 10. Irrigate
 * 11. Re-scan -> 12. Generate verification -> 13. Persist verification -> 14. Before/After -> 15. Audit trail
 * 16. Toggle offline -> 17. Offline event -> 18. Restore connectivity -> 19. Sync event -> 20. Confirm persistence
 */

import { test, describe, before, after } from 'node:test';
import assert from 'node:assert';
import http from 'node:http';
import { server, alertStore, syncEngine, engine, closedLoop } from '../services/rover-simulator/src/server.js';
import { updateZoneMoisture } from '../services/rover-simulator/src/telemetry-gen.js';
import { SyncBatchRequest } from '@prahar/shared';

describe('Phase 3: 20-Step End-to-End Validation Lifecycle', () => {
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
    assert.strictEqual(farmsRes.farms[0].id, 'FARM-DEMO-01');
  });

  test('Step 3: View Zones & Initial Soil Health Status', async () => {
    const zonesRes = await apiRequest('/api/zones?farm_id=FARM-DEMO-01');
    assert.strictEqual(zonesRes.success, true);
    assert.strictEqual(zonesRes.zones.length, 4);
    const targetZone = zonesRes.zones.find((z: any) => z.id === 'DEMO-ZONE-02');
    assert.notStrictEqual(targetZone, undefined);
    assert.strictEqual(targetZone.status, 'WATER_STRESS');
  });

  let simulatedScan: any;
  test('Step 4: Generate Simulated Rover Scan', async () => {
    const scanRes = await apiRequest('/api/rover/simulate-scan', {
      method: 'POST',
      body: { zone_id: 'DEMO-ZONE-02' },
    });
    assert.strictEqual(scanRes.success, true);
    assert.strictEqual(scanRes.data.zone_id, 'DEMO-ZONE-02');
    simulatedScan = scanRes.data;
  });

  let ingestResult: any;
  test('Step 5 & 6: Run Decision Engine & Persist Alert', async () => {
    const ingestRes = await apiRequest('/api/ingest/scan', {
      method: 'POST',
      body: simulatedScan,
    });
    assert.strictEqual(ingestRes.success, true);
    assert.strictEqual(ingestRes.data.decision.overall_severity, 'HIGH');
    ingestResult = ingestRes.data;

    // Verify persisted alert in database/file store
    const alertsRes = await apiRequest('/api/alerts?zone_id=DEMO-ZONE-02');
    assert.strictEqual(alertsRes.success, true);
    assert.strictEqual(alertsRes.data.length >= 1, true);
    const persistedAlert = alertsRes.data[0];
    assert.strictEqual(persistedAlert.type, 'WATER_STRESS');
    assert.strictEqual(persistedAlert.message_hi?.includes('गंभीर जल तनाव'), true);
  });

  test('Step 7: View Alert in Farmer App View', async () => {
    const alerts = await apiRequest('/api/alerts?zone_id=DEMO-ZONE-02&status=NEW');
    assert.strictEqual(alerts.success, true);
    assert.strictEqual(alerts.count >= 1, true);
    // Verifies bilingual display capability
    assert.strictEqual(alerts.data[0].recommended_action_hi.includes('सूक्ष्म-सिंचाई'), true);
  });

  test('Step 8: View Alert in Expert Console Queue & Triage Diagnosis', async () => {
    const queueRes = await apiRequest('/api/alerts');
    assert.strictEqual(queueRes.success, true);
    const targetAlert = queueRes.data.find((a: any) => a.zone_id === 'DEMO-ZONE-02');
    assert.notStrictEqual(targetAlert, undefined);

    // Expert confirms diagnosis
    const triageRes = await apiRequest(`/api/alerts/${targetAlert.alert_id}/triage`, {
      method: 'POST',
      body: {
        action: 'CONFIRM',
        actor: 'dr_sharma_kvk_expert',
        expert_note: 'Visual confirmation of water stress symptoms.',
      },
    });
    assert.strictEqual(triageRes.success, true);
    assert.strictEqual(triageRes.alert.status, 'ACKNOWLEDGED');
  });

  let approvedActionId: string;
  test('Step 9: Approve Irrigation (Safety Gate Satisfied)', async () => {
    const approveRes = await apiRequest('/api/remediation/approve', {
      method: 'POST',
      body: {
        zone_id: 'DEMO-ZONE-02',
        approved_by: 'dr_sharma_kvk_expert',
        duration_seconds: 30,
        volume_liters: 7.5,
        expert_note: 'Approved 30s micro-irrigation.',
      },
    });
    assert.strictEqual(approveRes.success, true);
    assert.strictEqual(approveRes.data.status, 'APPROVED');
    approvedActionId = approveRes.data.action_id;
  });

  test('Step 10: Execute Simulated Irrigation via Rover Engine', async () => {
    const execRes = await apiRequest('/api/remediation/execute', {
      method: 'POST',
      body: { action_id: approvedActionId },
    });
    assert.strictEqual(execRes.success, true);
    assert.strictEqual(execRes.data.status, 'COMPLETED');
  });

  let verificationRecord: any;
  test('Step 11, 12 & 13: Re-Scan, Generate Verification & Persist Verification', async () => {
    const verifyRes = await apiRequest('/api/remediation/verify', {
      method: 'POST',
      body: { action_id: approvedActionId },
    });
    assert.strictEqual(verifyRes.success, true);
    assert.strictEqual(verifyRes.data.resolved, true);
    assert.strictEqual(verifyRes.data.moisture_delta > 0, true);
    verificationRecord = verifyRes.data;
  });

  test('Step 14: Display Before/After Comparison Result', async () => {
    const verifsRes = await apiRequest('/api/remediation/verifications?zone_id=DEMO-ZONE-02');
    assert.strictEqual(verifsRes.success, true);
    assert.strictEqual(verifsRes.count >= 1, true);
    const verif = verifsRes.data[0];
    assert.strictEqual(verif.pre_moisture < verif.post_moisture, true);
    assert.strictEqual(verif.summary_hi.includes('उपचार का सत्यापन'), true);
  });

  test('Step 15: Verify Immutable Audit Trail', async () => {
    const auditRes = await apiRequest('/api/audit/history?zone_id=DEMO-ZONE-02');
    assert.strictEqual(auditRes.success, true);
    assert.strictEqual(auditRes.count >= 2, true); // Confirmation + Approval
    const approvalAudit = auditRes.data.find((a: any) => a.action === 'APPROVE_INTERVENTION');
    assert.notStrictEqual(approvalAudit, undefined);
    assert.strictEqual(approvalAudit.actor, 'dr_sharma_kvk_expert');
  });

  test('Step 16 & 17: Toggle Offline Mode & Generate Offline Event', async () => {
    // 16. Toggle offline
    const offRes = await apiRequest('/api/rover/offline-mode', {
      method: 'POST',
      body: { enabled: true },
    });
    assert.strictEqual(offRes.success, true);
    assert.strictEqual(offRes.offline_mode, true);

    // 17. Generate event while offline
    const scanOffRes = await apiRequest('/api/rover/simulate-scan', {
      method: 'POST',
      body: { zone_id: 'DEMO-ZONE-04' },
    });
    assert.strictEqual(scanOffRes.success, true);

    // Inspect queue
    const queueRes = await apiRequest('/api/rover/queue');
    assert.strictEqual(queueRes.success, true);
    assert.strictEqual(queueRes.buffered_count >= 1, true);
  });

  test('Step 18, 19 & 20: Restore Connectivity, Synchronize Event & Confirm Persistence', async () => {
    // 18. Restore connectivity
    const onRes = await apiRequest('/api/rover/offline-mode', {
      method: 'POST',
      body: { enabled: false },
    });
    assert.strictEqual(onRes.success, true);
    assert.strictEqual(onRes.offline_mode, false);

    // Drain rover queue
    const flushRes = await apiRequest('/api/rover/flush-queue', { method: 'POST' });
    assert.strictEqual(flushRes.success, true);
    assert.strictEqual(flushRes.flushed_count >= 1, true);

    // 19. Synchronize event batch through SyncEngine
    const batch: SyncBatchRequest = {
      client_id: 'ROVER-DEMO-01',
      records: [
        {
          event_id: `evt-offline-reconnect-${Date.now()}`,
          idempotency_key: `idemp-offline-reconnect-${Date.now()}`,
          rover_id: 'ROVER-DEMO-01',
          entity_type: 'SCAN_PAYLOAD',
          action: 'INSERT',
          payload: flushRes.events[0].payload,
          status: 'PENDING',
          retry_count: 0,
          max_retries: 3,
          buffered_at: flushRes.events[0].buffered_at,
          client_timestamp: flushRes.events[0].buffered_at,
        },
      ],
    };

    const syncRes = await apiRequest('/api/sync/push', {
      method: 'POST',
      body: batch,
    });
    assert.strictEqual(syncRes.success, true);
    assert.strictEqual(syncRes.synced_count, 1);
    assert.strictEqual(syncRes.duplicate_count, 0);

    // 20. Confirm persistence after synchronization & verify idempotency on retry
    const syncStatus = await apiRequest('/api/sync/status');
    assert.strictEqual(syncStatus.success, true);
    assert.strictEqual(syncStatus.data.is_online, true);

    // Duplicate push check
    const dupRes = await apiRequest('/api/sync/push', {
      method: 'POST',
      body: batch,
    });
    assert.strictEqual(dupRes.duplicate_count, 1);
    assert.strictEqual(dupRes.synced_count, 0);
  });
});
