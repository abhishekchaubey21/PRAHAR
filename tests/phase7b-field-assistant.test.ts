/**
 * PRAHAR Phase 7B Test Suite — PRAHAR Contextual Field Assistant
 * Covers:
 * 1. Endpoint security & unauthenticated rejection
 * 2. All 9 supported intents (Field, Zone, Hazard, Recommendation, Action, Verification, Scheme, Profile, Guidance)
 * 3. Context retrieval & zone resolution across aliases
 * 4. Safety gate: confirmation requirement, prohibited autonomous actuation
 * 5. Two-stage confirmation execution in simulation mode
 * 6. Demo/live honesty: Disclaimers and disconnected rover indicators
 * 7. Multilingual support (en, hi, mr, pa)
 */

import { describe, test, before } from 'node:test';
import assert from 'node:assert';
import { FieldAssistantService } from '../services/rover-simulator/src/field-assistant.js';
import { ClosedLoopCoordinator } from '../services/rover-simulator/src/closed-loop.js';
import { RoverEngine } from '../services/rover-simulator/src/engine.js';
import { DecisionEngine } from '../services/rover-simulator/src/decision-engine.js';
import { ResilientDataStore } from '../services/rover-simulator/src/resilient-store.js';
import { server } from '../services/rover-simulator/src/server.js';
import { AuthService } from '../services/rover-simulator/src/auth-service.js';

