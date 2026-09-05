/**
 * PRAHAR Automated Test Suite — Phase 3: Offline Synchronization & Ingestion
 * Validates 5-state sync machine, idempotency, retry handling, conflict resolution, and safety gates.
 */

import { test, describe, before, after } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import { SyncEngine } from '../services/rover-simulator/src/sync-engine.js';
import { RoverEngine } from '../services/rover-simulator/src/engine.js';
import { PersistentAlertStore } from '../services/rover-simulator/src/persistent-alert-store.js';
import { DecisionEngine } from '../services/rover-simulator/src/decision-engine.js';
import { ClosedLoopCoordinator } from '../services/rover-simulator/src/closed-loop.js';
import { SyncBatchRequest, RoverScanPayload, validateSyncRecord } from '@prahar/shared';

describe('Phase 3: Offline Synchronization Engine (5 States, Idempotency & Conflict)', () => {
  const testStorageDir = path.resolve(process.cwd(), '.test_prahar_data_sync');
  let syncEngine: SyncEngine;

  before(() => {
    syncEngine = new SyncEngine({
      storageDir: testStorageDir,
      maxRetries: 3,
      baseBackoffMs: 50,
    });
    syncEngine.clear();
  });

  after(() => {
    syncEngine.clear();
    try {
      if (fs.existsSync(testStorageDir)) {
        fs.rmSync(testStorageDir, { recursive: true, force: true });
      }
    } catch {
      // Ignore
    }
  });

  test('Validates sync record before queueing', () => {
    const invalid = validateSyncRecord({ event_id: 'e1' });
    assert.strictEqual(invalid.valid, false);
    assert.strictEqual(invalid.errors.length > 0, true);

    const valid = validateSyncRecord({
      event_id: 'e1',
      idempotency_key: 'idemp-01',
      rover_id: 'ROVER-DEMO-01',
      entity_type: 'SCAN_PAYLOAD',
      payload: { test: true },
    });
    assert.strictEqual(valid.valid, true);
  });

  test('Enqueues records in PENDING state and tracks queue breakdown', () => {
    const record = syncEngine.enqueue({
      event_id: 'evt-01',
      idempotency_key: 'idemp-01',
      rover_id: 'ROVER-DEMO-01',
      entity_type: 'SCAN_PAYLOAD',
      action: 'INSERT',
      payload: { zone_id: 'ZONE-A1', moisture: 18.0 },
      client_timestamp: new Date().toISOString(),
    });

    assert.strictEqual(record.status, 'PENDING');
    assert.strictEqual(record.retry_count, 0);

    const status = syncEngine.getStatus();
    assert.strictEqual(status.pending_count, 1);
    assert.strictEqual(status.total_buffered, 1);
  });

  test('Processes batch idempotently and prevents duplicate processing', () => {
    const batch: SyncBatchRequest = {
      client_id: 'ROVER-CLIENT-01',
      records: [
        {
          event_id: 'evt-batch-1',
          idempotency_key: 'idemp-batch-unique-1',
          rover_id: 'ROVER-DEMO-01',
          entity_type: 'TELEMETRY',
          action: 'INSERT',
          payload: { id: 'telemetry-01', battery: 95.0 },
          status: 'PENDING',
          retry_count: 0,
          max_retries: 3,
          buffered_at: new Date().toISOString(),
          client_timestamp: new Date().toISOString(),
        },
      ],
    };

    // First ingestion
    const firstResult = syncEngine.processBatch(batch);
    assert.strictEqual(firstResult.success, true);
    assert.strictEqual(firstResult.synced_count, 1);
    assert.strictEqual(firstResult.duplicate_count, 0);
    assert.strictEqual(firstResult.results[0].is_duplicate, false);

    // Duplicate ingestion with same idempotency_key
    const secondResult = syncEngine.processBatch(batch);
    assert.strictEqual(secondResult.success, true);
    assert.strictEqual(secondResult.synced_count, 0);
    assert.strictEqual(secondResult.duplicate_count, 1);
    assert.strictEqual(secondResult.results[0].is_duplicate, true);
    assert.strictEqual(secondResult.results[0].status, 'SYNCED');
  });

  test('Conflict handling: LAST_WRITE_WINS detects newer server record and flags CONFLICT', () => {
    // 1. Ingest an initial record with newer timestamp
    const now = Date.now();
    const serverTime = new Date(now).toISOString();
    const olderClientTime = new Date(now - 10000).toISOString();

    syncEngine.processBatch({
      client_id: 'CLI-01',
      records: [
        {
          event_id: 'evt-entity-base',
          idempotency_key: 'idemp-entity-base',
          rover_id: 'ROVER-DEMO-01',
          entity_type: 'ALERT_ACK',
          action: 'INSERT',
          payload: { id: 'entity-conflict-target', state: 'SERVER_FRESH' },
          status: 'PENDING',
          retry_count: 0,
          max_retries: 3,
          buffered_at: serverTime,
          client_timestamp: serverTime,
        },
      ],
    });

    // 2. Client pushes an update with older client_timestamp -> Expect CONFLICT
    const conflictResult = syncEngine.processBatch({
      client_id: 'CLI-01',
      records: [
        {
          event_id: 'evt-entity-stale',
          idempotency_key: 'idemp-entity-stale-01',
          rover_id: 'ROVER-DEMO-01',
          entity_type: 'ALERT_ACK',
          action: 'UPDATE',
          payload: { id: 'entity-conflict-target', state: 'STALE_CLIENT_STATE' },
          status: 'PENDING',
          retry_count: 0,
          max_retries: 3,
          buffered_at: olderClientTime,
          client_timestamp: olderClientTime,
        },
      ],
      strategy: 'LAST_WRITE_WINS',
    });

    assert.strictEqual(conflictResult.conflict_count, 1);
    assert.strictEqual(conflictResult.results[0].status, 'CONFLICT');
    assert.strictEqual(conflictResult.results[0].conflict_resolved, true);
  });

  test('Retry handling: transitions to FAILED when max_retries exceeded, and allows manual retry', async () => {
    syncEngine.clear();

    syncEngine.enqueue({
      event_id: 'evt-retry-fail',
      idempotency_key: 'idemp-fail-01',
      rover_id: 'ROVER-DEMO-01',
      entity_type: 'COMMAND_ACK',
      action: 'INSERT',
      payload: { command_id: 'cmd-test-fail' },
      client_timestamp: new Date().toISOString(),
    });

    // Simulate 3 network push failures (maxRetries = 3)
    const failingPusher = async () => {
      throw new Error('Simulated network timeout');
    };

    await syncEngine.flushQueue(failingPusher); // Retry 1
    await syncEngine.flushQueue(failingPusher); // Retry 2
    await syncEngine.flushQueue(failingPusher); // Retry 3 -> FAILED

    const failedEvents = syncEngine.getFailedEvents();
    assert.strictEqual(failedEvents.length, 1);
    assert.strictEqual(failedEvents[0].status, 'FAILED');
    assert.strictEqual(failedEvents[0].retry_count, 3);
    assert.strictEqual(failedEvents[0].last_error?.includes('network timeout'), true);

    // Manual retry resets to PENDING
    const retriedCount = syncEngine.retryFailed();
    assert.strictEqual(retriedCount, 1);
    assert.strictEqual(syncEngine.getStatus().pending_count, 1);
    assert.strictEqual(syncEngine.getStatus().failed_count, 0);
  });

  test('Offline Mode & Reconnection: Buffers while offline, flushes cleanly when reconnected', async () => {
    syncEngine.clear();

    // 1. Go offline
    syncEngine.setOnline(false);
    assert.strictEqual(syncEngine.getOnline(), false);

    // Queue 2 events
    syncEngine.enqueue({
      event_id: 'evt-off-1',
      idempotency_key: 'idemp-off-1',
      rover_id: 'ROVER-DEMO-01',
      entity_type: 'TELEMETRY',
      action: 'INSERT',
      payload: { battery: 94.0 },
      client_timestamp: new Date().toISOString(),
    });
    syncEngine.enqueue({
      event_id: 'evt-off-2',
      idempotency_key: 'idemp-off-2',
      rover_id: 'ROVER-DEMO-01',
      entity_type: 'TELEMETRY',
      action: 'INSERT',
      payload: { battery: 93.5 },
      client_timestamp: new Date().toISOString(),
    });

    assert.strictEqual(syncEngine.getStatus().pending_count, 2);

    // Flush while offline should do nothing
    const offlineFlush = await syncEngine.flushQueue();
    assert.strictEqual(offlineFlush.flushed, 0);
    assert.strictEqual(syncEngine.getStatus().pending_count, 2);

    // 2. Reconnect
    syncEngine.setOnline(true);
    assert.strictEqual(syncEngine.getOnline(), true);

    // Flush upon reconnect -> All flushed and synced
    const onlineFlush = await syncEngine.flushQueue();
    assert.strictEqual(onlineFlush.synced, 2);
    assert.strictEqual(syncEngine.getStatus().pending_count, 0);
  });
});

