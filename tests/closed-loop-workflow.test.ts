import test from 'node:test';
import assert from 'node:assert';
import { RoverEngine } from '../services/rover-simulator/src/engine.js';
import { InMemoryAlertStore } from '../services/rover-simulator/src/alert-store.js';
import { DecisionEngine } from '../services/rover-simulator/src/decision-engine.js';
import { ClosedLoopCoordinator } from '../services/rover-simulator/src/closed-loop.js';
import { updateZoneMoisture } from '../services/rover-simulator/src/telemetry-gen.js';
import { RoverScanPayload } from '@prahar/shared';

test('Closed-Loop Workflow - Full end-to-end remediation & genuine verification', async () => {
  const engine = new RoverEngine({ roverId: 'ROVER-LOOP-01' });
  const alertStore = new InMemoryAlertStore();
  const decisionEngine = new DecisionEngine(alertStore);
  const coordinator = new ClosedLoopCoordinator(engine, decisionEngine, alertStore);

  const zoneId = 'DEMO-ZONE-02'; // Dry zone
  updateZoneMoisture(zoneId, 17.5);

  // 1. Initial Rover Scan (Pre-intervention)
  const initialScan: RoverScanPayload = {
    scan_id: 'scan-pre-loop-01',
    rover_id: engine.getRoverId(),
    zone_id: zoneId,
    gps: { latitude: 12.9734, longitude: 77.5934 },
    battery_pct: 95.0,
    timestamp: new Date().toISOString(),
    sensor_readings: [
      { zone_id: zoneId, type: 'moisture', value: 16.8, unit: '%', timestamp: new Date().toISOString(), source: 'probe' },
      { zone_id: zoneId, type: 'temperature', value: 33.5, unit: '°C', timestamp: new Date().toISOString(), source: 'probe' },
      { zone_id: zoneId, type: 'humidity', value: 45.0, unit: '%', timestamp: new Date().toISOString(), source: 'probe' },
      { zone_id: zoneId, type: 'ph', value: 6.5, unit: 'pH', timestamp: new Date().toISOString(), source: 'probe' },
    ],
    detections: [
      {
        id: 'det-pre-01',
        zone_id: zoneId,
        hazard_type: 'WATER_STRESS',
        hazard_name: 'Severe Root-Zone Moisture Deficit',
        confidence: 0.91,
        severity_hint: 'HIGH',
        timestamp: new Date().toISOString(),
        source: 'ai',
      },
    ],
  };

  // 2. Ingest Scan & Run Decision Engine
  const ingestResult = await coordinator.ingestScan(initialScan);
  assert.strictEqual(ingestResult.decision.overall_severity, 'HIGH');
  assert.ok(ingestResult.decision.action_recommendation);
  assert.strictEqual(ingestResult.decision.action_recommendation?.action_type, 'RECOMMEND_IRRIGATION');
  assert.strictEqual(ingestResult.decision.action_recommendation?.requires_approval, true);

  // 3. Safety Gate: Verify approval is mandatory
  assert.throws(
    () => {
      coordinator.approveIntervention({
        zone_id: zoneId,
        approved_by: '', // Empty approval must fail
      });
    },
    /Safety Gate Violation/,
    'Empty approval must throw'
  );

  // 4. Farmer or Expert Approves Intervention
  const intervention = coordinator.approveIntervention({
    zone_id: zoneId,
    approved_by: 'demo_farmer_alpha',
    duration_seconds: 30,
    volume_liters: 7.5,
    expert_note: 'Approved 30s micro-irrigation to relieve acute root-zone moisture deficit.',
  });
  assert.strictEqual(intervention.status, 'APPROVED');
  assert.strictEqual(intervention.approved_by, 'demo_farmer_alpha');

  // 5. Execute Approved Physical Action
  const executionAck = await coordinator.executeApprovedIntervention(intervention.action_id);
  assert.strictEqual(executionAck.status, 'COMPLETED');
  assert.strictEqual(executionAck.command_type, 'IRRIGATE');

  // 6. Re-Scan & Post-Intervention Verification
  const verification = await coordinator.verifyIntervention(intervention.action_id);

  // Genuine Before vs After Verification Metrics (Requirement 3)
  assert.strictEqual(verification.zone_id, zoneId);
  assert.strictEqual(verification.action_id, intervention.action_id);
  assert.strictEqual(verification.pre_moisture, 16.8);
  assert.ok(verification.post_moisture > verification.pre_moisture, 'Post-moisture must be higher than pre-moisture');
  assert.ok(verification.moisture_delta > 0, 'Moisture delta must be positive');
  assert.strictEqual(verification.resolved, true, 'Moisture should be above critical threshold');
  assert.ok(verification.summary_en.includes('verified'));
  assert.ok(verification.summary_hi.includes('सत्यापन'));

  // Verify alert state transitioned to RESOLVED
  const activeAlerts = alertStore.getAlerts({ zone_id: zoneId, status: 'NEW' });
  assert.strictEqual(activeAlerts.length, 0, 'Active alert should be resolved');
});

test('Expert Actions & Audit Logging - Triage actions create auditable records', async () => {
  const alertStore = new InMemoryAlertStore();

  // Seed sample alert
  const alert = alertStore.saveAlert({
    alert_id: 'alert-audit-01',
    zone_id: 'DEMO-ZONE-03',
    type: 'DISEASE',
    severity: 'MEDIUM',
    message: 'Suspected Early Blight',
    recommended_action: 'Inspect field',
    status: 'NEW',
    timestamp: new Date().toISOString(),
  });

  // Expert confirms diagnosis
  const auditRecord = {
    audit_id: 'audit-001',
    actor: 'dr_sharma_kvk_expert',
    timestamp: new Date().toISOString(),
    zone_id: alert.zone_id,
    alert_id: alert.alert_id,
    action: 'CONFIRM' as const,
    previous_state: 'NEW',
    new_state: 'ACKNOWLEDGED',
    expert_note: 'Early Blight confirmed based on leaf necrosis patterns.',
  };
  alertStore.recordAudit(auditRecord);

  const history = alertStore.getAuditHistory({ alert_id: alert.alert_id });
  assert.strictEqual(history.length, 1);
  assert.strictEqual(history[0].actor, 'dr_sharma_kvk_expert');
  assert.strictEqual(history[0].action, 'CONFIRM');
  assert.strictEqual(history[0].expert_note, 'Early Blight confirmed based on leaf necrosis patterns.');
});
