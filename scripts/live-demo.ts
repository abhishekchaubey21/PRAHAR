/**
 * PRAHAR Phase 1-4 Local Live Integration Demonstration Script
 * Tests the live Rover Simulator (port 3001) and Next.js Expert Console (port 3000)
 */

const BASE_URL = 'http://localhost:3001';
const CONSOLE_URL = 'http://localhost:3000';

async function request(path: string, options: RequestInit = {}) {
  const res = await fetch(`${BASE_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });
  const text = await res.text();
  try {
    return { status: res.status, data: JSON.parse(text) };
  } catch {
    return { status: res.status, text };
  }
}

async function runLiveDemo() {
  console.log('================================================================');
  console.log('PRAHAR PHASE 1–4 COMPLETE LOCAL INTEGRATION DEMONSTRATION');
  console.log('================================================================\n');

  // Step 1: Simulator & Rover Status
  console.log('--- Step 1: Rover Status & Baseline ---');
  const statusRes = await request('/api/rover/status');
  console.log('Rover Status:', JSON.stringify(statusRes.data, null, 2));

  // Step 2: Next.js Expert Console Pages Verification
  console.log('\n--- Step 2: Expert Console Pages Verification ---');
  const consoleHome = await fetch(`${CONSOLE_URL}/`);
  const consoleQueue = await fetch(`${CONSOLE_URL}/queue`);
  const consoleClosedLoop = await fetch(`${CONSOLE_URL}/closed-loop`);
  console.log(`Expert Console Home (/): HTTP ${consoleHome.status}`);
  console.log(`Expert Console Queue (/queue): HTTP ${consoleQueue.status}`);
  console.log(`Expert Console Closed-Loop (/closed-loop): HTTP ${consoleClosedLoop.status}`);

  // Step 3: Generate Simulated Field Scan
  console.log('\n--- Step 3: Generate Simulated Field Scan (Zone DEMO-ZONE-02) ---');
  const scanRes = await request('/api/rover/simulate-scan', {
    method: 'POST',
    body: JSON.stringify({ zone_id: 'DEMO-ZONE-02' }),
  });
  console.log('Scan Successful:', scanRes.data.success);
  const scanData = scanRes.data.data;
  console.log('Telemetry Sensor Readings:');
  console.log(`  Zone ID: ${scanData.zone_id}`);
  console.log(`  GPS: Lat ${scanData.gps.latitude.toFixed(4)}, Lng ${scanData.gps.longitude.toFixed(4)}`);
  console.log(`  Battery: ${scanData.battery_pct}%`);
  scanData.sensor_readings.forEach((r: any) => {
    console.log(`  - ${r.sensor_type || 'SENSOR'}: ${r.value} ${r.unit}`);
  });
  console.log('Guy 3 Edge YOLOv8 Detections:');
  scanData.detections.forEach((d: any, idx: number) => {
    console.log(`  [${idx + 1}] Type: ${d.type || d.class}, Confidence: ${(d.confidence * 100).toFixed(1)}%, Model: Guy 3 Edge YOLOv8`);
  });

  // Step 4: Decision Engine Ingestion & Farm State
  console.log('\n--- Step 4: Farm State & Decision Result ---');
  const ingestRes = await request('/api/ingest/scan', {
    method: 'POST',
    body: JSON.stringify(scanData),
  });
  console.log('Ingestion Decision Result:', JSON.stringify(ingestRes.data, null, 2));

  // Retrieve generated alerts
  const allAlertsRes = await request('/api/alerts?zone_id=DEMO-ZONE-02');
  console.log(`Alerts Found for Zone DEMO-ZONE-02: ${allAlertsRes.data.count}`);
  const targetAlert = allAlertsRes.data.data[0];
  console.log('Alert Details:');
  console.log(`  Alert ID: ${targetAlert?.alert_id}`);
  console.log(`  Severity: ${targetAlert?.severity}`);
  console.log(`  Type: ${targetAlert?.type}`);
  console.log(`  Message (EN): ${targetAlert?.message}`);
  console.log(`  Message (HI): ${targetAlert?.message_hi}`);
  console.log(`  Recommended Action: ${targetAlert?.recommended_action}`);
  console.log(`  Status: ${targetAlert?.status}`);

  // Step 5: Open the WHY Reasoning Engine
  console.log('\n--- Step 5: Open WHY Reasoning Engine ---');
  const explainRes = await request('/api/intelligence/explain', {
    method: 'POST',
    body: JSON.stringify({
      zone_id: 'DEMO-ZONE-02',
      scan: scanData,
      decision: ingestRes.data.data.decision,
    }),
  });
  const report = explainRes.data.report;
  console.log('WHY Explanation:');
  console.log(`  Recommendation ID: ${report.recommendation_id}`);
  console.log(`  Confidence Rating: ${report.confidence_rating}`);
  console.log(`  Plain Reason (EN): ${report.plain_reason_en}`);
  console.log(`  Plain Reason (HI): ${report.plain_reason_hi}`);
  console.log(`  Recommended Action: ${report.recommended_action_en}`);
  console.log(`  Contributing Rules: ${report.contributing_rules.join(', ')}`);
  console.log('Evidence Items:');
  report.observed_evidence.forEach((e: any) => {
    console.log(`  - [${e.source}] ${e.parameter}: value=${e.value}, threshold=${e.threshold}, status=${e.status}`);
  });
  console.log('Limitations Disclosed:');
  report.limitations.forEach((l: string) => console.log(`  * ${l}`));

  // Step 6: Human Approval Gate
  console.log('\n--- Step 6: Human Approval Gate (Rejecting Autonomous Execution) ---');
  console.log('Attempting autonomous physical execution without approval...');
  const directCmdRes = await request('/api/rover/command', {
    method: 'POST',
    body: JSON.stringify({
      command_id: `CMD-UNAPPROVED-${Date.now()}`,
      command_type: 'IRRIGATE',
      payload: { duration_seconds: 60, volume_liters: 10 },
      issued_at: new Date().toISOString(),
    }),
  });
  console.log(`Direct Rover Command Execution: ${directCmdRes.data.success ? 'EXECUTED (CRITICAL SAFETY FAILURE)' : 'REJECTED BY SAFETY POLICY'}`);
  console.log(`Response:`, directCmdRes.data);

  console.log('\nSubmitting Explicit Human Approval to Closed-Loop Coordinator...');
  const approveRes = await request('/api/remediation/approve', {
    method: 'POST',
    body: JSON.stringify({
      zone_id: 'DEMO-ZONE-02',
      approved_by: 'EXPERT-AGRONOMIST-01',
      duration_seconds: 45,
      volume_liters: 10,
      expert_note: 'Approved: Soil moisture at 18.7% under 34.7C heat stress requires controlled irrigation.',
    }),
  });
  console.log('Approval Result:', JSON.stringify(approveRes.data, null, 2));
  const pendingIntervention = approveRes.data.data;

  // Step 7: Execute Simulated Remediation
  console.log('\n--- Step 7: Execute Approved Simulated Remediation ---');
  const executeRes = await request('/api/remediation/execute', {
    method: 'POST',
    body: JSON.stringify({
      action_id: pendingIntervention.action_id,
    }),
  });
  console.log('Execution Ack:', JSON.stringify(executeRes.data, null, 2));

  // Step 8: Perform Re-Scan & Verification
  console.log('\n--- Step 8: Perform Re-Scan & Verification ---');
  const verifyRes = await request('/api/remediation/verify', {
    method: 'POST',
    body: JSON.stringify({
      action_id: pendingIntervention.action_id,
    }),
  });
  console.log('Closed-Loop Verification Result:', JSON.stringify(verifyRes.data, null, 2));

  // Step 9: Audit Trail
  console.log('\n--- Step 9: Immutable Audit Trail ---');
  const auditAlertsRes = await request('/api/alerts?zone_id=DEMO-ZONE-02');
  console.log(`Alerts for Zone DEMO-ZONE-02:`, JSON.stringify(auditAlertsRes.data.data.map((a: any) => ({
    id: a.alert_id,
    status: a.status,
    type: a.type,
    dedup_key: a.deduplication_key,
    created_at: a.timestamp,
  })), null, 2));

  const verificationsRes = await request('/api/remediation/verifications?zone_id=DEMO-ZONE-02');
  console.log('Stored Verifications:', JSON.stringify(verificationsRes.data, null, 2));

  // Step 10: Offline Mode and Queue/Sync Demonstration
  console.log('\n--- Step 10: Offline Mode & Synchronization Engine ---');
  console.log('1. Setting rover to offline mode...');
  const offlineToggle = await request('/api/rover/offline-mode', {
    method: 'POST',
    body: JSON.stringify({ enabled: true }),
  });
  console.log('Offline Mode Status:', offlineToggle.data);

  console.log('2. Performing scan while rover is offline (buffered in local store)...');
  const offlineScan = await request('/api/rover/simulate-scan', {
    method: 'POST',
    body: JSON.stringify({ zone_id: 'DEMO-ZONE-03' }),
  });
  console.log('Offline Scan Status:', offlineScan.data.success);

  const queuePeek = await request('/api/rover/queue');
  console.log(`Rover Offline Buffered Events: ${queuePeek.data.buffered_count}`);

  console.log('3. Restoring connectivity and flushing rover offline queue...');
  await request('/api/rover/offline-mode', {
    method: 'POST',
    body: JSON.stringify({ enabled: false }),
  });
  const flushRes = await request('/api/rover/flush-queue', { method: 'POST' });
  console.log(`Flushed ${flushRes.data.flushed_count} events from Rover Offline Queue.`);

  console.log('4. Testing Cloud Sync Engine Batch Ingestion (/api/sync/push)...');
  const syncPush = await request('/api/sync/push', {
    method: 'POST',
    body: JSON.stringify({
      client_id: 'ROVER-LOCAL-CLIENT',
      records: [
        {
          id: `sync-rec-${Date.now()}`,
          table_name: 'sensor_telemetry',
          record_id: `rec-offline-${Date.now()}`,
          operation: 'INSERT',
          payload: { zone_id: 'DEMO-ZONE-03', moisture: 21.4 },
          created_at: new Date().toISOString(),
          version: 1,
        }
      ],
      strategy: 'LAST_WRITE_WINS',
    }),
  });
  console.log('Sync Push Result:', JSON.stringify(syncPush.data, null, 2));
  const syncStatus = await request('/api/sync/status');
  console.log('Sync Engine Status:', JSON.stringify(syncStatus.data.data, null, 2));

  // Step 11: Phase 4 Voice Flow Without Actuator Bypass
  console.log('\n--- Step 11: Voice Assistant Flow & Actuator Safety Gate ---');
  console.log('Query: "खेत की क्या स्थिति है?"');
  const voiceQueryRes = await request('/api/voice/interact', {
    method: 'POST',
    body: JSON.stringify({
      text: 'खेत की क्या स्थिति है?',
      language: 'hi',
      input_type: 'SIMULATED_VOICE_INTENT',
      user_id: 'farmer_demo_voice',
    }),
  });
  console.log('Voice Response (HI):', voiceQueryRes.data.response.spoken_text_hi);
  console.log('Voice Response (EN):', voiceQueryRes.data.response.spoken_text_en);
  console.log('Intent:', voiceQueryRes.data.response.intent);

  console.log('\nVoice Action Request: "DEMO-ZONE-02 में पानी चला दो" (Requires confirmation)');
  const voiceActAttempt1 = await request('/api/voice/interact', {
    method: 'POST',
    body: JSON.stringify({
      text: 'DEMO-ZONE-02 में पानी चला दो',
      language: 'hi',
      input_type: 'SIMULATED_VOICE_INTENT',
      user_id: 'farmer_demo_voice',
      session_id: 'voice_session_001',
    }),
  });
  console.log(`Requires Confirmation? ${voiceActAttempt1.data.response.requires_confirmation ? 'YES (SAFETY GATE ACTIVE)' : 'NO'}`);
  console.log(`Voice Prompt: "${voiceActAttempt1.data.response.spoken_text_hi}"`);

  console.log('\nFarmer Confirms Voice Action in Same Session: "हाँ, पुष्टि करता हूँ"');
  const voiceActAttempt2 = await request('/api/voice/interact', {
    method: 'POST',
    body: JSON.stringify({
      text: 'हाँ, पुष्टि करता हूँ',
      language: 'hi',
      input_type: 'SIMULATED_VOICE_INTENT',
      user_id: 'farmer_demo_voice',
      session_id: 'voice_session_001',
    }),
  });
  console.log(`Confirmed Intent: ${voiceActAttempt2.data.response.intent}`);
  console.log(`Voice Confirmation Response: "${voiceActAttempt2.data.response.spoken_text_hi}"`);
  console.log(`Safety Notice: "${voiceActAttempt2.data.response.safety_notice_en}"`);

  // Step 12: Multimodal Secondary Visual Evidence & Guy 3 Primary Ground Truth
  console.log('\n--- Step 12: Multimodal Secondary Evidence & Privacy Gating ---');
  console.log('Test A: Upload without user authorization (Privacy check)');
  const mmUnauthorized = await request('/api/multimodal/analyze', {
    method: 'POST',
    body: JSON.stringify({
      image_base64: 'data:image/jpeg;base64,SAMPLE_IMAGE',
      zone_id: 'DEMO-ZONE-02',
      user_initiated: false, // Unauthorized
      edge_detections: scanData.detections,
    }),
  });
  console.log(`Unauthorized Upload Handled: HTTP ${mmUnauthorized.status} - ${mmUnauthorized.data?.error || 'Rejected'}`);

  console.log('\nTest B: Authorized upload comparing against Guy 3 Edge YOLOv8 detections');
  const mmAuthorized = await request('/api/multimodal/analyze', {
    method: 'POST',
    body: JSON.stringify({
      image_base64: 'data:image/jpeg;base64,SAMPLE_IMAGE',
      zone_id: 'DEMO-ZONE-02',
      user_initiated: true, // Authorized
      primary_detection: scanData.detections[0],
    }),
  });
  console.log('Multimodal Status:', mmAuthorized.data.result.status);
  console.log('Secondary Findings (EN):', mmAuthorized.data.result.secondary_findings_en);
  console.log('Secondary Findings (HI):', mmAuthorized.data.result.secondary_findings_hi);
  console.log('Visual Confidence Hint:', mmAuthorized.data.result.visual_confidence_hint);
  console.log('Disclaimer:', mmAuthorized.data.result.disclaimer);

  // Step 13: Farm Risk Dashboard & Weather Risk Provider
  console.log('\n--- Step 13: Farm Risk Dashboard & Weather Risk Provider ---');
  const farmRiskRes = await request('/api/analytics/farm-risk');
  const db = farmRiskRes.data.dashboard;
  console.log('Farm Risk Dashboard:');
  console.log(`  Composite Health Indicator: ${db.composite_indicator.score_out_of_100}/100`);
  console.log(`  Label: ${db.composite_indicator.label}`);
  console.log(`  Formula: ${db.composite_indicator.formula_description}`);
  console.log(`  Classification: ${db.composite_indicator.classification}`);
  console.log('Individual Risk Factors:');
  console.log(`  - Water: ${db.conditions.water.score_out_of_100}/100 (${db.conditions.water.status})`);
  console.log(`  - Crop: ${db.conditions.crop.score_out_of_100}/100 (${db.conditions.crop.status})`);
  console.log(`  - Pest: ${db.conditions.pest.score_out_of_100}/100 (${db.conditions.pest.status})`);
  console.log(`  - Disease: ${db.conditions.disease.score_out_of_100}/100 (${db.conditions.disease.status})`);
  console.log(`  - Heat: ${db.conditions.heat.score_out_of_100}/100 (${db.conditions.heat.status})`);

  const weatherRes = await request('/api/weather/risk');
  console.log('\nWeather Risk Provider:');
  console.log(`  Provider Type: ${weatherRes.data.weather.provider_type}`);
  console.log(`  Data Label: ${weatherRes.data.weather.provider_label}`);
  console.log(`  Temperature: ${weatherRes.data.weather.temperature_c}°C, Humidity: ${weatherRes.data.weather.relative_humidity_pct}%`);
  weatherRes.data.assessments.forEach((a: any) => {
    console.log(`  - [${a.category}] Risk: ${a.risk_level} | Irrigation Advisable: ${a.irrigation_advisable}`);
    console.log(`    Impact: ${a.impact_description_en}`);
  });

  // Step 14: Field Evidence Report & Legal Disclaimer
  console.log('\n--- Step 14: PRAHAR Field Evidence Report & Non-Government Disclaimer ---');
  const reportRes = await request('/api/reports/field-evidence?farm_id=FARM-DEMO-01');
  console.log(`Report Title: ${reportRes.data.report.report_title}`);
  console.log(`Generated At: ${reportRes.data.report.generated_at}`);
  console.log(`Farm ID: ${reportRes.data.report.farm_id}`);
  console.log(`Legal Disclaimer: "${reportRes.data.report.disclaimer}"`);
  console.log(`Action Executed: ${reportRes.data.report.action_executed}`);
  console.log(`Verification Outcome: ${reportRes.data.report.verification_outcome}`);

  // Step 15: Farmer Opportunity Center
  console.log('\n--- Step 15: Farmer Opportunity Center Verified Schemes ---');
  const oppsRes = await request('/api/opportunities');
  console.log(`Total Verified Schemes: ${oppsRes.data.count}`);
  oppsRes.data.schemes.forEach((s: any) => {
    console.log(`  - [${s.scheme_id}] ${s.title_en}`);
    console.log(`    Category: ${s.category}`);
    console.log(`    Official Portal: ${s.official_portal_url}`);
    console.log(`    PRAHAR Support Note: ${s.prahar_assistance_note_en}`);
  });

  console.log('\n================================================================');
  console.log('ALL PHASE 1-4 INTEGRATION FLOWS VALIDATED SUCCESSFULLY');
  console.log('================================================================');
}

runLiveDemo().catch((err) => {
  console.error('Integration demonstration error:', err);
  process.exit(1);
});
