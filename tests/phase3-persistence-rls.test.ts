/**
 * PRAHAR Automated Test Suite — Phase 3: Production Data Layer & RLS Policies
 * Validates Supabase schema definitions, RLS access control rules, and persistent stores.
 */

import { test, describe, before, after } from 'node:test';
import assert from 'node:assert';
import fs from 'node:fs';
import path from 'node:path';
import { PersistentAlertStore } from '../services/rover-simulator/src/persistent-alert-store.js';
import { Alert, ExpertAuditRecord, RemediationVerification } from '@prahar/shared';

describe('Phase 3: Supabase Schema & RLS Policy Integrity', () => {
  const migrationPath = path.resolve(process.cwd(), 'supabase/migrations/20260905000001_phase3_production_data_and_rls.sql');

  test('Migration file exists and contains all required Phase 3 tables', () => {
    assert.strictEqual(fs.existsSync(migrationPath), true, 'Phase 3 migration file must exist');
    const sql = fs.readFileSync(migrationPath, 'utf-8');

    // Required tables
    const requiredTables = [
      'public.profiles',
      'public.remediation_actions',
      'public.remediation_verifications',
      'public.expert_audit_records',
    ];

    for (const table of requiredTables) {
      assert.strictEqual(sql.includes(`CREATE TABLE IF NOT EXISTS ${table}`), true, `Must define table ${table}`);
    }

    // Required columns
    assert.strictEqual(sql.includes('message_hi'), true, 'Alerts must have message_hi');
    assert.strictEqual(sql.includes('recommended_action_hi'), true, 'Alerts must have recommended_action_hi');
    assert.strictEqual(sql.includes('deduplication_key'), true, 'Alerts must have deduplication_key');
    assert.strictEqual(sql.includes('idempotency_key'), true, 'Sync events must have idempotency_key');
    assert.strictEqual(sql.includes('retry_count'), true, 'Sync events must have retry_count');
  });

  test('RLS is enabled on all core domain tables', () => {
    const sql = fs.readFileSync(migrationPath, 'utf-8');
    const expectedRlsTables = [
      'public.profiles',
      'public.farmers',
      'public.farms',
      'public.zones',
      'public.sensor_readings',
      'public.detections',
      'public.alerts',
      'public.rover_commands',
      'public.rover_telemetry',
      'public.remediation_actions',
      'public.remediation_verifications',
      'public.expert_audit_records',
      'public.offline_sync_events',
    ];

    for (const table of expectedRlsTables) {
      const stmt = `ALTER TABLE ${table} ENABLE ROW LEVEL SECURITY;`;
      assert.strictEqual(sql.includes(stmt), true, `RLS must be enabled on ${table}`);
    }
  });

  test('RLS Policies enforce strict Farmer ownership boundaries and Expert access', () => {
    const sql = fs.readFileSync(migrationPath, 'utf-8');

    // Helper functions
    assert.strictEqual(sql.includes('CREATE OR REPLACE FUNCTION public.get_user_role()'), true);
    assert.strictEqual(sql.includes('CREATE OR REPLACE FUNCTION public.get_user_farmer_id()'), true);

    // Farmer ownership checks
    assert.strictEqual(sql.includes('farmer_id = public.get_user_farmer_id()'), true);
    assert.strictEqual(sql.includes("public.get_user_role() IN ('EXPERT', 'ADMIN')"), true);

    // Audit trail immutability
    assert.strictEqual(sql.includes('CREATE POLICY "Audit records insert policy"'), true);
    assert.strictEqual(sql.includes('CREATE POLICY "Audit records select policy"'), true);
  });
});

