/**
 * PRAHAR Phase 6B-3: Report Export & Field Evidence Report Test Suite
 * Validates the software-owned core for Field Evidence Reports:
 * Authenticated JWT -> Gateway Endpoints -> Multi-Tenant PostgreSQL RLS -> Authoritative Field Evidence Report & Valid PDF-1.4 Generation.
 *
 * Scenarios Tested:
 * A. Authenticated report access (200 OK with structured JSON)
 * B. Unauthenticated rejection (401 Unauthorized when missing or invalid JWT)
 * C. Farmer tenant isolation (Farmer A cannot access Farmer B's farm report)
 * D. Unauthorized zone access (Access to unowned farm/zone rejected)
 * E. Authoritative data fidelity (Reflects real database values, sensor evidence, hazards, and verifications)
 * F. Date range filtering (Bounded historical window for hazards and alerts)
 * G. Report identity & metadata (Deterministic PFER report ID, timestamps, zone info)
 * H. Mandatory exact disclaimer verification in JSON response
 * I. Real valid PDF-1.4 binary generation (Header %PDF-1.4, EOF, exact disclaimer embedded)
 * J. Read-only guarantee (Report generation causes ZERO state mutations)
 * K. Direct PDF download stream (Content-Type: application/pdf, Content-Disposition: attachment)
 * L. Parameter validation (400 Bad Request when farm_id is missing)
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
} from '../services/rover-simulator/src/supabase-client.js';

// Load .env if present
if (typeof process.loadEnvFile === 'function') {
  try {
    process.loadEnvFile();
  } catch {}
}

const MANDATORY_DISCLAIMER =
  'This report is an informational field-evidence summary generated from PRAHAR system observations and AI/edge outputs. It is not an official government certificate, legal warranty, or guaranteed diagnosis.';

describe('Phase 6B-3: Field Evidence Report & PDF Export Suite', () => {
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
  let zoneB1Id: string = '';

  let actionAId: string = '';
  let verifAId: string = '';

  const testRunId = Date.now().toString(36);
  const farmerAEmail = `phase6b3.farmer.a.${testRunId}@prahar.internal`;
  const farmerBEmail = `phase6b3.farmer.b.${testRunId}@prahar.internal`;
  const testPassword = `Prahar6B3!Test@${testRunId}`;

  async function apiRequest(
    path: string,
    options: { method?: string; token?: string; body?: any; accept?: string } = {}
  ): Promise<{ status: number; headers: Headers; body: any; rawBuffer?: Buffer }> {
    const headers: Record<string, string> = {};
    if (options.accept) {
      headers['Accept'] = options.accept;
    } else {
      headers['Accept'] = 'application/json';
    }
    if (options.body) {
      headers['Content-Type'] = 'application/json';
    }
    if (options.token) {
      headers['Authorization'] = `Bearer ${options.token}`;
    }

    const res = await fetch(`${baseUrl}${path}`, {
      method: options.method || 'GET',
      headers,
      body: options.body ? JSON.stringify(options.body) : undefined,
    });

    const contentType = res.headers.get('content-type') || '';
    if (contentType.includes('application/pdf') || contentType.includes('octet-stream')) {
      const arrayBuf = await res.arrayBuffer();
      return {
        status: res.status,
        headers: res.headers,
        body: null,
        rawBuffer: Buffer.from(arrayBuf),
      };
    }

    const body = await res.json().catch(() => ({}));
    return { status: res.status, headers: res.headers, body };
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
      console.warn('[Notice] Live Supabase not available, skipping live tenant setup.');
      return;
    }

    adminClient = getServiceRoleClient();

    // 2. Create Farmer A & Farmer B in Supabase Auth
    const { data: userAData, error: errA } = await adminClient.auth.admin.createUser({
      email: farmerAEmail,
      password: testPassword,
      email_confirm: true,
      user_metadata: { full_name: 'Phase 6B-3 Farmer Alpha' },
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
      user_metadata: { full_name: 'Phase 6B-3 Farmer Beta' },
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

    const { error: fErr } = await adminClient.from('farmers').insert([
      { id: farmerAFarmerId, name: 'Farmer Alpha 6B-3', phone: `+9198${Date.now().toString().slice(-8)}` },
      { id: farmerBFarmerId, name: 'Farmer Beta 6B-3', phone: `+9197${Date.now().toString().slice(-8)}` },
    ]);
    if (fErr) throw new Error(`Failed to insert farmers: ${fErr.message}`);

    const { error: pErrA } = await adminClient.from('profiles').update({ farmer_id: farmerAFarmerId }).eq('id', farmerAUser.id);
    if (pErrA) throw new Error(`Failed to update profile A: ${pErrA.message}`);
    const { error: pErrB } = await adminClient.from('profiles').update({ farmer_id: farmerBFarmerId }).eq('id', farmerBUser.id);
    if (pErrB) throw new Error(`Failed to update profile B: ${pErrB.message}`);

    farmAId = crypto.randomUUID();
    farmBId = crypto.randomUUID();

    const { error: farmErr } = await adminClient.from('farms').insert([
      { id: farmAId, farmer_id: farmerAFarmerId, name: 'Alpha Orchard 6B-3', crop_type: 'Tomato', area_acres: 5.5 },
      { id: farmBId, farmer_id: farmerBFarmerId, name: 'Beta Fields 6B-3', crop_type: 'Wheat', area_acres: 8.0 },
    ]);
    if (farmErr) throw new Error(`Failed to insert farms: ${farmErr.message}`);

    zoneA1Id = `ZONE-6B3-A1-${testRunId}`;
    zoneB1Id = `ZONE-6B3-B1-${testRunId}`;

    await adminClient.from('zones').insert([
      { id: zoneA1Id, farm_id: farmAId, zone_name: 'Zone A-North 6B-3', soil_type: 'Clay Loam' },
      { id: zoneB1Id, farm_id: farmBId, zone_name: 'Zone B-East 6B-3', soil_type: 'Sandy Loam' },
    ]);

    // 4. Seed Sensor Readings, Detections, Alerts, Interventions, Verifications for Farm A
    const now = new Date();
    await adminClient.from('sensor_readings').insert([
      { zone_id: zoneA1Id, type: 'moisture', value: 18.5, unit: '%', recorded_at: now.toISOString() },
      { zone_id: zoneA1Id, type: 'temperature', value: 29.4, unit: '°C', recorded_at: now.toISOString() },
      { zone_id: zoneA1Id, type: 'humidity', value: 62.0, unit: '%', recorded_at: now.toISOString() },
      { zone_id: zoneA1Id, type: 'ph', value: 6.8, unit: 'pH', recorded_at: now.toISOString() },
    ]);

    const detId = crypto.randomUUID();
    await adminClient.from('detections').insert([
      {
        id: detId,
        zone_id: zoneA1Id,
        recorded_at: now.toISOString(),
        hazard_type: 'WATER_STRESS',
        hazard_name: 'Severe Water Stress',
        confidence: 0.92,
        severity_hint: 'HIGH',
      },
    ]);

    const alertId = crypto.randomUUID();
    await adminClient.from('alerts').insert([
      {
        id: alertId,
        zone_id: zoneA1Id,
        type: 'WATER_STRESS',
        severity: 'HIGH',
        status: 'NEW',
        message: 'Critical Soil Moisture Deficit in Zone A-North',
        recommended_action: 'Micro-irrigation',
        created_at: now.toISOString(),
      },
    ]);

    actionAId = `act-6b3-${testRunId}`;
    const { error: actErr } = await adminClient.from('remediation_actions').insert([
      {
        action_id: actionAId,
        zone_id: zoneA1Id,
        action_type: 'IRRIGATE',
        status: 'COMPLETED',
        duration_seconds: 45,
        volume_liters: 7.5,
        approved_by: 'dr_sharma_kvk_expert',
      },
    ]);
    if (actErr) throw new Error(`Failed to insert action: ${actErr.message}`);

    verifAId = `verif-6b3-${testRunId}`;
    const { error: vErr } = await adminClient.from('remediation_verifications').insert([
      {
        verification_id: verifAId,
        zone_id: zoneA1Id,
        action_id: actionAId,
        pre_moisture: 18.5,
        post_moisture: 28.5,
        moisture_delta: 10.0,
        resolved: true,
        summary_en: 'Target moisture restored to 28.5% (+10.0% delta). Action verified.',
        summary_hi: 'नमी का स्तर 28.5% (+10.0% बदलाव) तक सुधरा। उपचार सत्यापित।',
      },
    ]);
    if (vErr) throw new Error(`Failed to insert verification: ${vErr.message}`);
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
        await adminClient.from('zones').delete().eq('id', zoneA1Id);
      }
      if (zoneB1Id) await adminClient.from('zones').delete().eq('id', zoneB1Id);
      if (farmAId) await adminClient.from('farms').delete().eq('id', farmAId);
      if (farmBId) await adminClient.from('farms').delete().eq('id', farmBId);
      if (farmerAFarmerId) await adminClient.from('farmers').delete().eq('id', farmerAFarmerId);
      if (farmerBFarmerId) await adminClient.from('farmers').delete().eq('id', farmerBFarmerId);

      if (farmerAUser?.id) await adminClient.auth.admin.deleteUser(farmerAUser.id);
      if (farmerBUser?.id) await adminClient.auth.admin.deleteUser(farmerBUser.id);
    } catch (cleanupErr) {
      console.warn('Cleanup warning:', cleanupErr);
    }
  });

  test('Scenario A: Authenticated report access returns 200 OK with structured JSON', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId}&zone_id=${zoneA1Id}`, {
      token: farmerAToken,
    });

    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}: ${JSON.stringify(res.body)}`);
    assert.strictEqual(res.body.success, true);
    assert.ok(res.body.data, 'Expected data object');
    assert.strictEqual(res.body.data.farm_id, farmAId);
    assert.strictEqual(res.body.data.zone_id, zoneA1Id);
    assert.strictEqual(res.body.data.farm_name, 'Alpha Orchard 6B-3');
    assert.strictEqual(res.body.data.zone_name, 'Zone A-North 6B-3');
  });

  test('Scenario B: Unauthenticated request is rejected with 401 Unauthorized', async () => {
    const resNoToken = await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId || 'farm-demo-01'}`);
    assert.strictEqual(resNoToken.status, 401, `Expected 401 on missing token, got ${resNoToken.status}`);

    const resBadToken = await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId || 'farm-demo-01'}`, {
      token: 'invalid.bearer.token',
    });
    assert.strictEqual(resBadToken.status, 401, `Expected 401 on bad token, got ${resBadToken.status}`);
  });

  test('Scenario C: Tenant isolation: Farmer A cannot access Farmer B farm report', async () => {
    if (!isLiveSupabase) return;

    // Farmer A attempts to access Farmer B's farm
    const res = await apiRequest(`/api/reports/field-evidence?farm_id=${farmBId}`, {
      token: farmerAToken,
    });

    assert.ok(
      res.status === 403 || (res.status === 200 && res.body.data?.farm_name === ''),
      `Cross-tenant farm access must be rejected or isolated. Got status ${res.status}`
    );
  });

  test('Scenario D: Unauthorized zone access: querying an unowned zone is denied', async () => {
    if (!isLiveSupabase) return;

    // Farmer A attempts to access Zone B1 (which belongs to Farm B)
    const res = await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId}&zone_id=${zoneB1Id}`, {
      token: farmerAToken,
    });

    assert.ok(
      res.status === 403 || res.status === 400 || (res.status === 200 && res.body.data?.hazard_history?.length === 0),
      `Cross-tenant zone access must not leak data. Got status ${res.status}`
    );
  });

  test('Scenario E: Authoritative data fidelity: report reflects real database records', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId}&zone_id=${zoneA1Id}`, {
      token: farmerAToken,
    });

    assert.strictEqual(res.status, 200);
    const report = res.body.data;

    // Verify Sensor evidence
    assert.strictEqual(report.sensor_evidence.moisture, 18.5);
    assert.strictEqual(report.sensor_evidence.temperature, 29.4);
    assert.strictEqual(report.sensor_evidence.ph, 6.8);

    // Verify Hazards
    assert.ok(report.hazard_history.length > 0, 'Expected hazard history from detections');
    assert.strictEqual(report.hazard_history[0].hazard_type, 'WATER_STRESS');

    // Verify Interventions & Verification
    assert.ok(report.interventions_history.length > 0, 'Expected intervention history');
    assert.strictEqual(report.interventions_history[0].action_type, 'IRRIGATE');
    assert.strictEqual(report.interventions_history[0].verification?.resolved, true);
    assert.strictEqual(report.interventions_history[0].verification?.moisture_delta, 10.0);

    // Verify deterministic health summary
    assert.ok(report.field_health_summary, 'Expected field_health_summary');
    assert.ok(report.field_health_summary.status, 'Expected health status');
  });

  test('Scenario F: Date range filtering restricts time-series data', async () => {
    if (!isLiveSupabase) return;

    // Filter for a past window (10 days ago to 5 days ago), which should return no recent detections
    const pastFrom = new Date(Date.now() - 10 * 86400000).toISOString();
    const pastTo = new Date(Date.now() - 5 * 86400000).toISOString();

    const res = await apiRequest(
      `/api/reports/field-evidence?farm_id=${farmAId}&zone_id=${zoneA1Id}&from=${pastFrom}&to=${pastTo}`,
      { token: farmerAToken }
    );

    assert.strictEqual(res.status, 200);
    assert.strictEqual(res.body.data.hazard_history.length, 0, 'Past window should contain no recent hazards');
  });

  test('Scenario G: Report identity & metadata: deterministic PFER ID and timestamps', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId}`, {
      token: farmerAToken,
    });

    assert.strictEqual(res.status, 200);
    const report = res.body.data;
    assert.ok(report.report_id.startsWith('PFER-'), `Expected report_id to start with PFER-, got ${report.report_id}`);
    assert.ok(report.generated_at, 'Expected generated_at timestamp');
    assert.ok(report.period, 'Expected period metadata');
  });

  test('Scenario H: Mandatory exact disclaimer present in JSON response', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId}`, {
      token: farmerAToken,
    });

    assert.strictEqual(res.status, 200);
    assert.strictEqual(
      res.body.data.disclaimer,
      MANDATORY_DISCLAIMER,
      'JSON disclaimer must match exact mandatory text'
    );
  });

  test('Scenario I: Valid PDF-1.4 binary generation', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId}&format=pdf`, {
      token: farmerAToken,
      accept: 'application/pdf',
    });

    assert.strictEqual(res.status, 200, `Expected 200, got ${res.status}`);
    assert.ok(res.rawBuffer, 'Expected binary rawBuffer in response');

    const pdfBuffer = res.rawBuffer!;
    assert.ok(pdfBuffer.length > 500, `PDF size too small: ${pdfBuffer.length} bytes`);

    // Verify PDF-1.4 header
    const header = pdfBuffer.subarray(0, 8).toString('ascii');
    assert.ok(header.startsWith('%PDF-1.4'), `Expected %PDF-1.4 header, got: ${header}`);

    // Verify PDF end of file marker
    const tail = pdfBuffer.subarray(pdfBuffer.length - 30).toString('ascii');
    assert.ok(tail.includes('%%EOF'), `Expected %%EOF in PDF trailer, got: ${tail}`);

    // Verify PDF content contains report identifier and disclaimer text
    const contentStr = pdfBuffer.toString('latin1');
    assert.ok(contentStr.includes('PRAHAR Field Evidence Report'), 'PDF must contain report title');
    assert.ok(contentStr.includes('Alpha Orchard 6B-3'), 'PDF must contain authoritative farm name');
    assert.ok(contentStr.includes('informational field-evidence summary'), 'PDF must contain disclaimer excerpt');
  });

  test('Scenario J: Reports are strictly read-only and cause ZERO database mutations', async () => {
    if (!isLiveSupabase) return;

    // Count records before
    const { count: alertsBefore } = await adminClient.from('alerts').select('*', { count: 'exact', head: true });
    const { count: actionsBefore } = await adminClient.from('remediation_actions').select('*', { count: 'exact', head: true });
    const { count: verifsBefore } = await adminClient.from('remediation_verifications').select('*', { count: 'exact', head: true });

    // Request multiple report generations in JSON and PDF
    await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId}`, { token: farmerAToken });
    await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId}&format=pdf`, { token: farmerAToken, accept: 'application/pdf' });
    await apiRequest('/api/reports/field-evidence/generate', {
      method: 'POST',
      token: farmerAToken,
      body: { farm_id: farmAId, format: 'json' },
    });

    // Count records after
    const { count: alertsAfter } = await adminClient.from('alerts').select('*', { count: 'exact', head: true });
    const { count: actionsAfter } = await adminClient.from('remediation_actions').select('*', { count: 'exact', head: true });
    const { count: verifsAfter } = await adminClient.from('remediation_verifications').select('*', { count: 'exact', head: true });

    assert.strictEqual(alertsAfter, alertsBefore, 'Alert count must not mutate during report generation');
    assert.strictEqual(actionsAfter, actionsBefore, 'Action count must not mutate during report generation');
    assert.strictEqual(verifsAfter, verifsBefore, 'Verification count must not mutate during report generation');
  });

  test('Scenario K: Direct PDF download stream headers', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest(`/api/reports/field-evidence?farm_id=${farmAId}&format=pdf`, {
      token: farmerAToken,
      accept: 'application/pdf',
    });

    assert.strictEqual(res.status, 200);
    const contentType = res.headers.get('content-type');
    const contentDisp = res.headers.get('content-disposition');

    assert.ok(contentType?.includes('application/pdf'), `Expected application/pdf, got ${contentType}`);
    assert.ok(contentDisp?.includes('attachment'), `Expected attachment disposition, got ${contentDisp}`);
    assert.ok(contentDisp?.includes('.pdf'), `Expected filename ending in .pdf, got ${contentDisp}`);
  });

  test('Scenario L: Parameter validation: missing farm_id returns 400 Bad Request', async () => {
    if (!isLiveSupabase) return;

    const res = await apiRequest('/api/reports/field-evidence', {
      token: farmerAToken,
    });

    assert.strictEqual(res.status, 400, `Expected 400 Bad Request on missing farm_id, got ${res.status}`);
    assert.strictEqual(res.body.success, false);
    assert.ok(res.body.error?.includes('farm_id'), `Expected error message to mention farm_id, got: ${res.body.error}`);
  });
});