describe('Phase 3: Decision Engine Safety & Ingestion Boundary Regression', () => {
  const testStorageDir = path.resolve(process.cwd(), '.test_prahar_data_safety');
  let alertStore: PersistentAlertStore;
  let decisionEngine: DecisionEngine;
  let engine: RoverEngine;
  let closedLoop: ClosedLoopCoordinator;

  before(() => {
    alertStore = new PersistentAlertStore({ storageDir: testStorageDir });
    alertStore.clear();
    decisionEngine = new DecisionEngine(alertStore);
    engine = new RoverEngine({ roverId: 'ROVER-SAFE-01', initialBattery: 95.0 });
    closedLoop = new ClosedLoopCoordinator(engine, decisionEngine, alertStore);
  });

  after(() => {
    alertStore.clear();
    try {
      if (fs.existsSync(testStorageDir)) {
        fs.rmSync(testStorageDir, { recursive: true, force: true });
      }
    } catch {
      // Ignore
    }
  });

  test('Decision Engine + Persistent Alert Store enforces Heat Stress & Low Moisture Rule', async () => {
    const scan: RoverScanPayload = {
      scan_id: 'scan-p3-01',
      rover_id: 'ROVER-SAFE-01',
      zone_id: 'DEMO-ZONE-02',
      gps: { lat: 26.8467, lng: 80.9462 },
      battery_pct: 95.0,
      timestamp: new Date().toISOString(),
      sensor_readings: [
        { type: 'moisture', value: 16.5, unit: '%' },
        { type: 'temperature', value: 34.5, unit: 'C' },
        { type: 'humidity', value: 50.0, unit: '%' },
        { type: 'ph', value: 6.8, unit: 'pH' },
      ],
      detections: [
        {
          detection_id: 'det-01',
          hazard_type: 'WATER_STRESS',
          hazard_name: 'Severe Water Deficit',
          confidence: 0.92,
          severity_hint: 'HIGH',
        },
      ],
    };

    const ingested = await closedLoop.ingestScan(scan);
    assert.strictEqual(ingested.decision.overall_severity, 'HIGH');
    assert.strictEqual(ingested.decision.action_recommendation?.action_type, 'RECOMMEND_IRRIGATION');
    assert.strictEqual(ingested.decision.action_recommendation?.requires_approval, true);

    // Verify alert was persisted in PersistentAlertStore
    const alerts = await alertStore.getAlerts({ zone_id: 'DEMO-ZONE-02' });
    assert.strictEqual(alerts.length >= 1, true);
    assert.strictEqual(alerts[0].type, 'WATER_STRESS');
    assert.strictEqual(alerts[0].message_hi?.includes('गंभीर जल तनाव'), true);
  });

  test('Safety Gate: Irrigation requires approved_by and rejects autonomous execution', async () => {
    // Attempt approval without approved_by -> Must throw
    assert.throws(
      () => {
        closedLoop.approveIntervention({
          zone_id: 'DEMO-ZONE-02',
          approved_by: '', // Blank approval
        });
      },
      /Safety Gate Violation: Explicit approved_by attribution is required/
    );

    // Valid approval
    const intervention = closedLoop.approveIntervention({
      zone_id: 'DEMO-ZONE-02',
      approved_by: 'dr_sharma_kvk_expert',
      duration_seconds: 30,
      volume_liters: 7.5,
    });

    assert.strictEqual(intervention.status, 'APPROVED');
    assert.strictEqual(intervention.approved_by, 'dr_sharma_kvk_expert');

    // Execution
    const ack = await closedLoop.executeApprovedIntervention(intervention.action_id);
    assert.strictEqual(ack.status, 'COMPLETED');
    assert.strictEqual(ack.duplicate, false);

    // Verification
    const verification = await closedLoop.verifyIntervention(intervention.action_id);
    assert.strictEqual(verification.resolved, true);
    assert.strictEqual(verification.post_moisture > verification.pre_moisture, true);

    // Verify verification is persisted
    const storedVerifs = await alertStore.getVerifications?.('DEMO-ZONE-02');
    assert.strictEqual(storedVerifs && storedVerifs.length >= 1, true);
  });
});
