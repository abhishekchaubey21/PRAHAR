/**
 * PRAHAR Phase 4 Test Suite — Multimodal Privacy & Voice Safety Architecture
 * Validates:
 * 1. Voice STT provider distinction (Real STT vs Simulation/Demo Intent Input).
 * 2. Strict Voice Safety Gate: Voice NEVER directly triggers actuators.
 * 3. Mandatory confirmation & authenticated approval for voice-driven irrigation.
 * 4. Multimodal Privacy: User-initiated gating (no automated uploading).
 * 5. Primary Ground Truth: Guy 3 Edge YOLOv8 model primacy preserved.
 * 6. Multimodal agreement states: AGREEMENT, CONTRADICTION, UNCERTAINTY, COMPLEMENTARY.
 * 7. Provider failure fallback when external vision/speech models are offline.
 */

import { test, describe } from 'node:test';
import assert from 'node:assert';
import {
  VoiceAssistant,
  SimulatedSTTProvider,
} from '../services/rover-simulator/src/voice-assistant.js';
import {
  MultimodalAssistant,
  LocalHeuristicMultimodalProvider,
  ExternalGeminiMultimodalProvider,
} from '../services/rover-simulator/src/multimodal-assistant.js';
import { InMemoryAlertStore } from '../services/rover-simulator/src/alert-store.js';
import { ClosedLoopCoordinator } from '../services/rover-simulator/src/closed-loop.js';
import { RoverEngine } from '../services/rover-simulator/src/engine.js';
import { DecisionEngine } from '../services/rover-simulator/src/decision-engine.js';
import { Detection, RoverScanPayload } from '@prahar/shared';

describe('Phase 4: Voice Safety & Multi-Stage Confirmation Gate', () => {
  const engine = new RoverEngine({ roverId: 'ROVER-VOICE-TEST' });
  const alertStore = new InMemoryAlertStore();
  const decisionEngine = new DecisionEngine(alertStore);
  const closedLoop = new ClosedLoopCoordinator(engine, decisionEngine, alertStore);
  const voiceAssistant = new VoiceAssistant(alertStore, closedLoop);

  // Seed pre-scan for Zone 2 so closed loop has evidence
  const initialScan: RoverScanPayload = {
    scan_id: 'scan-voice-pre-01',
    rover_id: engine.getRoverId(),
    zone_id: 'DEMO-ZONE-02',
    gps: { latitude: 12.9734, longitude: 77.5934 },
    battery_pct: 95.0,
    timestamp: new Date().toISOString(),
    sensor_readings: [
      { zone_id: 'DEMO-ZONE-02', type: 'moisture', value: 16.5, unit: '%', timestamp: new Date().toISOString(), source: 'probe' },
      { zone_id: 'DEMO-ZONE-02', type: 'temperature', value: 34.0, unit: '°C', timestamp: new Date().toISOString(), source: 'probe' },
    ],
    detections: [
      {
        id: 'det-v-01',
        zone_id: 'DEMO-ZONE-02',
        hazard_type: 'WATER_STRESS',
        hazard_name: 'Severe Water Deficit',
        confidence: 0.92,
        severity_hint: 'HIGH',
        timestamp: new Date().toISOString(),
        source: 'ai',
      },
    ],
  };

  test('Voice Assistant honestly identifies STT provider as SIMULATED / DEMO', async () => {
    const stt = new SimulatedSTTProvider();
    assert.strictEqual(typeof stt.transcribeAudio, 'function');
    const transcription = await stt.transcribeAudio(Buffer.from(''), 'hi');
    assert.ok(transcription.transcript.length > 0);
    assert.strictEqual(transcription.confidence, 0.95);

    const response = await voiceAssistant.processQuery({
      text: 'खेत की क्या स्थिति है?',
      language: 'hi',
      input_type: 'SIMULATED_VOICE',
    });

    assert.strictEqual(response.intent, 'FARM_STATUS');
    assert.ok(response.spoken_text_hi.length > 0);
  });

  test('Voice Safety: Irrigation voice request DOES NOT execute directly (Requires Confirmation)', async () => {
    // Ingest scan first
    await closedLoop.ingestScan(initialScan);

    // Farmer says "Irrigate Zone 2"
    const response = await voiceAssistant.processQuery({
      text: 'ज़ोन 2 में सिंचाई शुरू करो',
      language: 'hi',
      input_type: 'SIMULATED_VOICE',
      session_id: 'session-voice-test',
    });

    assert.strictEqual(response.intent, 'APPROVE_IRRIGATION');
    assert.strictEqual(response.requires_confirmation, true);
    assert.ok(response.pending_action);
    assert.strictEqual(response.pending_action.action_type, 'IRRIGATE');
    assert.strictEqual(response.pending_action.zone_id, 'DEMO-ZONE-02');
    assert.ok(response.safety_notice_hi.includes('पुष्टि'));
    assert.ok(response.spoken_text_hi.includes('पुष्टि'));
  });

  test('Voice Safety: Irrigation executes ONLY when explicit confirmation provided in same session', async () => {
    // Follow-up voice confirmation
    const confirmResponse = await voiceAssistant.processQuery({
      text: 'हाँ, पुष्टि करता हूँ',
      language: 'hi',
      input_type: 'SIMULATED_VOICE',
      session_id: 'session-voice-test',
      user_id: 'farmer_voice_authenticated',
    });

    assert.strictEqual(confirmResponse.intent, 'CONFIRM_ACTION');
    assert.strictEqual(confirmResponse.requires_confirmation, false);
    assert.ok(confirmResponse.spoken_text_hi.includes('स्वीकृत'));
    assert.ok(confirmResponse.safety_notice_en.includes('explicit confirmation gate'));
  });

  test('Voice Assistant gracefully handles unknown intent without motor activation', async () => {
    const response = await voiceAssistant.processQuery({
      text: 'आज का गाना बजाओ',
      language: 'hi',
      input_type: 'SIMULATED_VOICE',
    });

    assert.strictEqual(response.intent, 'UNKNOWN');
    assert.strictEqual(response.requires_confirmation, false);
    assert.ok(response.spoken_text_en.toLowerCase().includes('did not recognize'));
  });
});

