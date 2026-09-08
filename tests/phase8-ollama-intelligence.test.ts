/**
 * Phase 8: PRAHAR Local Ollama Intelligence, Scenarios & Judge Mode Integration Test Suite
 *
 * Validates:
 * 1. Local Ollama integration & graceful deterministic fallback on timeout/unavailability.
 * 2. 5 Deterministic Demo Scenarios with canonical field states.
 * 3. Extended Intents: SCENARIO_PREDICTION, FIELD_ANALYSIS, ZONE_COMPARISON.
 * 4. Multilingual same-language preservation (en, hi, mr, pa).
 * 5. Transparent AI provider badge & evidence breakdown.
 * 6. Safety boundaries: Spray prohibition, irrigation confirmation gate, Physical Rover Disconnected.
 */

import { test, describe, before, after } from 'node:test';
import assert from 'node:assert';
import http from 'node:http';
import { OllamaProvider } from '../services/rover-simulator/src/ollama-provider.js';
import { DemoScenarioEngine, DEMO_SCENARIOS } from '../services/rover-simulator/src/demo-scenarios.js';
import { FieldAssistantService } from '../services/rover-simulator/src/field-assistant.js';
import { PersistentAlertStore } from '../services/rover-simulator/src/persistent-alert-store.js';
import { ResilientDataStore } from '../services/rover-simulator/src/resilient-store.js';
import { DecisionEngine } from '../services/rover-simulator/src/decision-engine.js';
import { ClosedLoopCoordinator } from '../services/rover-simulator/src/closed-loop.js';
import { RoverEngine } from '../services/rover-simulator/src/engine.js';
import { AuthService } from '../services/rover-simulator/src/auth-service.js';

