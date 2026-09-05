import test from 'node:test';
import assert from 'node:assert';
import { RoverEngine } from '../services/rover-simulator/src/engine.js';
import { RoverCommand } from '../packages/shared/src/commands.js';

test('Command Idempotency - duplicate command_id returns duplicate:true and does not re-execute', async () => {
  const engine = new RoverEngine({ roverId: 'TEST-ROVER-01' });

  const commandId = 'test-idemp-001';
  const command: RoverCommand = {
    command_id: commandId,
    rover_id: 'TEST-ROVER-01',
    command_type: 'START_SCAN',
    payload: { zone_id: 'DEMO-ZONE-01' },
    issued_at: new Date().toISOString(),
  };

  // 1. First execution
  const ack1 = await engine.executeCommand(command);
  assert.strictEqual(ack1.command_id, commandId);
  assert.strictEqual(ack1.status, 'COMPLETED');
  assert.strictEqual(ack1.duplicate, false);
  const batteryAfterFirst = engine.getBatteryPct();

  // 2. Second execution with identical command_id
  const ack2 = await engine.executeCommand(command);
  assert.strictEqual(ack2.command_id, commandId);
  assert.strictEqual(ack2.duplicate, true);
  assert.ok(ack2.message.includes('already processed'), 'Should inform caller that command was already processed');

  // Verify that battery did not drain a second time (proves second scan was not run)
  assert.strictEqual(engine.getBatteryPct(), batteryAfterFirst);
});

test('Command Processor - handles STOP and STATUS commands correctly', async () => {
  const engine = new RoverEngine();

  // STATUS
  const statusAck = await engine.executeCommand({
    command_id: 'status-cmd-01',
    rover_id: engine.getRoverId(),
    command_type: 'STATUS',
    payload: {},
    issued_at: new Date().toISOString(),
  });
  assert.strictEqual(statusAck.status, 'COMPLETED');
  assert.strictEqual(statusAck.result.rover_id, engine.getRoverId());

  // STOP
  const stopAck = await engine.executeCommand({
    command_id: 'stop-cmd-01',
    rover_id: engine.getRoverId(),
    command_type: 'STOP',
    payload: { reason: 'Test safety pause' },
    issued_at: new Date().toISOString(),
  });
  assert.strictEqual(stopAck.status, 'COMPLETED');
  assert.strictEqual(engine.getState(), 'STOPPED');
});

test('Physical Safety Boundaries - rejects irrigation exceeding MAX_IRRIGATION_DURATION_SEC', async () => {
  const engine = new RoverEngine();

  // Attempt 300 seconds irrigation (max limit is 180s)
  const unsafeIrrigateCmd: RoverCommand = {
    command_id: 'unsafe-irrigate-01',
    rover_id: engine.getRoverId(),
    command_type: 'IRRIGATE',
    payload: { zone_id: 'DEMO-ZONE-02', duration_seconds: 300 },
    issued_at: new Date().toISOString(),
  };

  const ack = await engine.executeCommand(unsafeIrrigateCmd);
  assert.strictEqual(ack.status, 'REJECTED');
  assert.strictEqual(ack.duplicate, false);
  assert.ok(ack.message.includes('Safety'), 'Message should indicate safety violation');
});

test('Physical Safety Boundaries - halts operations when battery is below critical threshold', async () => {
  // Rover with critically low battery (8%, threshold is 10%)
  const lowBatteryEngine = new RoverEngine({ initialBattery: 8.0 });

  const scanCmd: RoverCommand = {
    command_id: 'low-batt-scan-01',
    rover_id: lowBatteryEngine.getRoverId(),
    command_type: 'START_SCAN',
    payload: { zone_id: 'DEMO-ZONE-01' },
    issued_at: new Date().toISOString(),
  };

  const ack = await lowBatteryEngine.executeCommand(scanCmd);
  assert.strictEqual(ack.status, 'REJECTED');
  assert.strictEqual(ack.error, 'LOW_BATTERY_ABORT');
});