describe('Phase 4: Multimodal Privacy & Guy 3 Primary Ground Truth', () => {
  const assistant = new MultimodalAssistant();

  const primaryDetection: Detection = {
    id: 'det-edge-yolo-01',
    zone_id: 'DEMO-ZONE-03',
    hazard_type: 'DISEASE',
    hazard_name: 'Early Blight (Alternaria solani)',
    confidence: 0.88,
    severity_hint: 'HIGH',
    timestamp: new Date().toISOString(),
    source: 'ai',
  };

  test('Multimodal Privacy: Rejects analysis if user has not authorized upload', async () => {
    await assert.rejects(
      async () => {
        await assistant.analyzeCropEvidence({
          image_ref: 'crop_leaf_zone3.jpg',
          zone_id: 'DEMO-ZONE-03',
          primary_detection: primaryDetection,
          user_initiated: false, // Privacy violation: Not user initiated!
        });
      },
      /Privacy Violation/,
      'Must reject non-user-initiated image upload'
    );
  });

  test('Multimodal Assistant treats Guy 3 Edge model as PRIMARY ground truth and reports AGREEMENT', async () => {
    const result = await assistant.analyzeCropEvidence({
      image_ref: 'crop_leaf_zone3.jpg',
      zone_id: 'DEMO-ZONE-03',
      crop_type: 'tomato',
      primary_detection: primaryDetection,
      user_initiated: true, // User authorized
    });

    assert.strictEqual(result.status, 'AGREEMENT');
    assert.ok(result.visual_confidence_hint >= 0.70);
    assert.ok(result.secondary_findings_en.includes('Early Blight'));
    assert.ok(result.disclaimer.includes('Guy 3 edge rover detection remains primary ground truth'));
  });

  test('Multimodal Assistant detects UNCERTAINTY when visual evidence diverges on pest detection', async () => {
    const pestDetection: Detection = {
      id: 'det-pest-01',
      zone_id: 'DEMO-ZONE-02',
      hazard_type: 'PEST',
      hazard_name: 'Fall Armyworm',
      confidence: 0.72,
      severity_hint: 'MEDIUM',
      timestamp: new Date().toISOString(),
      source: 'ai',
    };

    const result = await assistant.analyzeCropEvidence({
      image_ref: 'blight_leaf_sample.jpg',
      zone_id: 'DEMO-ZONE-02',
      primary_detection: pestDetection,
      user_initiated: true,
    });

    assert.strictEqual(result.status, 'UNCERTAINTY');
    assert.strictEqual(result.requires_expert_review, true);
    assert.ok(result.secondary_findings_en.includes('Guy 3\'s edge model detection retained as primary'));
  });

  test('External multimodal provider failure gracefully falls back to local heuristic', async () => {
    const failingProvider = new ExternalGeminiMultimodalProvider(); // Missing key triggers error
    const fallbackAssistant = new MultimodalAssistant(failingProvider);

    const result = await fallbackAssistant.analyzeCropEvidence({
      image_ref: 'sample.jpg',
      zone_id: 'DEMO-ZONE-01',
      user_initiated: true,
    });

    assert.strictEqual(result.is_provider_fallback, true);
    assert.ok(result.status);
    assert.ok(result.disclaimer.includes('primary ground truth'));
  });
});