describe('Phase 3: Persistent Alert Store & Audit Records', () => {
  const testStorageDir = path.resolve(process.cwd(), '.test_prahar_data_rls');
  let store: PersistentAlertStore;

  before(() => {
    store = new PersistentAlertStore({ storageDir: testStorageDir });
    store.clear();
  });

  after(() => {
    store.clear();
    try {
      if (fs.existsSync(testStorageDir)) {
        fs.rmSync(testStorageDir, { recursive: true, force: true });
      }
    } catch {
      // Ignore
    }
  });

  test('Saves and retrieves alerts with bilingual text and deduplication key', () => {
    const testAlert: Alert = {
      alert_id: 'alt-p3-01',
      zone_id: 'ZONE-A1',
      type: 'WATER_STRESS',
      severity: 'HIGH',
      message: 'High Water Stress detected in ZONE-A1.',
      message_hi: 'ZONE-A1 में गंभीर जल तनाव पाया गया।',
      recommended_action: 'Micro-irrigation recommended.',
      recommended_action_hi: 'सूक्ष्म-सिंचाई की सिफारिश।',
      status: 'NEW',
      timestamp: new Date().toISOString(),
      deduplication_key: 'ZONE-A1:WATER_STRESS',
      occurrence_count: 1,
    };

    store.saveAlert(testAlert);

    const retrieved = store.getAlertById('alt-p3-01');
    assert.notStrictEqual(retrieved, null);
    assert.strictEqual(retrieved?.message_hi, 'ZONE-A1 में गंभीर जल तनाव पाया गया।');
    assert.strictEqual(retrieved?.deduplication_key, 'ZONE-A1:WATER_STRESS');

    // Deduplication key lookup
    const deduplicated = store.findActiveAlertByDeduplicationKey('ZONE-A1:WATER_STRESS');
    assert.strictEqual(deduplicated?.alert_id, 'alt-p3-01');
  });

  test('Persists expert audit records with timestamp and actor attribution', () => {
    const auditRecord: ExpertAuditRecord = {
      audit_id: 'adt-01',
      actor: 'dr_sharma_kvk_expert',
      timestamp: new Date().toISOString(),
      zone_id: 'ZONE-A1',
      alert_id: 'alt-p3-01',
      action: 'APPROVE_INTERVENTION',
      previous_state: 'PENDING_APPROVAL',
      new_state: 'APPROVED_FOR_EXECUTION',
      expert_note: 'Approved 30s irrigation after soil sensor inspection.',
    };

    store.recordAudit(auditRecord);

    const history = store.getAuditHistory({ zone_id: 'ZONE-A1' });
    assert.strictEqual(history.length, 1);
    assert.strictEqual(history[0].actor, 'dr_sharma_kvk_expert');
    assert.strictEqual(history[0].action, 'APPROVE_INTERVENTION');
  });

  test('Persists and retrieves closed-loop remediation verifications', () => {
    const verification: RemediationVerification = {
      verification_id: 'verif-test-01',
      zone_id: 'ZONE-A1',
      action_id: 'act-01',
      pre_moisture: 16.5,
      post_moisture: 29.0,
      moisture_delta: 12.5,
      resolved: true,
      verification_timestamp: new Date().toISOString(),
      summary_en: 'Moisture improved from 16.5% to 29.0%.',
      summary_hi: 'नमी 16.5% से बढ़कर 29.0% हो गई।',
    };

    store.saveVerification(verification);

    const records = store.getVerifications('ZONE-A1');
    assert.strictEqual(records.length, 1);
    assert.strictEqual(records[0].resolved, true);
    assert.strictEqual(records[0].moisture_delta, 12.5);
  });

  test('Data persists across store reinstantiations (file backup simulation)', () => {
    // Instantiate a new store pointing to the exact same directory
    const secondStore = new PersistentAlertStore({ storageDir: testStorageDir });
    const alert = secondStore.getAlertById('alt-p3-01');
    assert.notStrictEqual(alert, null);
    assert.strictEqual(alert?.alert_id, 'alt-p3-01');

    const history = secondStore.getAuditHistory({ zone_id: 'ZONE-A1' });
    assert.strictEqual(history.length, 1);

    const verifications = secondStore.getVerifications('ZONE-A1');
    assert.strictEqual(verifications.length, 1);
  });
});
