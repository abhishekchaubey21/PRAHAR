import test from 'node:test';
import assert from 'node:assert';
import { DecisionEngine } from '../services/rover-simulator/src/decision-engine.js';
import { InMemoryAlertStore } from '../services/rover-simulator/src/alert-store.js';
import { RoverScanPayload, DECISION_THRESHOLDS } from '@prahar/shared';

function createMockScan(params: {
  zoneId: string;
  moisture: number;
  temp: number;
  humidity: number;
  detections?: any[];
}): RoverScanPayload {
  return {
    scan_id: `scan-mock-${Date.now()}`,
    rover_id: 'ROVER-MOCK-01',
    zone_id: params.zoneId,
    gps: { latitude: 12.9716, longitude: 77.5946 },
    battery_pct: 90.0,
    timestamp: new Date().toISOString(),
    sensor_readings: [
      { zone_id: params.zoneId, type: 'moisture', value: params.moisture, unit: '%', timestamp: new Date().toISOString(), source: 'probe' },
      { zone_id: params.zoneId, type: 'temperature', value: params.temp, unit: '°C', timestamp: new Date().toISOString(), source: 'probe' },
      { zone_id: params.zoneId, type: 'humidity', value: params.humidity, unit: '%', timestamp: new Date().toISOString(), source: 'probe' },
      { zone_id: params.zoneId, type: 'ph', value: 6.5, unit: 'pH', timestamp: new Date().toISOString(), source: 'probe' },
    ],
    detections: params.detections || [],
  };
}

test('Decision Engine - Rule 1: Heat stress & low moisture triggers HIGH severity water stress with mandatory approval', async () => {
  const store = new InMemoryAlertStore();
  const engine = new DecisionEngine(store);

  // Moisture 18% (< 20% critical) and Temp 35°C (> 32°C heat stress)
  const scan = createMockScan({
    zoneId: 'DEMO-ZONE-02',
    moisture: 18.0,
    temp: 35.0,
    humidity: 40.0,
  });

  const result = await engine.evaluateScan(scan);

  assert.strictEqual(result.zone_id, 'DEMO-ZONE-02');
  assert.strictEqual(result.overall_severity, 'HIGH');
  assert.ok(result.action_recommendation, 'Action recommendation must be generated');
  assert.strictEqual(result.action_recommendation?.action_type, 'RECOMMEND_IRRIGATION');
  assert.strictEqual(result.action_recommendation?.requires_approval, true, 'Safety Gate: must require approval');
  assert.strictEqual(result.action_recommendation?.approval_status, 'PENDING_APPROVAL');

  // Verify alert created in store
  const alerts = store.getAlerts({ zone_id: 'DEMO-ZONE-02' });
  assert.strictEqual(alerts.length, 1);
  assert.strictEqual(alerts[0].type, 'WATER_STRESS');
  assert.strictEqual(alerts[0].severity, 'HIGH');
  assert.ok(alerts[0].message_hi, 'Must contain Hindi localized advisory');
});

test('Decision Engine - Rule 2: Fungal disease with high humidity triggers amplified HIGH severity risk', async () => {
  const store = new InMemoryAlertStore();
  const engine = new DecisionEngine(store);

  // High humidity (78% > 70% threshold) with Early Blight disease (conf = 0.88 >= 0.70)
  const scan = createMockScan({
    zoneId: 'DEMO-ZONE-03',
    moisture: 35.0,
    temp: 28.0,
    humidity: 78.0,
    detections: [
      {
        id: 'det-01',
        zone_id: 'DEMO-ZONE-03',
        hazard_type: 'DISEASE',
        hazard_name: 'Early Blight (Alternaria solani)',
        confidence: 0.88,
        severity_hint: 'MEDIUM',
        timestamp: new Date().toISOString(),
        source: 'cam',
      },
    ],
  });

  const result = await engine.evaluateScan(scan);

  // Disease severity should be amplified to HIGH due to high humidity microclimate
  assert.strictEqual(result.overall_severity, 'HIGH');
  assert.strictEqual(result.requires_expert_review, true, 'Diseases must route to expert review');

  const alerts = store.getAlerts({ zone_id: 'DEMO-ZONE-03' });
  assert.strictEqual(alerts.length, 1);
  assert.strictEqual(alerts[0].severity, 'HIGH');
  assert.ok(alerts[0].message.includes('Early Blight'));
  assert.ok(alerts[0].message_hi?.includes('Early Blight'));
});