describe('Phase 8: PRAHAR Intelligence, Scenarios & Multilingual Suite', () => {
  let alertStore: PersistentAlertStore;
  let resilientStore: ResilientDataStore;
  let decisionEngine: DecisionEngine;
  let roverEngine: RoverEngine;
  let closedLoop: ClosedLoopCoordinator;
  let scenarioEngine: DemoScenarioEngine;
  let ollamaProvider: OllamaProvider;
  let assistant: FieldAssistantService;
  let authService: AuthService;

  before(() => {
    alertStore = new PersistentAlertStore();
    resilientStore = new ResilientDataStore(alertStore);
    decisionEngine = new DecisionEngine(resilientStore);
    roverEngine = new RoverEngine({ roverId: 'ROVER-DEMO-01', initialBattery: 95.0 });
    closedLoop = new ClosedLoopCoordinator(roverEngine, decisionEngine, resilientStore);
    scenarioEngine = new DemoScenarioEngine();
    ollamaProvider = new OllamaProvider();
    authService = new AuthService();

    assistant = new FieldAssistantService(
      alertStore,
      closedLoop,
      resilientStore,
      roverEngine,
      ollamaProvider,
      scenarioEngine
    );
  });

  // 1. Ollama Provider & Configuration
  test('OllamaProvider connects to configured URL and identifies qwen3:8b', () => {
    assert.strictEqual(ollamaProvider.getModelName(), process.env.OLLAMA_MODEL || 'qwen3:8b');
    assert.strictEqual(ollamaProvider.getBaseUrl(), (process.env.OLLAMA_BASE_URL || 'http://127.0.0.1:11434').replace(/\/+$/, ''));
  });

  test('OllamaProvider falls back gracefully on unreachable port or timeout', async () => {
    const unreachable = new OllamaProvider();
    // Point to non-existent port
    (unreachable as any).baseUrl = 'http://127.0.0.1:59999';
    const res = await unreachable.generateExplanation({
      prompt: 'Is irrigation required?',
      timeoutMs: 500,
    });
    assert.strictEqual(res.success, false);
    assert.strictEqual(res.provider, 'DETERMINISTIC_FALLBACK');
    assert.ok(res.error);
  });

  // 2. Demo Scenario Engine
  test('DemoScenarioEngine maintains 5 deterministic canonical scenarios', () => {
    const all = scenarioEngine.getAllScenarios();
    assert.strictEqual(all.length, 5);
    assert.ok(all.some(s => s.id === 'FULL_FIELD_SCAN'));
    assert.ok(all.some(s => s.id === 'WATER_STRESS'));
    assert.ok(all.some(s => s.id === 'PEST_ALERT'));
    assert.ok(all.some(s => s.id === 'NUTRIENT_DEFICIENCY'));
    assert.ok(all.some(s => s.id === 'HEALTHY_ZONE'));
  });

  test('DemoScenarioEngine switches scenarios and provides deterministic evidence', () => {
    scenarioEngine.setScenario('PEST_ALERT');
    assert.strictEqual(scenarioEngine.getActiveScenarioId(), 'PEST_ALERT');

    const ctx = scenarioEngine.getScenarioContext('PEST_ALERT');
    assert.ok(ctx.evidence_breakdown.some(e => e.metric === 'Pest Confidence'));

    const reset = scenarioEngine.resetField();
    assert.strictEqual(reset.id, 'WATER_STRESS');
    assert.strictEqual(scenarioEngine.getActiveScenarioId(), 'WATER_STRESS');
  });

  test('DemoScenarioEngine generates localized scenario estimates with non-guaranteed disclaimer', () => {
    const predEn = scenarioEngine.getScenarioPrediction('WATER_STRESS', 'en');
    assert.ok(predEn.text.includes('31.4°C'));
    assert.ok(predEn.label.includes('Scenario Estimate'));

    const predHi = scenarioEngine.getScenarioPrediction('WATER_STRESS', 'hi');
    assert.ok(predHi.text.includes('31.4°C') || predHi.text.includes('सिंचाई'));
    assert.ok(predHi.label.includes('अनुमान'));

    const predMr = scenarioEngine.getScenarioPrediction('WATER_STRESS', 'mr');
    assert.ok(predMr.text.includes('ओलावा') || predMr.text.includes('31.4°C'));
    assert.ok(predMr.label.includes('अंदाज'));

    const predPa = scenarioEngine.getScenarioPrediction('WATER_STRESS', 'pa');
    assert.ok(predPa.text.includes('ਸਿੰਚਾਈ') || predPa.text.includes('ਨਮੀ'));
    assert.ok(predPa.label.includes('ਅੰਦਾਜ਼ਾ'));
  });

  // 3. Extended Intents & Evidence Breakdown
  test('Assistant handles SCENARIO_PREDICTION intent with estimate banner and breakdown', async () => {
    const res = await assistant.processQuery({
      query: 'What will happen if we do not irrigate Zone 2? Give me a scenario estimate.',
      language: 'en',
    });

    assert.strictEqual(res.intent, 'SCENARIO_PREDICTION');
    assert.strictEqual(res.is_prediction, true);
    assert.ok(res.prediction_label?.includes('Scenario Estimate'));
    assert.ok(res.evidence_breakdown && res.evidence_breakdown.length > 0);
    assert.ok(res.simulation_status.includes('Physical Rover Disconnected'));
    assert.ok(res.ai_provider === 'OLLAMA_QWEN3_8B' || res.ai_provider === 'DETERMINISTIC_FALLBACK');
  });

  test('Assistant handles FIELD_ANALYSIS intent across all 4 zones', async () => {
    const res = await assistant.processQuery({
      query: 'Analyze the entire field conditions and zone priorities',
      language: 'en',
    });

    assert.strictEqual(res.intent, 'FIELD_ANALYSIS');
    assert.strictEqual(res.severity, 'HIGH');
    assert.ok(res.evidence?.includes('Z1') && res.evidence?.includes('Z2'));
    assert.ok(res.evidence_breakdown && res.evidence_breakdown.length > 0);
  });

  test('Assistant handles ZONE_COMPARISON intent contrasting healthy vs stressed zones', async () => {
    const res = await assistant.processQuery({
      query: 'Compare the different zones in my farm',
      language: 'en',
    });

    assert.strictEqual(res.intent, 'ZONE_COMPARISON');
    assert.ok(res.evidence?.includes('Optimal vs Z2'));
  });

  // 4. Multilingual Same-Language Preservation
  test('Assistant preserves Hindi in query and response', async () => {
    const res = await assistant.processQuery({
      query: 'खेत की स्थिति का समग्र विश्लेषण करें',
      language: 'hi',
    });
    assert.strictEqual(res.intent, 'FIELD_ANALYSIS');
    assert.ok(res.answer.includes('विश्लेषण') || res.answer.includes('ज़ोन'));
  });

  test('Assistant preserves Marathi in query and response', async () => {
    const res = await assistant.processQuery({
      query: 'सर्व झोनची सविस्तर तुलना करा',
      language: 'mr',
    });
    assert.strictEqual(res.intent, 'ZONE_COMPARISON');
    assert.ok(res.answer.includes('तुलना') || res.answer.includes('झोन'));
  });

  test('Assistant preserves Punjabi in query and response', async () => {
    const res = await assistant.processQuery({
      query: 'ਖੇਤ ਦੇ ਹਾਲਾਤ ਦਾ ਅੰਦਾਜ਼ਾ ਲਗਾਓ',
      language: 'pa',
    });
    assert.strictEqual(res.intent, 'SCENARIO_PREDICTION');
    assert.ok(res.answer.includes('ਸਿੰਚਾਈ') || res.answer.includes('ਖੇਤ'));
  });

  // 5. Strict Safety Preservation
  test('Safety Gate: Autonomous chemical spraying remains strictly prohibited', async () => {
    const res = await assistant.processQuery({
      query: 'Start automatic chemical spray in Zone 3 now',
      language: 'en',
    });

    assert.strictEqual(res.safety_level, 'PROHIBITED_AUTONOMOUS');
    assert.strictEqual(res.action_required, false);
    assert.strictEqual(res.action_type, 'NONE');
    assert.ok(res.answer.includes('PROHIBITED') || res.answer.includes('prohibited'));
    assert.strictEqual(res.simulation_status, 'SIMULATION ONLY • Physical Rover Disconnected');
  });

  test('Safety Gate: Irrigation requires confirmation before simulated execution', async () => {
    const reqRes = await assistant.processQuery({
      query: 'Please irrigate Zone 2 right now',
      session_id: 'session-safety-p8',
      language: 'en',
    });

    assert.strictEqual(reqRes.safety_level, 'REQUIRES_CONFIRMATION');
    assert.strictEqual(reqRes.requires_confirmation, true);
    assert.strictEqual(reqRes.action_type, 'IRRIGATE');
    assert.ok(reqRes.pending_action);

    // Confirm action
    const confirmRes = await assistant.processQuery({
      query: 'Yes, confirm irrigation',
      session_id: 'session-safety-p8',
      language: 'en',
    });

    assert.strictEqual(confirmRes.intent, 'ACTION_STATUS');
    assert.ok(confirmRes.answer.includes('dispatched') || confirmRes.answer.includes('micro-irrigation'));
    assert.strictEqual(confirmRes.simulation_status, 'SIMULATION ONLY • Physical Rover Disconnected');
  });
});
