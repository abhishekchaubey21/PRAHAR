import test from 'node:test';
import assert from 'node:assert';
import {
  validateSensorBundle,
  validateTelemetry,
  validateDetection,
  validateCommand,
  validateScanPayload,
} from '../packages/shared/src/index.js';

test('Shared Contracts - Sensor bundle validation', () => {
  const validBundle = {
    moisture_pct: 35.0,
    temperature_c: 28.5,
    humidity_pct: 60.0,
    ph: 6.5,
    timestamp: new Date().toISOString(),
  };
  assert.strictEqual(validateSensorBundle(validBundle).valid, true);

  const invalidBundle = {
    moisture_pct: 120.0, // Invalid > 100%
    temperature_c: -50.0, // Invalid extreme
    humidity_pct: -5.0,
    ph: 16.0, // Invalid > 14
  };
  const result = validateSensorBundle(invalidBundle);
  assert.strictEqual(result.valid, false);
  assert.strictEqual(result.errors.length, 4);
});

test('Shared Contracts - Telemetry validation', () => {
  const validTelemetry = {
    rover_id: 'ROVER-01',
    zone_id: 'ZONE-A',
    gps: { latitude: 12.9716, longitude: 77.5946 },
    battery_pct: 85.0,
    status: 'IDLE' as const,
    tilt_deg: 0.5,
    fault_flags: [],
    timestamp: new Date().toISOString(),
  };
  assert.strictEqual(validateTelemetry(validTelemetry).valid, true);

  const invalidTelemetry = {
    rover_id: '',
    zone_id: 'ZONE-A',
    gps: { latitude: 95.0, longitude: 200.0 }, // Invalid lat/long
    battery_pct: -10, // Invalid
    status: 'FLYING' as any, // Invalid status
  };
  const result = validateTelemetry(invalidTelemetry);
  assert.strictEqual(result.valid, false);
  assert.ok(result.errors.length >= 3);
});

test('Shared Contracts - Detection validation', () => {
  const validDetection = {
    zone_id: 'ZONE-B',
    hazard_type: 'DISEASE' as const,
    hazard_name: 'Early Blight',
    confidence: 0.88,
    severity_hint: 'MEDIUM' as const,
    timestamp: new Date().toISOString(),
    source: 'rover_camera',
  };
  assert.strictEqual(validateDetection(validDetection).valid, true);

  const invalidDetection = {
    zone_id: '',
    hazard_type: 'UNKNOWN_HAZARD' as any,
    hazard_name: '',
    confidence: 1.5, // Invalid > 1.0
    severity_hint: 'SUPER_CRITICAL' as any,
  };
  const result = validateDetection(invalidDetection);
  assert.strictEqual(result.valid, false);
  assert.ok(result.errors.length >= 4);
});

test('Shared Contracts - Command validation', () => {
  // Valid command
  const validCmd = {
    command_id: 'cmd-1',
    rover_id: 'ROVER-01',
    command_type: 'START_SCAN' as const,
    payload: { zone_id: 'ZONE-1' },
    issued_at: new Date().toISOString(),
  };
  assert.strictEqual(validateCommand(validCmd).valid, true);

  // Missing zone_id
  const invalidScanCmd = {
    command_id: 'cmd-2',
    rover_id: 'ROVER-01',
    command_type: 'START_SCAN' as const,
    payload: {},
    issued_at: new Date().toISOString(),
  };
  assert.strictEqual(validateCommand(invalidScanCmd).valid, false);

  // Invalid command type
  const badTypeCmd = {
    command_id: 'cmd-3',
    rover_id: 'ROVER-01',
    command_type: 'EXPLODE' as any,
    payload: {},
    issued_at: new Date().toISOString(),
  };
  assert.strictEqual(validateCommand(badTypeCmd).valid, false);
});