test('Decision Engine - Rule 3: Confidence Gating (< 0.70) suppresses physical action and routes to expert review', async () => {
  const store = new InMemoryAlertStore();
  const engine = new DecisionEngine(store);

  // Detection with low confidence (0.62 < 0.70 threshold)
  const scan = createMockScan({
    zoneId: 'DEMO-ZONE-01',
    moisture: 36.0,
    temp: 26.0,
    humidity: 55.0,
    detections: [
      {
        id: 'det-low-01',
        zone_id: 'DEMO-ZONE-01',
        hazard_type: 'DISEASE',
        hazard_name: 'Uncertain Foliar Lesions',
        confidence: 0.62,
        severity_hint: 'MEDIUM',
        timestamp: new Date().toISOString(),
        source: 'cam',
      },
    ],
  });

  const result = await engine.evaluateScan(scan);

  // Confidence gating: physical action must NOT be recommended, must require expert review
  assert.strictEqual(result.requires_expert_review, true);
  assert.strictEqual(result.action_recommendation, undefined, 'Physical action must be suppressed for low confidence');

  const alerts = store.getAlerts({ zone_id: 'DEMO-ZONE-01' });
  assert.strictEqual(alerts.length, 1);
  assert.ok(alerts[0].message.includes('[Needs Expert Review]'));
  assert.ok(alerts[0].message_hi?.includes('[विशेषज्ञ समीक्षा आवश्यक]'));
});

test('Decision Engine - Rule 4: 24-hour alert deduplication prevents duplicate active alerts on repeated scans', async () => {
  const store = new InMemoryAlertStore();
  const engine = new DecisionEngine(store);

  const scan1 = createMockScan({
    zoneId: 'DEMO-ZONE-02',
    moisture: 17.0,
    temp: 34.0,
    humidity: 42.0,
  });

  // First scan cycle
  const result1 = await engine.evaluateScan(scan1);
  assert.strictEqual(result1.alerts_to_create.length, 1);
  assert.strictEqual(store.getAlerts().length, 1);
  assert.strictEqual(store.getAlerts()[0].occurrence_count, 1);

  // Second scan cycle 10 minutes later for identical zone and hazard
  const scan2 = createMockScan({
    zoneId: 'DEMO-ZONE-02',
    moisture: 16.5,
    temp: 34.5,
    humidity: 41.0,
  });

  const result2 = await engine.evaluateScan(scan2);
  // Deduplicated: should NOT create a new alert, but update the existing one
  assert.strictEqual(result2.alerts_to_create.length, 0);
  assert.strictEqual(result2.alerts_updated.length, 1);
  assert.strictEqual(store.getAlerts().length, 1, 'Store must still have exactly 1 active alert');
  assert.strictEqual(store.getAlerts()[0].occurrence_count, 2, 'Occurrence count should increment to 2');
});

test('Decision Engine - Threshold boundary tests', async () => {
  const store = new InMemoryAlertStore();
  const engine = new DecisionEngine(store);

  // Test at exactly 19.9% moisture (critical) vs 20.1% moisture with moderate temp
  const scanCritical = createMockScan({ zoneId: 'ZONE-T1', moisture: 19.9, temp: 25.0, humidity: 50.0 });
  const resultCritical = await engine.evaluateScan(scanCritical);
  assert.strictEqual(resultCritical.overall_severity, 'HIGH', 'Moisture < 20% must be HIGH');

  store.clear();
  const scanNormal = createMockScan({ zoneId: 'ZONE-T2', moisture: 26.0, temp: 28.0, humidity: 50.0 });
  const resultNormal = await engine.evaluateScan(scanNormal);
  assert.strictEqual(resultNormal.overall_severity, 'LOW', 'Normal moisture must be LOW');
  assert.strictEqual(resultNormal.action_recommendation, undefined);
});
