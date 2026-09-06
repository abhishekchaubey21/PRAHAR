/**
 * PRAHAR Phase 6B-1: Persistent In-App Notification System Test Suite
 * Validates the complete software-owned core for Notifications:
 * Flutter / API client -> HTTP -> JWT -> PRAHAR Gateway -> RBAC + Deduplication -> Supabase / PostgreSQL / RLS -> Real Persistence.
 *
 * Scenarios Tested:
 * A: Own notifications readable
 * B: Cross-farmer notifications blocked
 * C: Unauthenticated access blocked (401)
 * D: RBAC enforced
 * E: Notification persists in real Supabase
 * F: Mark-read persists
 * G: Mark-all-read persists
 * H: Unread count correct
 * I: Duplicate event deduplication
 * J: Correct alert/zone/action linkage
 * K: API error handling
 * L: Real RLS integration
 */

import { test, describe, before, after } from 'node:test';
import assert from 'node:assert';
import crypto from 'node:crypto';
import { server, notificationService } from '../services/rover-simulator/src/server.js';
import { AuthService } from '../services/rover-simulator/src/auth-service.js';
import {
  isSupabaseConfigured,
  getServiceRoleClient,
  getAnonClient,
  createUserScopedClient,
} from '../services/rover-simulator/src/supabase-client.js';

// Load .env if present
if (typeof process.loadEnvFile === 'function') {
  try {
    process.loadEnvFile();
  } catch {}
}

