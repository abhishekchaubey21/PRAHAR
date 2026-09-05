import test from 'node:test';
import assert from 'node:assert';
import { RoverEngine } from '../services/rover-simulator/src/engine.js';
import { RoverCommand } from '../packages/shared/src/commands.js';

test('Offline Queue - buffers events when offline and flushes upon reconnection', async () => {
  const engine = new RoverEngine({ roverId: 'TEST-ROVER-OFFLINE', offlineMode: false });

  // Initially online: no offline buffer accumulation
  engine.simulateScanCycle('DEMO-ZONE-01');
  assert.strictEqual(engine.offlineStore.getCount(), 0);

  // Toggle offline mode
  engine.setOfflineMode(true);
  assert.strictEqual(engine.isOfflineMode(), true);

  // 1. Trigger scan cycle while offline
  engine.simulateScanCycle('DEMO-ZONE-02');
  assert.strictEqual(engine.offlineStore.getCount(), 1);

  // 2. Query telemetry while offline
  engine.getTelemetry();
  assert.strictEqual(engine.offlineStore.getCount(), 2);

  // 3. Execute command while offline
  const cmd: RoverCommand = {
    command_id: 'cmd-offline-01',
    rover_id: engine.getRoverId(),
    command_type: 'IRRIGATE',
    payload: { zone_id: 'DEMO-ZONE-02', duration_seconds: 20 },
    issued_at: new Date().toISOString(),
  };
  await engine.executeCommand(cmd);
  // Both command ACK and internal irrigation simulation event are buffered
  assert.ok(engine.offlineStore.getCount() >= 3);

  // Peek buffered events
  const peeked = engine.offlineStore.peekAll();
  assert.strictEqual(peeked[0].event_type, 'SCAN_PAYLOAD');
  assert.strictEqual(peeked[0].synced, false);

  // 4. Reconnect & Flush Queue
  engine.setOfflineMode(false);
  const flushed = engine.flushOfflineQueue();

  assert.ok(flushed.length >= 3);
  assert.strictEqual(flushed[0].synced, true);
  assert.strictEqual(engine.offlineStore.getCount(), 0, 'Offline store must be empty after flush');
});