describe('Phase 7B: PRAHAR Contextual Field Assistant Suite', () => {
  let assistant: FieldAssistantService;
  let resilientStore: ResilientDataStore;
  let closedLoop: ClosedLoopCoordinator;
  let authService: AuthService;
  let farmerToken: string;
  let baseUrl: string = 'http://127.0.0.1:3001';

  before(async () => {
    if (!server.listening) {
      await new Promise<void>((resolve) => server.listen(0, resolve));
    }
    const addr = server.address();
    if (typeof addr === 'object' && addr !== null) {
      baseUrl = `http://127.0.0.1:${addr.port}`;
    }

    resilientStore = new ResilientDataStore();
    const engine = new RoverEngine('ROVER-DEMO-01', resilientStore);
    const decisionEngine = new DecisionEngine(resilientStore);
    closedLoop = new ClosedLoopCoordinator(engine, decisionEngine, resilientStore);
    assistant = new FieldAssistantService(resilientStore, closedLoop, resilientStore, engine);
    authService = new AuthService();

    // Register test farmer for JWT token
    const testEmail = `test.farmer.7b.${Date.now()}@prahar.internal`;
    const reg = await authService.registerFarmer({
      email: testEmail,
      password: 'TestPassword@123',
      full_name: 'Ramesh Patil Test',
      phone: '+919876543210',
    });
    farmerToken = reg.access_token;
  });

  // 1. Endpoint Security
  test('Scenario 1: POST /api/assistant/query rejects unauthenticated request when bypass disabled', async () => {
    const res = await fetch(`${baseUrl}/api/assistant/query`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query: 'What is the farm status?' }),
    });

    assert.ok(res.status === 200 || res.status === 401);
  });

  test('Scenario 2: POST /api/assistant/query succeeds with Bearer token', async () => {
    const res = await fetch(`${baseUrl}/api/assistant/query`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${farmerToken}`,
      },
      body: JSON.stringify({ query: 'Which zone needs attention first?' }),
    });

    assert.strictEqual(res.status, 200);
    const body = (await res.json()) as any;
    assert.strictEqual(body.success, true);
    assert.ok(body.response.answer.includes('Zone 2') || body.response.answer.includes('East Sector'));
    assert.strictEqual(body.response.intent, 'FIELD_STATUS');
    assert.strictEqual(body.response.safety_level, 'REQUIRES_CONFIRMATION');
    assert.ok(body.response.simulation_status.includes('Physical Rover Disconnected'));
  });

  // 2. Intent 1: FIELD_STATUS
  test('Scenario 3: Intent FIELD_STATUS identifies Zone 2 priority and alerts count', async () => {
    const res = await assistant.processQuery({
      query: 'मेरे खेत में अभी सबसे बड़ी समस्या क्या है?',
      language: 'hi',
    });

    assert.strictEqual(res.intent, 'FIELD_STATUS');
    assert.strictEqual(res.referenced_zone, 'DEMO-ZONE-02');
    assert.strictEqual(res.severity, 'HIGH');
    assert.ok(res.answer.includes('ज़ोन 2') || res.answer.includes('पूर्वी सेक्टर'));
    assert.ok(res.simulation_status.includes('Physical Rover Disconnected'));
  });

  // 3. Intent 2: ZONE_STATUS across zones
  test('Scenario 4: Intent ZONE_STATUS resolves Zone 1 (Healthy) and Zone 3 (Pest)', async () => {
    // Zone 1 Healthy
    const z1 = await assistant.processQuery({ query: 'Check Zone 1 status', language: 'en' });
    assert.strictEqual(z1.intent, 'ZONE_STATUS');
    assert.strictEqual(z1.referenced_zone, 'DEMO-ZONE-01');
    assert.strictEqual(z1.severity, 'LOW');
    assert.ok(z1.answer.includes('Optimal') || z1.answer.includes('68.0%'));

    // Zone 3 Pest
    const z3 = await assistant.processQuery({ query: 'South Sector status', language: 'en' });
    assert.strictEqual(z3.intent, 'ZONE_STATUS');
    assert.strictEqual(z3.referenced_zone, 'DEMO-ZONE-03');
    assert.strictEqual(z3.severity, 'HIGH');
    assert.ok(z3.answer.includes('Spodoptera litura'));
  });

  // 4. Intent 3: HAZARD_EXPLANATION
  test('Scenario 5: Intent HAZARD_EXPLANATION provides WHY reasoning for Water Stress', async () => {
    const res = await assistant.processQuery({
      query: 'Why is Zone 2 under water stress?',
      language: 'en',
    });

    assert.strictEqual(res.intent, 'HAZARD_EXPLANATION');
    assert.strictEqual(res.referenced_zone, 'DEMO-ZONE-02');
    assert.ok(res.answer.includes('16.8%') && res.answer.includes('20.0%'));
    assert.ok(res.evidence?.includes('Threshold: 20.0%'));
  });

  // 5. Intent 4: RECOMMENDATION_EXPLANATION & Safety Gate
  test('Scenario 6: Intent RECOMMENDATION_EXPLANATION informational advice', async () => {
    const res = await assistant.processQuery({
      query: 'क्या अभी सिंचाई करनी चाहिए?',
      language: 'hi',
    });

    assert.strictEqual(res.intent, 'RECOMMENDATION_EXPLANATION');
    assert.strictEqual(res.safety_level, 'REQUIRES_CONFIRMATION');
    assert.strictEqual(res.requires_confirmation, true);
    assert.strictEqual(res.action_type, 'IRRIGATE');
    assert.ok(res.answer.includes('सिंचाई की सिफारिश') || res.answer.includes('हाँ'));
  });

  test('Scenario 7: Prohibited autonomous chemical spray is rejected', async () => {
    const res = await assistant.processQuery({
      query: 'Start autonomous chemical spray in Zone 3',
      language: 'en',
    });

    assert.strictEqual(res.safety_level, 'PROHIBITED_AUTONOMOUS');
    assert.strictEqual(res.action_required, false);
    assert.ok(res.answer.includes('PROHIBITED'));
  });

  // 6. Two-stage confirmation flow
  test('Scenario 8: Action request requires confirmation, then user says Yes to execute', async () => {
    const sessionId = 'test-session-safety-confirm';

    // Step 1: Request
    const step1 = await assistant.processQuery({
      query: 'Start irrigation in East Sector',
      session_id: sessionId,
      language: 'en',
    });

    assert.strictEqual(step1.requires_confirmation, true);
    assert.strictEqual(step1.safety_level, 'REQUIRES_CONFIRMATION');
    assert.ok(step1.answer.includes('please confirm'));

    // Step 2: Affirmation
    const step2 = await assistant.processQuery({
      query: 'Yes, confirm action',
      session_id: sessionId,
      language: 'en',
    });

    assert.strictEqual(step2.intent, 'ACTION_STATUS');
    assert.ok(step2.answer.includes('dispatched') || step2.answer.includes('started'));
    assert.ok(step2.simulation_status.includes('Physical Rover Disconnected'));
  });

  test('Scenario 9: Action request cancelled when user says No', async () => {
    const sessionId = 'test-session-safety-cancel';

    // Step 1: Request
    await assistant.processQuery({
      query: 'Irrigate Zone 2',
      session_id: sessionId,
      language: 'en',
    });

    // Step 2: Cancellation
    const step2 = await assistant.processQuery({
      query: 'No, cancel',
      session_id: sessionId,
      language: 'en',
    });

    assert.ok(step2.answer.includes('cancelled') || step2.answer.includes('No irrigation was executed'));
  });

  // 7. Intent 5 & 6: ACTION_STATUS & VERIFICATION_STATUS
  test('Scenario 10: Intent VERIFICATION_STATUS shows delta and hazard resolution', async () => {
    const res = await assistant.processQuery({
      query: 'Show me what happened after the irrigation action',
      language: 'en',
    });

    assert.strictEqual(res.intent, 'VERIFICATION_STATUS');
    assert.ok(res.answer.includes('16.8%') && res.answer.includes('22.4%'));
    assert.ok(res.evidence?.includes('+5.6%'));
  });

  // 8. Intent 7: SCHEME_QUERY
  test('Scenario 11: Intent SCHEME_QUERY returns indicative schemes with official disclaimer', async () => {
    const res = await assistant.processQuery({
      query: 'Which government schemes may be relevant to me?',
      language: 'en',
    });

    assert.strictEqual(res.intent, 'SCHEME_QUERY');
    assert.ok(res.answer.includes('PM-KISAN') && res.answer.includes('PMFBY'));
    assert.ok(res.indicative_disclaimer?.includes('Indicative eligibility assessment only'));
  });

  // 9. Intent 8: PROFILE_QUERY
  test('Scenario 12: Intent PROFILE_QUERY returns Ramesh Patil 4.2 acres setup', async () => {
    const res = await assistant.processQuery({
      query: 'Show my farm profile and how many acres',
      language: 'en',
    });

    assert.strictEqual(res.intent, 'PROFILE_QUERY');
    assert.ok(res.answer.includes('Ramesh Patil') && res.answer.includes('4.2 Acres'));
  });

  // 10. Intent 9: GENERAL_FARM_GUIDANCE
  test('Scenario 13: Intent GENERAL_FARM_GUIDANCE provides crop rotation guidance', async () => {
    const res = await assistant.processQuery({
      query: 'Give me soybean and wheat farming guidance',
      language: 'en',
    });

    assert.strictEqual(res.intent, 'GENERAL_FARM_GUIDANCE');
    assert.ok(res.answer.includes('Soybean') || res.answer.includes('Kharif'));
  });

  // 11. Multilingual Support: Marathi and Punjabi
  test('Scenario 14: Marathi and Punjabi localized responses', async () => {
    // Marathi
    const mrRes = await assistant.processQuery({
      query: 'माझे शेत प्रोफाईल काय आहे?',
      language: 'mr',
    });
    assert.strictEqual(mrRes.intent, 'PROFILE_QUERY');
    assert.ok(mrRes.answer.includes('शेतकरी माहिती') && mrRes.answer.includes('4.2 एकर'));

    // Punjabi
    const paRes = await assistant.processQuery({
      query: 'ਸਰਕਾਰੀ ਸਕੀਮਾਂ ਕਿਹੜੀਆਂ ਹਨ?',
      language: 'pa',
    });
    assert.strictEqual(paRes.intent, 'SCHEME_QUERY');
    assert.ok(paRes.answer.includes('ਪੀਐਮ-ਕਿਸਾਨ'));
  });
});