describe('Phase 6B-1: Persistent In-App Notification System Suite', () => {
  let baseUrl: string = 'http://127.0.0.1:3001';
  const isLiveSupabase = isSupabaseConfigured() && Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY);

  let adminClient: any;
  const authService = new AuthService();

  let farmerAUser: any;
  let farmerBUser: any;
  let expertUser: any;

  let farmerAToken: string = '';
  let farmerBToken: string = '';
  let expertToken: string = '';

  let farmerAFarmerId: string = '';
  let farmerBFarmerId: string = '';
  let farmAId: string = '';
  let farmBId: string = '';
  let zoneAId: string = '';
  let zoneBId: string = '';
  let alertAId: string = '';
  let actionAId: string = '';

  let notifA1Id: string = '';
  let notifA2Id: string = '';
  let notifB1Id: string = '';

  const testRunId = Date.now().toString(36);
  const farmerAEmail = `phase6b1.farmer.a.${testRunId}@prahar.internal`;
  const farmerBEmail = `phase6b1.farmer.b.${testRunId}@prahar.internal`;
  const expertEmail = `phase6b1.expert.${testRunId}@prahar.internal`;
  const testPassword = `Prahar6B1!Test@${testRunId}`;

  async function apiRequest(
    path: string,
    options: { method?: string; token?: string; body?: any } = {}
  ): Promise<{ status: number; body: any }> {
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (options.token) {
      headers['Authorization'] = `Bearer ${options.token}`;
    }

    const res = await fetch(`${baseUrl}${path}`, {
      method: options.method || 'GET',
      headers,
      body: options.body ? JSON.stringify(options.body) : undefined,
    });

    const body = await res.json().catch(() => ({}));
    return { status: res.status, body };
  }

  before(async () => {
    // 1. Ensure Gateway server is listening
    if (!server.listening) {
      await new Promise<void>((resolve) => server.listen(0, resolve));
    }
    const addr = server.address();
    if (typeof addr === 'object' && addr !== null) {
      baseUrl = `http://127.0.0.1:${addr.port}`;
    }

    if (!isLiveSupabase) {
      console.warn('[Notice] Live Supabase not available, running with in-memory persistence.');
      return;
    }

    adminClient = getServiceRoleClient();

    // 2. Create Farmer A in Supabase Auth
    const { data: userAData, error: errA } = await adminClient.auth.admin.createUser({
      email: farmerAEmail,
      password: testPassword,
      email_confirm: true,
      user_metadata: { full_name: 'Phase 6B-1 Farmer Alpha' },
    });
    if (errA) throw new Error(`Failed to create Farmer A: ${errA.message}`);
    farmerAUser = userAData.user;

    const { data: signA, error: signErrA } = await getAnonClient().auth.signInWithPassword({
      email: farmerAEmail,
      password: testPassword,
    });
    if (signErrA) throw new Error(`Failed to sign in Farmer A: ${signErrA.message}`);
    farmerAToken = signA.session.access_token;

    // 3. Create Farmer B in Supabase Auth
    const { data: userBData, error: errB } = await adminClient.auth.admin.createUser({
      email: farmerBEmail,
      password: testPassword,
      email_confirm: true,
      user_metadata: { full_name: 'Phase 6B-1 Farmer Beta' },
    });
    if (errB) throw new Error(`Failed to create Farmer B: ${errB.message}`);
    farmerBUser = userBData.user;

    const { data: signB, error: signErrB } = await getAnonClient().auth.signInWithPassword({
      email: farmerBEmail,
      password: testPassword,
    });
    if (signErrB) throw new Error(`Failed to sign in Farmer B: ${signErrB.message}`);
    farmerBToken = signB.session.access_token;

    // 4. Create Expert in Supabase Auth
    const { data: expData, error: errExp } = await adminClient.auth.admin.createUser({
      email: expertEmail,
      password: testPassword,
      email_confirm: true,
      user_metadata: { full_name: 'Phase 6B-1 Agronomist Expert' },
    });
    if (errExp) throw new Error(`Failed to create Expert: ${errExp.message}`);
    expertUser = expData.user;

    try {
      await authService.promoteUserRole(
        { user_id: 'usr-admin-system', email: 'admin@prahar.gov.in', role: 'ADMIN' },
        expertUser.id,
        'EXPERT'
      );
    } catch (_) {}

    const { data: signExp, error: signErrExp } = await getAnonClient().auth.signInWithPassword({
      email: expertEmail,
      password: testPassword,
    });
    if (signErrExp) throw new Error(`Failed to sign in Expert: ${signErrExp.message}`);
    expertToken = signExp.session.access_token;

    // 5. Seed isolated tenant fixtures
    farmerAFarmerId = crypto.randomUUID();
    farmerBFarmerId = crypto.randomUUID();
    farmAId = crypto.randomUUID();
    farmBId = crypto.randomUUID();
    zoneAId = `ZONE-6B1-A-${testRunId}`;
    zoneBId = `ZONE-6B1-B-${testRunId}`;
    alertAId = crypto.randomUUID();
    actionAId = `act-6b1-a-${testRunId}`;

    await adminClient.from('farmers').insert([
      { id: farmerAFarmerId, name: 'Farmer Alpha 6B1', phone: `+91-91${Math.floor(10000000 + Math.random() * 90000000)}`, language: 'en' },
      { id: farmerBFarmerId, name: 'Farmer Beta 6B1', phone: `+91-92${Math.floor(10000000 + Math.random() * 90000000)}`, language: 'hi' },
    ]);

    await adminClient.from('profiles').update({ farmer_id: farmerAFarmerId }).eq('id', farmerAUser.id);
    await adminClient.from('profiles').update({ farmer_id: farmerBFarmerId }).eq('id', farmerBUser.id);

    await adminClient.from('farms').insert([
      { id: farmAId, farmer_id: farmerAFarmerId, name: `Farm Alpha 6B1`, crop_type: 'Wheat', area_acres: 4.0 },
      { id: farmBId, farmer_id: farmerBFarmerId, name: `Farm Beta 6B1`, crop_type: 'Soybean', area_acres: 6.0 },
    ]);

    await adminClient.from('zones').insert([
      { id: zoneAId, farm_id: farmAId, zone_name: `Zone Alpha 6B1` },
      { id: zoneBId, farm_id: farmBId, zone_name: `Zone Beta 6B1` },
    ]);

    await adminClient.from('alerts').insert([
      { id: alertAId, zone_id: zoneAId, type: 'WATER_STRESS', severity: 'HIGH', message: 'Low moisture in Zone A', recommended_action: 'Irrigate 30s' },
    ]);

    await adminClient.from('remediation_actions').insert([
      {
        action_id: actionAId,
        zone_id: zoneAId,
        action_type: 'IRRIGATE',
        duration_seconds: 30,
        volume_liters: 7.5,
        approved_by: expertUser.id,
        status: 'APPROVED',
      },
    ]);

    // 6. Seed Expert Farm Assignment (Authorizing Expert to Farm A ONLY)
    await adminClient.from('expert_farm_assignments').insert([
      { expert_id: expertUser.id, farm_id: farmAId },
    ]);

    // 7. Seed Notifications via NotificationService
    const notifA1 = await notificationService.createNotification({
      user_id: farmerAUser.id,
      farm_id: farmAId,
      zone_id: zoneAId,
      alert_id: alertAId,
      type: 'ALERT_CREATED',
      severity: 'HIGH',
      title: 'Water Stress Detected in Zone Alpha',
      title_hi: 'ज़ोन अल्फा में जल तनाव का पता चला',
      message: 'Moisture level dropped below 20%. Micro-irrigation recommended.',
      message_hi: 'नमी का स्तर 20% से नीचे चला गया। सूक्ष्म सिंचाई की सिफारिश की गई।',
      deduplication_key: `dedup:alert:${alertAId}`,
    });
    notifA1Id = notifA1.id;

    const notifA2 = await notificationService.createNotification({
      user_id: farmerAUser.id,
      farm_id: farmAId,
      zone_id: zoneAId,
      action_id: actionAId,
      type: 'ACTION_APPROVED',
      severity: 'MEDIUM',
      title: 'Irrigation Action Approved',
      title_hi: 'सिंचाई कार्रवाई स्वीकृत',
      message: 'KVK Expert approved 30s micro-irrigation for Zone Alpha.',
      message_hi: 'केवीके विशेषज्ञ ने ज़ोन अल्फा के लिए 30 सेकंड की सूक्ष्म सिंचाई को मंजूरी दी।',
      deduplication_key: `dedup:action:${actionAId}`,
    });
    notifA2Id = notifA2.id;

    const notifB1 = await notificationService.createNotification({
      user_id: farmerBUser.id,
      farm_id: farmBId,
      zone_id: zoneBId,
      type: 'RISK_DETECTED',
      severity: 'HIGH',
      title: 'High Heat Risk in Farm Beta',
      title_hi: 'फार्म बीटा में उच्च ताप जोखिम',
      message: 'Ambient temp exceeded 38C.',
      message_hi: 'परिवेश का तापमान 38 डिग्री सेल्सियस से अधिक हो गया।',
      deduplication_key: `dedup:risk:heat:${farmBId}`,
    });
    notifB1Id = notifB1.id;
  });

  after(async () => {
    if (isLiveSupabase && adminClient) {
      try {
        await adminClient.from('expert_farm_assignments').delete().in('expert_id', [expertUser?.id]);
        await adminClient.from('notifications').delete().in('farm_id', [farmAId, farmBId]);
        await adminClient.from('remediation_actions').delete().in('zone_id', [zoneAId, zoneBId]);
        await adminClient.from('alerts').delete().in('zone_id', [zoneAId, zoneBId]);
        await adminClient.from('zones').delete().in('id', [zoneAId, zoneBId]);
        await adminClient.from('farms').delete().in('id', [farmAId, farmBId]);
        await adminClient.from('profiles').delete().in('id', [farmerAUser?.id, farmerBUser?.id, expertUser?.id]);
        await adminClient.from('farmers').delete().in('id', [farmerAFarmerId, farmerBFarmerId]);
        await adminClient.auth.admin.deleteUser(farmerAUser.id);
        await adminClient.auth.admin.deleteUser(farmerBUser.id);
        await adminClient.auth.admin.deleteUser(expertUser.id);
      } catch (err: any) {
        console.warn('[Cleanup Warning]:', err.message);
      }
    }
  });

  // ==========================================================================
  // SCENARIOS A through L
  // ==========================================================================

  test('Scenario A: Own notifications readable via GET /api/notifications', async () => {
    const res = await apiRequest('/api/notifications', { token: farmerAToken });
    assert.strictEqual(res.status, 200, 'Expected 200 OK for authenticated notifications query');
    assert.strictEqual(res.body.success, true);
    assert.ok(Array.isArray(res.body.data), 'Expected array of notifications');
    assert.strictEqual(res.body.data.length, 2, 'Farmer A should have exactly 2 notifications');

    const ids = res.body.data.map((n: any) => n.id);
    assert.ok(ids.includes(notifA1Id), 'Farmer A notifications should include notifA1');
    assert.ok(ids.includes(notifA2Id), 'Farmer A notifications should include notifA2');
  });

  test('Scenario B: Cross-farmer notifications blocked (Tenant Isolation)', async () => {
    const resA = await apiRequest('/api/notifications', { token: farmerAToken });
    const idsA = resA.body.data.map((n: any) => n.id);
    assert.strictEqual(idsA.includes(notifB1Id), false, 'Farmer A MUST NOT see Farmer B notification');

    const resB = await apiRequest('/api/notifications', { token: farmerBToken });
    assert.strictEqual(resB.status, 200);
    assert.strictEqual(resB.body.data.length, 1, 'Farmer B should have exactly 1 notification');
    assert.strictEqual(resB.body.data[0].id, notifB1Id);
    assert.strictEqual(resB.body.data.some((n: any) => n.id === notifA1Id || n.id === notifA2Id), false, 'Farmer B MUST NOT see Farmer A notifications');
  });

  test('Scenario C: Unauthenticated access blocked (401 Unauthorized)', async () => {
    const resList = await apiRequest('/api/notifications');
    assert.strictEqual(resList.status, 401, 'Unauthenticated list must return 401');

    const resCount = await apiRequest('/api/notifications/unread-count');
    assert.strictEqual(resCount.status, 401, 'Unauthenticated unread-count must return 401');

    const resPatch = await apiRequest(`/api/notifications/${notifA1Id}/read`, { method: 'PATCH' });
    assert.strictEqual(resPatch.status, 401, 'Unauthenticated patch must return 401');

    const resReadAll = await apiRequest('/api/notifications/read-all', { method: 'POST' });
    assert.strictEqual(resReadAll.status, 401, 'Unauthenticated read-all must return 401');
  });

  test('Scenario D: Expert/Admin notification RLS (Authorized Farm vs Unauthorized Cross-Tenant Denied)', async () => {
    // Expert is authorized for Farm A, but NOT Farm B
    const resExp = await apiRequest('/api/notifications', { token: expertToken });
    assert.strictEqual(resExp.status, 200, 'Expert should be able to query notifications');
    assert.strictEqual(resExp.body.success, true);
    assert.ok(resExp.body.data.length >= 2, 'Expert should see notifications for authorized Farm A');
    assert.strictEqual(
      resExp.body.data.every((n: any) => n.farm_id === farmAId),
      true,
      'Expert must ONLY see notifications for authorized Farm A'
    );
    assert.strictEqual(
      resExp.body.data.some((n: any) => n.farm_id === farmBId),
      false,
      'Unauthorized cross-tenant access to Farm B notifications MUST be denied'
    );

    // Direct RLS query with user-scoped client
    if (isLiveSupabase) {
      const expClient = createUserScopedClient(expertToken);
      const { data: expRows, error: expErr } = await expClient.from('notifications').select('*');
      assert.strictEqual(expErr, null);
      assert.ok(expRows && expRows.length >= 2);
      assert.strictEqual(expRows.every((n: any) => n.farm_id === farmAId), true);
      assert.strictEqual(expRows.some((n: any) => n.farm_id === farmBId), false);

      // Explicit cross-tenant query for Farm B notifications must yield zero rows
      const { data: bRows, error: bErr } = await expClient
        .from('notifications')
        .select('*')
        .eq('farm_id', farmBId);
      assert.strictEqual(bErr, null);
      assert.strictEqual(bRows?.length, 0, 'Expert must be blocked by RLS from accessing Farm B notifications');
    }
  });

  test('Scenario E: Notification persists in real Supabase', async () => {
    if (!isLiveSupabase) return;

    const { data, error } = await adminClient
      .from('notifications')
      .select('*')
      .eq('id', notifA1Id)
      .maybeSingle();

    assert.strictEqual(error, null, 'Expected no DB query error');
    assert.ok(data, 'Notification record must exist in public.notifications');
    assert.strictEqual(data.type, 'ALERT_CREATED');
    assert.strictEqual(data.farm_id, farmAId);
    assert.strictEqual(data.zone_id, zoneAId);
    assert.strictEqual(data.alert_id, alertAId);
    assert.strictEqual(data.is_read, false);
  });

  test('Scenario F: Mark-read persists via PATCH /api/notifications/:id/read', async () => {
    const res = await apiRequest(`/api/notifications/${notifA1Id}/read`, {
      method: 'PATCH',
      token: farmerAToken,
    });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.data.is_read, true);
    assert.ok(res.body.data.read_at, 'read_at must be populated');

    if (isLiveSupabase) {
      const { data } = await adminClient
        .from('notifications')
        .select('is_read, read_at')
        .eq('id', notifA1Id)
        .single();
      assert.strictEqual(data.is_read, true, 'is_read must persist to true in Supabase');
      assert.ok(data.read_at, 'read_at must persist in Supabase');
    }
  });

  test('Scenario G: Mark-all-read persists via POST /api/notifications/read-all', async () => {
    const res = await apiRequest('/api/notifications/read-all', {
      method: 'POST',
      token: farmerAToken,
    });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);

    // Verify all Farmer A notifications are now read
    const resList = await apiRequest('/api/notifications', { token: farmerAToken });
    for (const n of resList.body.data) {
      assert.strictEqual(n.is_read, true, 'All Farmer A notifications should be is_read=true');
    }

    // Verify Farmer B's notification was NOT affected
    const resB = await apiRequest('/api/notifications', { token: farmerBToken });
    assert.strictEqual(resB.body.data[0].is_read, false, 'Farmer B notification must remain unread');
  });

  test('Scenario H: Unread count returns accurate values', async () => {
    // Farmer A has 0 unread now
    const resCountA = await apiRequest('/api/notifications/unread-count', { token: farmerAToken });
    assert.strictEqual(resCountA.status, 200);
    assert.strictEqual(resCountA.body.count, 0, 'Farmer A unread count should be 0');

    // Farmer B has 1 unread
    const resCountB = await apiRequest('/api/notifications/unread-count', { token: farmerBToken });
    assert.strictEqual(resCountB.status, 200);
    assert.strictEqual(resCountB.body.count, 1, 'Farmer B unread count should be 1');
  });

  test('Scenario I: Duplicate event deduplication enforces idempotency', async () => {
    const dedupKey = `dedup:alert:${alertAId}`;

    // Attempt to create duplicate notification with the exact same user & deduplication_key
    const dupNotif = await notificationService.createNotification({
      user_id: farmerAUser.id,
      farm_id: farmAId,
      zone_id: zoneAId,
      alert_id: alertAId,
      type: 'ALERT_CREATED',
      severity: 'HIGH',
      title: 'Duplicate Water Stress Attempt',
      message: 'This should be deduplicated.',
      deduplication_key: dedupKey,
    });

    // Should return existing notification id, NOT create a second record
    assert.strictEqual(dupNotif.id, notifA1Id, 'Deduplication must return existing record');

    if (isLiveSupabase) {
      const { data } = await adminClient
        .from('notifications')
        .select('id')
        .eq('user_id', farmerAUser.id)
        .eq('deduplication_key', dedupKey);

      assert.strictEqual(data?.length, 1, 'Only one record must exist in DB for same user and dedup key');
    }
  });

  test('Scenario J: Correct alert/zone/action linkage in notification records', async () => {
    const res = await apiRequest('/api/notifications', { token: farmerAToken });
    const notifAlert = res.body.data.find((n: any) => n.type === 'ALERT_CREATED');
    const notifAction = res.body.data.find((n: any) => n.type === 'ACTION_APPROVED');

    assert.ok(notifAlert, 'ALERT_CREATED notification should exist');
    assert.strictEqual(notifAlert.zone_id, zoneAId);
    assert.strictEqual(notifAlert.alert_id, alertAId);
    assert.strictEqual(notifAlert.farm_id, farmAId);

    assert.ok(notifAction, 'ACTION_APPROVED notification should exist');
    assert.strictEqual(notifAction.zone_id, zoneAId);
    assert.strictEqual(notifAction.action_id, actionAId);
    assert.strictEqual(notifAction.farm_id, farmAId);
  });

  test('Scenario K: API error handling (400, 401, 404)', async () => {
    // 401 on invalid token
    const resBadToken = await apiRequest('/api/notifications', { token: 'invalid.jwt.token' });
    assert.ok(resBadToken.status === 401 || resBadToken.status === 403);

    // 404 on marking non-existent notification
    const resNotFound = await apiRequest('/api/notifications/00000000-0000-0000-0000-000000000000/read', {
      method: 'PATCH',
      token: farmerAToken,
    });
    assert.strictEqual(resNotFound.status, 404);
    assert.strictEqual(resNotFound.body.success, false);
  });

  test('Scenario L: Real PostgreSQL RLS integration via user-scoped client', async () => {
    if (!isLiveSupabase) return;

    // Direct user-scoped client for Farmer A
    const clientA = createUserScopedClient(farmerAToken);
    const { data: dataA, error: errA } = await clientA.from('notifications').select('*');
    assert.strictEqual(errA, null);
    assert.ok(dataA && dataA.length >= 2);
    assert.strictEqual(dataA.some((n: any) => n.user_id !== farmerAUser.id), false, 'RLS must not allow Farmer A to select foreign user notifications');

    // Direct user-scoped client for Farmer B
    const clientB = createUserScopedClient(farmerBToken);
    const { data: dataB, error: errB } = await clientB.from('notifications').select('*');
    assert.strictEqual(errB, null);
    assert.strictEqual(dataB?.length, 1);
    assert.strictEqual(dataB[0].user_id, farmerBUser.id);
  });

  test('Scenario M: Notification Write Security & Immutability (Client tampering blocked)', async () => {
    if (!isLiveSupabase) return;

    const clientA = createUserScopedClient(farmerAToken);

    // 1. Farmer client cannot INSERT notifications directly (service-role only)
    const { data: insertData, error: insertErr } = await clientA.from('notifications').insert([
      {
        notification_id: `tamper-insert-${Date.now()}`,
        user_id: farmerAUser.id,
        farm_id: farmAId,
        type: 'SYSTEM',
        severity: 'CRITICAL',
        title: 'Tampered notification attempt',
        message: 'Direct client insert should be blocked',
      },
    ]).select();

    const isInsertBlocked = insertErr !== null && (
      insertErr.code === '42501' ||
      insertErr.message?.includes('permission denied') ||
      insertErr.message?.includes('violates row-level security')
    );
    assert.ok(
      isInsertBlocked,
      `Client direct INSERT must be blocked with permission denied. Got error: ${insertErr?.message}, data: ${JSON.stringify(insertData)}`
    );

    // 2. Farmer client cannot UPDATE content/ownership (title, severity, user_id, farm_id)
    const { data: updateData, error: updateErr } = await clientA
      .from('notifications')
      .update({ title: 'Hacked Title', severity: 'LOW', user_id: farmerBUser.id })
      .eq('id', notifA1Id)
      .select();

    const isUpdateBlocked = updateErr !== null && (
      updateErr.code === '42501' ||
      updateErr.message?.includes('permission denied') ||
      updateErr.message?.includes('Access Denied: Notification content and ownership are immutable')
    );
    assert.ok(
      isUpdateBlocked,
      `Client tampering with notification content/ownership must be rejected. Got error: ${updateErr?.message}, data: ${JSON.stringify(updateData)}`
    );

    // 3. Farmer client CAN update read-state (is_read, read_at)
    const { data: readUpdateData, error: readUpdateErr } = await clientA
      .from('notifications')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('id', notifA1Id)
      .select();

    assert.strictEqual(readUpdateErr, null, 'Updating read-state must succeed');
    assert.ok(readUpdateData && readUpdateData.length > 0);
  });

  test('Scenario N: Backend Authoritative Source of Truth (No silent memory fallback)', async () => {
    if (!isLiveSupabase) return;

    // Attempting to create notification with invalid UUID foreign key must fail authoritatively at DB level
    await assert.rejects(
      async () => {
        await notificationService.createNotification({
          user_id: '00000000-0000-0000-0000-000000000000',
          farm_id: '00000000-0000-0000-0000-000000000000',
          type: 'SYSTEM',
          severity: 'INFO',
          title: 'Invalid Foreign Key Test',
          message: 'Must not silently fall back to local store',
        });
      },
      /Supabase insert failed/i,
      'Backend must throw on database failure rather than silently caching in memory'
    );
  });
});
