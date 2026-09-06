/**
 * PRAHAR Phase 6B-4: Opportunity & Scheme Center Test Suite
 * Validates the complete software-owned core for Opportunities & Scheme Tracking:
 * Flutter / API client -> HTTP -> JWT -> PRAHAR Gateway -> Deterministic Eligibility & Tracking -> Supabase / PostgreSQL / RLS -> Real Persistence.
 *
 * Scenarios Tested:
 * A: Authenticated/Public catalogue read returns 7 verified Indian schemes with official .gov.in/.nic.in URLs
 * B: Category & Type filtering (e.g. type=SUBSIDY, type=SCHEME)
 * C: Single opportunity detail (PM-KISAN) & 404 on missing scheme
 * D: Application guide retrieval (checklist, steps, disclaimer)
 * E: Deterministic eligibility evaluation (Likely Eligible)
 * F: Deterministic eligibility evaluation (Insufficient Information when land data is missing)
 * G: Unauthenticated rejection on eligibility evaluation (401 Unauthorized)
 * H: Tracking record creation (Farmer A tracks PM-KISAN, server derives user_id from JWT)
 * I: Tracking record update (Status: USER_SUBMITTED, immutable user_id / opportunity_id)
 * J: Invalid tracking status rejected (400 Bad Request)
 * K: Invalid opportunity_id rejected (404 Not Found)
 * L: Tenant isolation: Farmer B cannot read Farmer A's tracking records
 * M: Cross-farmer spoofing blocked (Farmer B passing ?farmer_user_id=farmerAId rejected with 403)
 * N: Real PostgreSQL persistence verified in public.farmer_opportunity_tracking
 * O: Expert authorization boundary:
 *    - Expert assigned to Farm A CAN read Farmer A tracking
 *    - Expert NOT assigned to Farm B is BLOCKED (403 Forbidden) from accessing Farmer B tracking
 */

import { test, describe, before, after } from 'node:test';
import assert from 'node:assert';
import crypto from 'node:crypto';
import { server } from '../services/rover-simulator/src/server.js';
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

const MANDATORY_DISCLAIMER =
  'Eligibility shown by PRAHAR is guidance only. Final eligibility is determined by the concerned government department/bank/authority.';

