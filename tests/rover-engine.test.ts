import test from 'node:test';
import assert from 'node:assert';
import { RoverEngine } from '../services/rover-simulator/src/engine.ts';
import { validateSensorBundle, validateTelemetry } from '../packages/shared/src/telemetry.ts';
import { validateDetection } from '../packages/shared/src/detection.ts';

test('RoverEngine - initialization and default status', () => {
  const engine = new RoverEngine({ roverId: 'TEST-ROVER-01' });
  assert.strictEqual(engine.getRoverId(), 'TEST-ROVER-01');
  assert.strictEqual(engine.getState(), 'IDLE');
  assert.strictEqual(engine.getCurrentZoneId(), 'DEMO-ZONE-01');
  assert.strictEqual(engine.isOfflineMode(), false);

  const status = engine.getStatus();
  assert.strictEqual(status.rover_id, 'TEST-ROVER-01');
  assert.strictEqual(status.state, 'IDLE');
  assert.strictEqual(status.offline_buffered_events, 0);
});

test('RoverEngine - simulated scan cycle generates valid agronomic telemetry and detections', () => {
  const engine = new RoverEngine({ roverId: 'TEST-ROVER-01' });
  const scanPayload = engine.simulateScanCycle('DEMO-ZONE-02');

  assert.strictEqual(scanPayload.zone_id, 'DEMO-ZONE-02');
  assert.strictEqual(scanPayload.rover_id, 'TEST-ROVER-01');
  assert.ok(scanPayload.sensor_readings.length >= 4, 'Must have at least 4 sensor readings');

  // Verify telemetry readings
  const moistureReading = scanPayload.sensor_readings.find((r) => r.type === 'moisture');
  const tempReading = scanPayload.sensor_readings.find((r) => r.type === 'temperature');
  const humReading = scanPayload.sensor_readings.find((r) => r.type === 'humidity');
  const phReading = scanPayload.sensor_readings.find((r) => r.type === 'ph');

  assert.ok(moistureReading, 'Moisture reading present');
  assert.ok(tempReading, 'Temperature reading present');
  assert.ok(humReading, 'Humidity reading present');
  assert.ok(phReading, 'pH reading present');

  const bundleValidation = validateSensorBundle({
    moisture_pct: moistureReading?.value,
    temperature_c: tempReading?.value,
    humidity_pct: humReading?.value,
    ph: phReading?.value,
    timestamp: new Date().toISOString(),
  });
  assert.strictEqual(bundleValidation.valid, true, `Sensor bundle invalid: ${bundleValidation.errors.join(', ')}`);

  // Verify telemetry heartbeat
  const telemetry = engine.getTelemetry();
  const telemetryValidation = validateTelemetry(telemetry);
  assert.strictEqual(telemetryValidation.valid, true, `Telemetry invalid: ${telemetryValidation.errors.join(', ')}`);

  // Verify detections if any
  for (const det of scanPayload.detections) {
    const detValidation = validateDetection(det);
    assert.strictEqual(detValidation.valid, true, `Detection invalid: ${detValidation.errors.join(', ')}`);
  }
});

test('RoverEngine - simulated irrigation updates moisture safely', () => {
  const engine = new RoverEngine();
  const result = engine.simulateIrrigation({
    zoneId: 'DEMO-ZONE-02',
    durationSeconds: 30,
  });

  assert.strictEqual(result.zone_id, 'DEMO-ZONE-02');
  assert.strictEqual(result.duration_seconds, 30);
  assert.ok(result.volume_liters > 0, 'Volume must be positive');
  assert.ok(result.moisture_after_pct >= result.moisture_before_pct, 'Moisture should increase after irrigation');
  assert.strictEqual(engine.getState(), 'IDLE');
});
