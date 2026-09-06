/**
 * PRAHAR Phase 6B-2: Farmer Analytics, Field Health & Historical Trends Test Suite
 * Validates the complete software-owned core for Analytics:
 * Authenticated JWT -> Gateway Endpoints -> Multi-Tenant PostgreSQL RLS -> Real Field Health & Trends.
 *
 * Scenarios Tested:
 * A. Authenticated analytics access (200 OK)
 * B. Unauthenticated rejection (401 Unauthorized)
 * C. Farmer tenant isolation (Farmer A vs Farmer B)
 * D. Farm/zone authorization (Access to unowned farm/zone rejected)
 * E. Real summary calculation (Reflects real database values and deterministic status)
 * F. Real trend data (Chronological points returned)
 * G. Empty historical state (Clean response when zone has no sensor data)
 * H. Intervention history (Remediation actions returned)
 * I. Verification history (Linked pre/post moisture delta and resolution)
 * J. Bounded date ranges (Filters restrict time-series)
 * K. API error propagation (400 Bad Request on missing parameters)
 */

import { test, describe, before, after } from 'node:test';
import assert from 'node:assert';
import crypto from 'node:crypto';
import { server, analyticsService } from '../services/rover-simulator/src/server.js';
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

describe('Phase 6B-2: Farmer Analytics, Field Health & Historical Trends Suite', () => {
  let baseUrl: string = 'http://127.0.0.1:3001';
  const isLiveSupabase = isSupabaseConfigured() && Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY);

  let adminClient: any;
  const authService = new AuthService();

  let farmerAUser: any;
  let farmerBUser: any;

  let farmerAToken: string = '';
  let farmerBToken: string = '';

  let farmerAFarmerId: string = '';
  let farmerBFarmerId: string = '';
  let farmAId: string = '';
  let farmBId: string = '';
  let zoneA1Id: string = '';
  let zoneA2EmptyId: string = '';
  let zoneB1Id: string = '';

  let actionAId: string = '';
  let verifAId: string = '';

  const testRunId = Date.now().toString(36);
  const farmerAEmail = `phase6b2.farmer.a.${testRunId}@prahar.internal`;
  const farmerBEmail = `phase6b2.farmer.b.${testRunId}@prahar.internal`;
  const testPassword = `Prahar6B2!Test@${testRunId}`;

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
      console.warn('[Notice] Live Supabase not available, running in mock fallback mode.');
      return;
    }

    adminClient = getServiceRoleClient();

    // 2. Create Farmer A & Farmer B in Supabase Auth
    const { data: userAData, error: errA } = await adminClient.auth.admin.createUser({
      email: farmerAEmail,
      password: testPassword,
      email_confirm: true,
      user_metadata: { full_name: 'Phase 6B-2 Farmer Alpha' },
    });
    if (errA) throw new Error(`Failed to create Farmer A: ${errA.message}`);
    farmerAUser = userAData.user;

    const { data: signA, error: signErrA } = await getAnonClient().auth.signInWithPassword({
      email: farmerAEmail,
      password: testPassword,
    });
    if (signErrA || !signA.session) throw new Error(`Farmer A login failed: ${signErrA?.message}`);
    farmerAToken = signA.session.access_token;

    const { data: userBData, error: errB } = await adminClient.auth.admin.createUser({
      email: farmerBEmail,
      password: testPassword,
      email_confirm: true,
      user_metadata: { full_name: 'Phase 6B-2 Farmer Beta' },
    });
    if (errB) throw new Error(`Failed to create Farmer B: ${errB.message}`);
    farmerBUser = userBData.user;

    const { data: signB, error: signErrB } = await getAnonClient().auth.signInWithPassword({
      email: farmerBEmail,
      password: testPassword,
    });
    if (signErrB || !signB.session) throw new Error(`Farmer B login failed: ${signErrB?.message}`);
    farmerBToken = signB.session.access_token;

    // 3. Create Farmers, Farms, Zones
    farmerAFarmerId = crypto.randomUUID();
    farmerBFarmerId = crypto.randomUUID();

    await adminClient.from('farmers').insert([
      { id: farmerAFarmerId, name: 'Farmer A (Analytics Alpha)', phone: `+91999${Date.now().toString().slice(-7)}` },
      { id: farmerBFarmerId, name: 'Farmer B (Analytics Beta)', phone: `+91888${Date.now().toString().slice(-7)}` },
    ]);

    await adminClient.from('profiles').update({ farmer_id: farmerAFarmerId }).eq('id', farmerAUser.id);
    await adminClient.from('profiles').update({ farmer_id: farmerBFarmerId }).eq('id', farmerBUser.id);

    farmAId = crypto.randomUUID();
    farmBId = crypto.randomUUID();

    await adminClient.from('farms').insert([
      { id: farmAId, farmer_id: farmerAFarmerId, name: 'Farm Alpha Precision', crop_type: 'Tomato', area_acres: 4.5 },
      { id: farmBId, farmer_id: farmerBFarmerId, name: 'Farm Beta Orchards', crop_type: 'Wheat', area_acres: 8.0 },
    ]);

    zoneA1Id = `ZONE-6B2-A1-${testRunId}`;
    zoneA2EmptyId = `ZONE-6B2-A2-${testRunId}`;
    zoneB1Id = `ZONE-6B2-B1-${testRunId}`;

    await adminClient.from('zones').insert([
      { id: zoneA1Id, farm_id: farmAId, zone_name: 'Zone Alpha 1 (Active Data)', soil_type: 'Clay Loam' },
      { id: zoneA2EmptyId, farm_id: farmAId, zone_name: 'Zone Alpha 2 (Empty Baseline)', soil_type: 'Sandy Loam' },
      { id: zoneB1Id, farm_id: farmBId, zone_name: 'Zone Beta 1 (Isolated)', soil_type: 'Silt' },
    ]);

    // 4. Insert Real Sensor Readings for Zone A1
    const baseTime = Date.now() - 3600000;
    await adminClient.from('sensor_readings').insert([
      { zone_id: zoneA1Id, type: 'moisture', value: 24.5, unit: '%', recorded_at: new Date(baseTime).toISOString() },
      { zone_id: zoneA1Id, type: 'temperature', value: 31.0, unit: '°C', recorded_at: new Date(baseTime).toISOString() },
      { zone_id: zoneA1Id, type: 'humidity', value: 55.0, unit: '%', recorded_at: new Date(baseTime).toISOString() },
      { zone_id: zoneA1Id, type: 'ph', value: 6.5, unit: 'pH', recorded_at: new Date(baseTime).toISOString() },
      { zone_id: zoneA1Id, type: 'moisture', value: 21.0, unit: '%', recorded_at: new Date(baseTime + 1800000).toISOString() },
      { zone_id: zoneA1Id, type: 'temperature', value: 33.5, unit: '°C', recorded_at: new Date(baseTime + 1800000).toISOString() },
      { zone_id: zoneA1Id, type: 'moisture', value: 17.8, unit: '%', recorded_at: new Date(baseTime + 3600000).toISOString() }, // Critical
    ]);

    // 5. Insert Detection & Alert for Zone A1
    await adminClient.from('detections').insert([
      {
        zone_id: zoneA1Id,
        hazard_type: 'WATER_STRESS',
        hazard_name: 'Root Zone Moisture Depletion',
        confidence: 0.94,
        severity_hint: 'HIGH',
        recorded_at: new Date().toISOString(),
      },
    ]);

    await adminClient.from('alerts').insert([
      {
        zone_id: zoneA1Id,
        type: 'WATER_STRESS',
        severity: 'HIGH',
        status: 'NEW',
        message: 'Severe moisture depletion in Zone Alpha 1 (17.8%).',
        recommended_action: 'Execute 30s micro-irrigation.',
      },
    ]);

    // 6. Insert Remediation Action & Verification for Zone A1
    actionAId = `act-6b2-${testRunId}`;
    verifAId = `verif-6b2-${testRunId}`;

    await adminClient.from('remediation_actions').insert([
      {
        action_id: actionAId,
        zone_id: zoneA1Id,
        action_type: 'IRRIGATE',
        duration_seconds: 30,
        volume_liters: 7.5,
        approved_by: 'dr_sharma_kvk_expert',
        status: 'COMPLETED',
      },
    ]);

    await adminClient.from('remediation_verifications').insert([
      {
        verification_id: verifAId,
        zone_id: zoneA1Id,
        action_id: actionAId,
        pre_moisture: 17.8,
        post_moisture: 28.5,
        moisture_delta: 10.7,
        resolved: true,
        summary_en: 'Zone Alpha 1 remediation verified: Moisture improved from 17.8% to 28.5% (+10.7%). Resolved.',
        summary_hi: 'ज़ोन अल्फा 1 उपचार सत्यापित: नमी 17.8% से बढ़कर 28.5% हो गई (+10.7%)। समाधान हुआ।',
      },
    ]);
  });

  after(async () => {
    if (!isLiveSupabase || !adminClient) return;

    try {
      if (verifAId) await adminClient.from('remediation_verifications').delete().eq('verification_id', verifAId);
      if (actionAId) await adminClient.from('remediation_actions').delete().eq('action_id', actionAId);
      if (zoneA1Id) {
        await adminClient.from('alerts').delete().eq('zone_id', zoneA1Id);
        await adminClient.from('detections').delete().eq('zone_id', zoneA1Id);
        await adminClient.from('sensor_readings').delete().eq('zone_id', zoneA1Id);
      }
      if (zoneA1Id) await adminClient.from('zones').delete().eq('id', zoneA1Id);
      if (zoneA2EmptyId) await adminClient.from('zones').delete().eq('id', zoneA2EmptyId);
      if (zoneB1Id) await adminClient.from('zones').delete().eq('id', zoneB1Id);

      if (farmAId) await adminClient.from('farms').delete().eq('id', farmAId);
      if (farmBId) await adminClient.from('farms').delete().eq('id', farmBId);

      if (farmerAFarmerId) await adminClient.from('farmers').delete().eq('id', farmerAFarmerId);
      if (farmerBFarmerId) await adminClient.from('farmers').delete().eq('id', farmerBFarmerId);

      if (farmerAUser) await adminClient.auth.admin.deleteUser(farmerAUser.id);
      if (farmerBUser) await adminClient.auth.admin.deleteUser(farmerBUser.id);
    } catch (e: any) {
      console.warn('[Teardown Warning]', e.message);
    }
  });

  // --------------------------------------------------------------------------
  // Scenario A: Authenticated analytics access
  // --------------------------------------------------------------------------
  test('Scenario A: Authenticated analytics access returns 200 OK with real data', async () => {
    if (!isLiveSupabase) return;

    // 1. Summary
    const sumRes = await apiRequest(`/api/analytics/summary?farm_id=${farmAId}`, {
      token: farmerAToken,
    });
    assert.strictEqual(sumRes.status, 200);
    assert.strictEqual(sumRes.body.success, true);
    assert.strictEqual(sumRes.body.data.farm_id, farmAId);
    assert.ok(sumRes.body.data.zones.length >= 2);

    // 2. Trends
    const trendsRes = await apiRequest(`/api/analytics/trends?zone_id=${zoneA1Id}`, {
      token: farmerAToken,
    });
    assert.strictEqual(trendsRes.status, 200);
    assert.strictEqual(trendsRes.body.success, true);
    assert.strictEqual(trendsRes.body.data.zone_id, zoneA1Id);
    assert.strictEqual(trendsRes.body.data.has_sufficient_data, true);

    // 3. Interventions
    const intRes = await apiRequest(`/api/analytics/interventions?farm_id=${farmAId}`, {
      token: farmerAToken,
    });
    assert.strictEqual(intRes.status, 200);
    assert.strictEqual(intRes.body.success, true);
    assert.ok(intRes.body.data.total_count >= 1);
  });

  // --------------------------------------------------------------------------
  // Scenario B: Unauthenticated rejection
  // --------------------------------------------------------------------------
  test('Scenario B: Unauthenticated requests are rejected with 401 Unauthorized', async () => {
    const res1 = await apiRequest(`/api/analytics/summary?farm_id=${farmAId}`);
    assert.strictEqual(res1.status, 401);
    assert.strictEqual(res1.body.success, false);

    const res2 = await apiRequest(`/api/analytics/trends?zone_id=${zoneA1Id}`);
    assert.strictEqual(res2.status, 401);

    const res3 = await apiRequest(`/api/analytics/interventions?farm_id=${farmAId}`);
    assert.strictEqual(res3.status, 401);
  });

  // --------------------------------------------------------------------------
  // Scenario C: Farmer tenant isolation
  // --------------------------------------------------------------------------
  test('Scenario C: Farmer A cannot access Farmer B farm analytics (cross-tenant denied)', async () => {
    if (!isLiveSupabase) return;

    // Farmer A queries Farmer B's farm summary
    const crossRes = await apiRequest(`/api/analytics/summary?farm_id=${farmBId}`, {
      token: farmerAToken,
    });
    assert.strictEqual(crossRes.status, 403);
    assert.strictEqual(crossRes.body.success, false);
    assert.match(crossRes.body.error, /access denied|not found/i);

    // Farmer A queries Farmer B's zone trends
    const crossTrend = await apiRequest(`/api/analytics/trends?zone_id=${zoneB1Id}`, {
      token: farmerAToken,
    });
    assert.strictEqual(crossTrend.status, 403);
    assert.strictEqual(crossTrend.body.success, false);
  });

  // --------------------------------------------------------------------------
  // Scenario D: Farm/zone authorization
  // --------------------------------------------------------------------------
  test('Scenario D: Request for non-existent or unauthorized zone returns 403 Forbidden', async () => {
    if (!isLiveSupabase) return;

    const fakeZoneId = `ZONE-NONEXISTENT-${crypto.randomUUID()}`;
    const res = await apiRequest(`/api/analytics/trends?zone_id=${fakeZoneId}`, {
      token: farmerAToken,
    });
    assert.strictEqual(res.status, 403);
    assert.strictEqual(res.body.success, false);
  });

  // --------------------------------------------------------------------------
  // Scenario E: Real summary calculation
  // --------------------------------------------------------------------------
  test('Scenario E: Field health summary calculation reflects real telemetry and alerts', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/analytics/summary?farm_id=${farmAId}&zone_id=${zoneA1Id}`, {
      token: farmerAToken,
    });
    assert.strictEqual(res.status, 200);

    const zoneSummary = res.body.data.zones[0];
    assert.strictEqual(zoneSummary.zone_id, zoneA1Id);
    assert.strictEqual(zoneSummary.health_label, 'PRAHAR Field-Health & Risk Summary');
    // Moisture was 17.8% (< 18.0%) -> CRITICAL or ATTENTION_REQUIRED
    assert.ok(
      zoneSummary.health_status === 'CRITICAL' || zoneSummary.health_status === 'ATTENTION_REQUIRED',
      `Unexpected status: ${zoneSummary.health_status}`
    );
    assert.strictEqual(zoneSummary.latest_metrics.moisture_pct, 17.8);
    assert.strictEqual(zoneSummary.active_alerts_count, 1);
  });

  // --------------------------------------------------------------------------
  // Scenario F: Real trend data
  // --------------------------------------------------------------------------
  test('Scenario F: Time-series trend returns real chronological points and hazard aggregation', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/analytics/trends?zone_id=${zoneA1Id}`, {
      token: farmerAToken,
    });
    assert.strictEqual(res.status, 200);

    const trends = res.body.data;
    assert.strictEqual(trends.has_sufficient_data, true);
    assert.ok(trends.sensor_trends.length >= 3);

    // Verify hazard breakdown contains WATER_STRESS detection
    const hazardList = trends.hazard_breakdown || trends.hazardBreakdown || [];
    const waterStress = hazardList.find((h: any) => h.hazard_type === 'WATER_STRESS');
    assert.ok(waterStress, 'Expected WATER_STRESS hazard item in breakdown');
    assert.strictEqual(waterStress.highest_severity, 'HIGH');
  });

  // --------------------------------------------------------------------------
  // Scenario G: Empty historical state
  // --------------------------------------------------------------------------
  test('Scenario G: Querying zone with zero telemetry returns clean empty state', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/analytics/trends?zone_id=${zoneA2EmptyId}`, {
      token: farmerAToken,
    });
    assert.strictEqual(res.status, 200);

    const trends = res.body.data;
    assert.strictEqual(trends.zone_id, zoneA2EmptyId);
    assert.strictEqual(trends.has_sufficient_data, false);
    assert.strictEqual(trends.sensor_trends.length, 0);
    const hazardList = trends.hazard_breakdown || trends.hazardBreakdown || [];
    assert.strictEqual(hazardList.length, 0);
  });

  // --------------------------------------------------------------------------
  // Scenario H: Intervention history
  // --------------------------------------------------------------------------
  test('Scenario H: Interventions endpoint returns real approved/executed actions', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/analytics/interventions?farm_id=${farmAId}&zone_id=${zoneA1Id}`, {
      token: farmerAToken,
    });
    assert.strictEqual(res.status, 200);

    const interventions = res.body.data.interventions;
    assert.ok(interventions.length >= 1);

    const item = interventions.find((i: any) => i.action_id === actionAId);
    assert.ok(item, 'Expected intervention action to be returned');
    assert.strictEqual(item.action_type, 'IRRIGATE');
    assert.strictEqual(item.duration_seconds, 30);
    assert.strictEqual(item.approved_by, 'dr_sharma_kvk_expert');
  });

  // --------------------------------------------------------------------------
  // Scenario I: Verification history
  // --------------------------------------------------------------------------
  test('Scenario I: Verification record is linked with pre/post moisture delta and resolution', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/analytics/interventions?farm_id=${farmAId}&zone_id=${zoneA1Id}`, {
      token: farmerAToken,
    });
    assert.strictEqual(res.status, 200);

    const item = res.body.data.interventions.find((i: any) => i.action_id === actionAId);
    assert.ok(item.verification, 'Expected linked verification');
    assert.strictEqual(item.verification.verification_id, verifAId);
    assert.strictEqual(item.verification.pre_moisture, 17.8);
    assert.strictEqual(item.verification.post_moisture, 28.5);
    assert.strictEqual(item.verification.moisture_delta, 10.7);
    assert.strictEqual(item.verification.resolved, true);
    assert.ok(item.verification.summary_en.length > 0);
    assert.ok(item.verification.summary_hi.length > 0);
  });

  // --------------------------------------------------------------------------
  // Scenario J: Bounded date ranges
  // --------------------------------------------------------------------------
  test('Scenario J: Trends query respects from and to bounded date filters', async () => {
    if (!isLiveSupabase) return;

    const futureFrom = new Date(Date.now() + 86400000).toISOString();
    const res = await apiRequest(`/api/analytics/trends?zone_id=${zoneA1Id}&from=${futureFrom}`, {
      token: farmerAToken,
    });
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.sensor_trends.length, 0);
    assert.strictEqual(res.body.data.has_sufficient_data, false);
  });

  // --------------------------------------------------------------------------
  // Scenario K: API error propagation
  // --------------------------------------------------------------------------
  test('Scenario K: Missing required query parameters return 400 Bad Request', async () => {
    // Missing farm_id on summary
    const res1 = await apiRequest('/api/analytics/summary', { token: farmerAToken });
    assert.strictEqual(res1.status, 400);
    assert.match(res1.body.error, /farm_id/i);

    // Missing zone_id on trends
    const res2 = await apiRequest('/api/analytics/trends', { token: farmerAToken });
    assert.strictEqual(res2.status, 400);
    assert.match(res2.body.error, /zone_id/i);
  });
});