describe('Phase 6B-4: Opportunity & Scheme Center Suite', () => {
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

  const testRunId = Date.now().toString(36);
  const farmerAEmail = `phase6b4.farmer.a.${testRunId}@prahar.internal`;
  const farmerBEmail = `phase6b4.farmer.b.${testRunId}@prahar.internal`;
  const expertEmail = `phase6b4.expert.${testRunId}@prahar.internal`;
  const testPassword = `Prahar6B4!Test@${testRunId}`;

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
      console.log('Skipping live Supabase seeding: Running in local mock mode.');
      return;
    }

    adminClient = getServiceRoleClient();

    // 2. Create Farmer A Auth User & Profile
    const { data: userAData, error: uAErr } = await adminClient.auth.admin.createUser({
      email: farmerAEmail,
      password: testPassword,
      email_confirm: true,
      user_metadata: { role: 'FARMER', full_name: `Farmer A 6B4 (${testRunId})` },
    });
    if (uAErr) throw new Error(`Failed creating Farmer A: ${uAErr.message}`);
    farmerAUser = userAData.user;

    farmerAFarmerId = crypto.randomUUID();
    const { error: fErrA } = await adminClient.from('farmers').insert([
      {
        id: farmerAFarmerId,
        name: `Rameshwar Farmer A 6B4`,
        phone: `+9198${Date.now().toString().slice(-8)}`,
        language: 'en',
      },
    ]);
    if (fErrA) throw new Error(`Failed creating Farmer A: ${fErrA.message}`);

    const { error: pErrA } = await adminClient
      .from('profiles')
      .update({ farmer_id: farmerAFarmerId, role: 'FARMER' })
      .eq('id', farmerAUser.id);
    if (pErrA) throw new Error(`Failed updating profile A: ${pErrA.message}`);

    // 3. Create Farmer B Auth User & Profile
    const { data: userBData, error: uBErr } = await adminClient.auth.admin.createUser({
      email: farmerBEmail,
      password: testPassword,
      email_confirm: true,
      user_metadata: { role: 'FARMER', full_name: `Farmer B 6B4 (${testRunId})` },
    });
    if (uBErr) throw new Error(`Failed creating Farmer B: ${uBErr.message}`);
    farmerBUser = userBData.user;

    farmerBFarmerId = crypto.randomUUID();
    const { error: fErrB } = await adminClient.from('farmers').insert([
      {
        id: farmerBFarmerId,
        name: `Suresh Farmer B 6B4`,
        phone: `+9197${Date.now().toString().slice(-8)}`,
        language: 'hi',
      },
    ]);
    if (fErrB) throw new Error(`Failed creating Farmer B: ${fErrB.message}`);

    const { error: pErrB } = await adminClient
      .from('profiles')
      .update({ farmer_id: farmerBFarmerId, role: 'FARMER' })
      .eq('id', farmerBUser.id);
    if (pErrB) throw new Error(`Failed updating profile B: ${pErrB.message}`);

    // 4. Create Expert Auth User & Profile
    const { data: expertData, error: expErr } = await adminClient.auth.admin.createUser({
      email: expertEmail,
      password: testPassword,
      email_confirm: true,
      user_metadata: { role: 'EXPERT', full_name: `Expert Dr. Sharma 6B4 (${testRunId})` },
    });
    if (expErr) throw new Error(`Failed creating Expert: ${expErr.message}`);
    expertUser = expertData.user;

    const { error: expPErr } = await adminClient
      .from('profiles')
      .update({ role: 'EXPERT' })
      .eq('id', expertUser.id);
    if (expPErr) throw new Error(`Failed updating expert profile: ${expPErr.message}`);

    // 5. Create Farm A for Farmer A (6.18 acres ~ 2.5 hectares)
    farmAId = crypto.randomUUID();
    const { error: farmErrA } = await adminClient.from('farms').insert([
      {
        id: farmAId,
        farmer_id: farmerAFarmerId,
        name: 'Alpha Orchard 6B-4',
        crop_type: 'Wheat',
        area_acres: 6.18,
      },
    ]);
    if (farmErrA) throw new Error(`Failed creating Farm A: ${farmErrA.message}`);

    // 6. Create Farm B for Farmer B (2.47 acres ~ 1.0 hectare)
    farmBId = crypto.randomUUID();
    const { error: farmErrB } = await adminClient.from('farms').insert([
      {
        id: farmBId,
        farmer_id: farmerBFarmerId,
        name: 'Beta Fields 6B-4',
        crop_type: 'Soybean',
        area_acres: 2.47,
      },
    ]);
    if (farmErrB) throw new Error(`Failed creating Farm B: ${farmErrB.message}`);

    // 7. Assign Expert to Farm A ONLY (Tenant boundary)
    const { error: assignErr } = await adminClient.from('expert_farm_assignments').insert([
      {
        expert_id: expertUser.id,
        farm_id: farmAId,
      },
    ]);
    if (assignErr) throw new Error(`Failed assigning expert to Farm A: ${assignErr.message}`);

    // 8. Log in users to get verified JWTs
    const anon = getAnonClient();
    const loginA = await anon.auth.signInWithPassword({ email: farmerAEmail, password: testPassword });
    farmerAToken = loginA.data.session?.access_token || '';

    const loginB = await anon.auth.signInWithPassword({ email: farmerBEmail, password: testPassword });
    farmerBToken = loginB.data.session?.access_token || '';

    const loginExp = await anon.auth.signInWithPassword({ email: expertEmail, password: testPassword });
    expertToken = loginExp.data.session?.access_token || '';

    assert.ok(farmerAToken, 'Farmer A token must exist');
    assert.ok(farmerBToken, 'Farmer B token must exist');
    assert.ok(expertToken, 'Expert token must exist');
  });

  after(async () => {
    if (!isLiveSupabase || !adminClient) return;

    try {
      // Clean up tracking records
      if (farmerAUser?.id || farmerBUser?.id) {
        await adminClient
          .from('farmer_opportunity_tracking')
          .delete()
          .in('user_id', [farmerAUser?.id, farmerBUser?.id].filter(Boolean));
      }

      if (expertUser?.id && farmAId) {
        await adminClient.from('expert_farm_assignments').delete().eq('expert_id', expertUser.id);
      }

      if (farmAId) await adminClient.from('farms').delete().eq('id', farmAId);
      if (farmBId) await adminClient.from('farms').delete().eq('id', farmBId);
      if (farmerAFarmerId) await adminClient.from('farmers').delete().eq('id', farmerAFarmerId);
      if (farmerBFarmerId) await adminClient.from('farmers').delete().eq('id', farmerBFarmerId);

      if (farmerAUser?.id) await adminClient.auth.admin.deleteUser(farmerAUser.id);
      if (farmerBUser?.id) await adminClient.auth.admin.deleteUser(farmerBUser.id);
      if (expertUser?.id) await adminClient.auth.admin.deleteUser(expertUser.id);
    } catch (cleanupErr) {
      console.warn('Cleanup warning:', cleanupErr);
    }
  });

  test('Scenario A: Public/Authenticated catalogue read returns verified schemes with official .gov.in/.nic.in URLs', async () => {
    const res = await apiRequest('/api/opportunities');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.success, true);
    assert.ok(Array.isArray(res.body.data), 'Expected array of opportunities in data');
    assert.ok(res.body.data.length >= 7, 'Expected at least 7 verified opportunities');

    for (const opp of res.body.data) {
      assert.ok(opp.id, 'Opportunity must have an id');
      assert.ok(opp.title_en, 'Opportunity must have title_en');
      assert.ok(opp.title_hi, 'Opportunity must have title_hi');
      assert.ok(opp.type, 'Opportunity must have type');
      assert.ok(['SCHEME', 'SUBSIDY', 'LOAN', 'INSURANCE', 'SUPPORT'].includes(opp.type), 'Valid opportunity type');
      assert.ok(opp.status === 'VERIFIED', 'Opportunity must be marked VERIFIED');
      assert.ok(
        opp.official_portal_url.includes('.gov.in') || opp.official_portal_url.includes('.nic.in'),
        `Official portal URL must be official government domain (.gov.in or .nic.in). Got: ${opp.official_portal_url}`
      );
      assert.ok(opp.disclaimer.includes('Eligibility shown by PRAHAR is guidance only'), 'Mandatory disclaimer required');
    }
  });

  test('Scenario B: Category & Type filtering works correctly', async () => {
    const resSub = await apiRequest('/api/opportunities?type=SUBSIDY');
    assert.strictEqual(resSub.status, 200);
    assert.ok(resSub.body.data.length >= 3, 'Expected subsidy schemes');
    for (const s of resSub.body.data) {
      assert.strictEqual(s.type, 'SUBSIDY');
    }

    const resScheme = await apiRequest('/api/opportunities?type=SCHEME');
    assert.strictEqual(resScheme.status, 200);
    assert.ok(resScheme.body.data.some((s: any) => s.id === 'PM-KISAN'), 'PM-KISAN must be present');
  });

  test('Scenario C: Single opportunity detail (PM-KISAN) and 404 for unknown', async () => {
    const res = await apiRequest('/api/opportunities/PM-KISAN');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.id, 'PM-KISAN');
    assert.strictEqual(res.body.data.official_portal_url, 'https://pmkisan.gov.in');

    const resUnknown = await apiRequest('/api/opportunities/UNKNOWN-SCHEME-999');
    assert.strictEqual(resUnknown.status, 404);
  });

  test('Scenario D: Application guide retrieval includes checklist, steps, and portal URL', async () => {
    const res = await apiRequest('/api/opportunities/PM-KISAN/application-guide');
    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.opportunity_id, 'PM-KISAN');
    assert.ok(Array.isArray(res.body.data.required_documents), 'Checklist must be an array');
    assert.ok(res.body.data.required_documents.length >= 3, 'Must have at least 3 required documents');
    assert.ok(Array.isArray(res.body.data.application_steps), 'Application steps must be an array');
    assert.ok(res.body.data.application_steps.length >= 2, 'Must have at least 2 application steps');
    assert.strictEqual(res.body.data.official_portal_url, 'https://pmkisan.gov.in');
    assert.strictEqual(res.body.data.disclaimer, MANDATORY_DISCLAIMER);
  });

  test('Scenario E: Deterministic eligibility evaluation (Likely Eligible)', async () => {
    if (!isLiveSupabase) return;

    // Farmer A has 2.5 hectares (~6.18 acres), which satisfies PM-KUSUM (>= 0.5 acres)
    const res = await apiRequest('/api/opportunities/check-eligibility', {
      method: 'POST',
      token: farmerAToken,
      body: {
        opportunity_id: 'PM-KUSUM-SOLAR',
        farm_id: farmAId,
      },
    });

    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
    assert.strictEqual(res.body.data.opportunity_id, 'PM-KUSUM-SOLAR');
    assert.strictEqual(res.body.data.status, 'LIKELY_ELIGIBLE');
    assert.ok(res.body.data.matched_criteria_en.length > 0, 'Should have matched criteria');
    assert.strictEqual(res.body.data.disclaimer, MANDATORY_DISCLAIMER);
  });

  test('Scenario F: Deterministic eligibility evaluation (Insufficient Information when land acres missing)', async () => {
    if (!isLiveSupabase) return;

    // Evaluate without providing farm_id and with an empty farm context
    const res = await apiRequest('/api/opportunities/check-eligibility', {
      method: 'POST',
      token: farmerAToken,
      body: {
        opportunity_id: 'PM-KUSUM-SOLAR',
        farm_id: '00000000-0000-0000-0000-000000000000', // non-existent farm, no land acres
      },
    });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.status, 'INSUFFICIENT_INFORMATION');
    assert.ok(res.body.data.missing_information_en.length > 0, 'Must declare missing information');
    assert.strictEqual(res.body.data.disclaimer, MANDATORY_DISCLAIMER);
  });

  test('Scenario G: Unauthenticated rejection on eligibility evaluation (401 Unauthorized)', async () => {
    const res = await apiRequest('/api/opportunities/check-eligibility', {
      method: 'POST',
      body: { opportunity_id: 'PM-KISAN' },
    });
    assert.strictEqual(res.status, 401);

    const resBadToken = await apiRequest('/api/opportunities/check-eligibility', {
      method: 'POST',
      token: 'invalid.bearer.token',
      body: { opportunity_id: 'PM-KISAN' },
    });
    assert.strictEqual(resBadToken.status, 401);
  });

  test('Scenario H: Tracking record creation (Farmer A tracks PM-KISAN)', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest('/api/opportunities/tracking', {
      method: 'POST',
      token: farmerAToken,
      body: {
        opportunity_id: 'PM-KISAN',
        status: 'PREPARING',
        notes: 'Gathering land records and Aadhaar eKYC',
      },
    });

    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
    assert.strictEqual(res.body.data.opportunity_id, 'PM-KISAN');
    assert.strictEqual(res.body.data.status, 'PREPARING');
    assert.strictEqual(res.body.data.user_id, farmerAUser.id);
  });

  test('Scenario I: Tracking record update (Status: USER_SUBMITTED with notes, immutable user_id / opportunity_id)', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest('/api/opportunities/tracking', {
      method: 'POST',
      token: farmerAToken,
      body: {
        opportunity_id: 'PM-KISAN',
        status: 'USER_SUBMITTED',
        notes: 'Submitted on pmkisan.gov.in portal. Application Ref: PMK-2026-9812',
      },
    });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.status, 'USER_SUBMITTED');
    assert.strictEqual(res.body.data.user_id, farmerAUser.id, 'user_id must remain Farmer A');
    assert.strictEqual(res.body.data.opportunity_id, 'PM-KISAN', 'opportunity_id must remain PM-KISAN');

    // Verify GET /api/opportunities/tracking lists this record
    const listRes = await apiRequest('/api/opportunities/tracking', {
      token: farmerAToken,
    });
    assert.strictEqual(listRes.status, 200);
    assert.ok(listRes.body.data.some((t: any) => t.opportunity_id === 'PM-KISAN' && t.status === 'USER_SUBMITTED'));
  });

  test('Scenario J: Invalid tracking status rejected with 400 Bad Request', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest('/api/opportunities/tracking', {
      method: 'POST',
      token: farmerAToken,
      body: {
        opportunity_id: 'PM-KISAN',
        status: 'OFFICIALLY_APPROVED_BY_GOVERNMENT', // invalid fabricated status
      },
    });

    assert.strictEqual(res.status, 400);
  });

  test('Scenario K: Invalid opportunity_id rejected with 404 Not Found', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest('/api/opportunities/tracking', {
      method: 'POST',
      token: farmerAToken,
      body: {
        opportunity_id: 'FABRICATED-FAKE-SCHEME',
        status: 'PREPARING',
      },
    });

    assert.strictEqual(res.status, 404);
  });

  test('Scenario L: Tenant Isolation (Farmer B cannot read Farmer A tracking records)', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest('/api/opportunities/tracking', {
      token: farmerBToken,
    });

    assert.strictEqual(res.status, 200);
    assert.ok(
      !res.body.data.some((t: any) => t.user_id === farmerAUser.id),
      'Farmer B MUST NOT see Farmer A tracking records'
    );
  });

  test('Scenario M: Cross-Farmer Spoofing Blocked (Farmer B passing ?farmer_user_id=farmerAId rejected with 403)', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/opportunities/tracking?farmer_user_id=${farmerAUser.id}`, {
      token: farmerBToken,
    });

    assert.strictEqual(res.status, 403, 'Cross-farmer tracking query MUST be rejected with 403 Forbidden');
  });

  test('Scenario N: Real PostgreSQL persistence verified in public.farmer_opportunity_tracking', async () => {
    if (!isLiveSupabase) return;

    const { data, error } = await adminClient
      .from('farmer_opportunity_tracking')
      .select('*')
      .eq('user_id', farmerAUser.id)
      .eq('opportunity_id', 'PM-KISAN');

    assert.strictEqual(error, null);
    assert.ok(data && data.length === 1, 'Record must exist in public.farmer_opportunity_tracking table');
    assert.strictEqual(data[0].status, 'USER_SUBMITTED');
  });

  test('Scenario O: Expert Authorization Boundary', async () => {
    if (!isLiveSupabase) return;

    // 1. Expert is assigned to Farm A (Farmer A) -> CAN query Farmer A's tracking
    const resAssigned = await apiRequest(`/api/opportunities/tracking?farmer_user_id=${farmerAUser.id}`, {
      token: expertToken,
    });
    assert.strictEqual(resAssigned.status, 200, 'Expert assigned to Farm A must be authorized');
    assert.ok(
      resAssigned.body.data.some((t: any) => t.opportunity_id === 'PM-KISAN'),
      'Expert should see Farmer A tracking'
    );

    // 2. Expert is NOT assigned to Farm B (Farmer B) -> MUST BE REJECTED with 403
    const resUnassigned = await apiRequest(`/api/opportunities/tracking?farmer_user_id=${farmerBUser.id}`, {
      token: expertToken,
    });
    assert.strictEqual(
      resUnassigned.status,
      403,
      'Expert NOT assigned to Farm B must be rejected with 403 Forbidden'
    );
  });
});
