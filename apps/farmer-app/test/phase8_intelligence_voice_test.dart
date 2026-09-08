import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/auth_service.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/data/providers/demo_scenarios_provider.dart';
import 'package:farmer_app/data/repositories/field_assistant_repository.dart';
import 'package:farmer_app/domain/assistant_model.dart';
import 'package:farmer_app/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MockClient createMockPhase8Gateway({
    Future<http.Response> Function(http.Request)? customHandler,
  }) {
    return MockClient((request) async {
      if (customHandler != null) {
        final res = await customHandler(request);
        if (res.statusCode != 404) return res;
      }

      if (request.url.path == '/api/scenarios') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'active_scenario_id': 'WATER_STRESS',
              'scenarios': [
                {
                  'id': 'FULL_FIELD_SCAN',
                  'name': 'Full Field Comprehensive Scan',
                  'name_hi': 'पूर्ण खेत व्यापक स्कैन',
                  'name_mr': 'संपूर्ण शेत सर्वसमावेशक स्कॅन',
                  'name_pa': 'ਪੂਰੇ ਖੇਤ ਦੀ ਵਿਆਪਕ ਜਾਂਚ',
                  'description': 'Multi-zone scan across all 4 sectors.',
                  'target_zone_id': 'DEMO-ZONE-02',
                  'starting_status': 'EVALUATING',
                  'recommendation': 'Target Zone 2 micro-irrigation.',
                  'expected_improvement': 'Moisture increases from 16.8% to 28.5%.',
                },
                {
                  'id': 'WATER_STRESS',
                  'name': 'Zone 2 Acute Water Stress',
                  'name_hi': 'ज़ोन 2 गंभीर जल तनाव',
                  'name_mr': 'झोन 2 तीव्र पाण्याचा ताण',
                  'name_pa': 'ਜ਼ੋਨ 2 ਗੰਭੀਰ ਪਾਣੀ ਦੀ ਕਮੀ',
                  'description': 'East Sector exhibits critical soil moisture drop (16.8%).',
                  'target_zone_id': 'DEMO-ZONE-02',
                  'starting_status': 'WATER_STRESS',
                  'recommendation': 'Trigger micro-irrigation cycle.',
                  'expected_improvement': 'Moisture rises above 25.0%.',
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/scenarios/select') {
        return http.Response(
          jsonEncode({'success': true, 'active_scenario_id': 'FULL_FIELD_SCAN'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/scenarios/reset') {
        return http.Response(
          jsonEncode({'success': true, 'message': 'Demo state reset successfully'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/farms') {
        return http.Response(
          jsonEncode({'success': true, 'farms': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/zones') {
        return http.Response(
          jsonEncode({'success': true, 'zones': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/alerts') {
        return http.Response(
          jsonEncode({'success': true, 'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/remediation/verify' || request.url.path == '/api/remediation/verifications') {
        return http.Response(
          jsonEncode({'success': true, 'data': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/opportunities') {
        return http.Response(
          jsonEncode({'success': true, 'opportunities': []}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/assistant/query') {
        return http.Response(
          jsonEncode({
            'success': true,
            'response': {
              'intent': 'SCENARIO_PREDICTION',
              'answer': 'PRAHAR Predictive Scenario Estimate: If Zone 2 remains untreated, moisture drops to 12%.',
              'referenced_zone': 'DEMO-ZONE-02',
              'severity': 'HIGH',
              'recommendation': 'Trigger micro-irrigation cycle.',
              'requires_confirmation': true,
              'safety_level': 'REQUIRES_CONFIRMATION',
              'simulation_status': 'SIMULATION ONLY • Physical Rover Disconnected',
              'indicative_disclaimer': 'Physical Rover: Disconnected (Simulation Only)',
              'ai_provider': 'OLLAMA_QWEN3_8B',
              'is_prediction': true,
              'prediction_label': 'PRAHAR Scenario Estimate • Indicative Simulation',
              'evidence_breakdown': [
                {
                  'metric': 'Soil Moisture',
                  'observed': '16.8%',
                  'threshold': '< 20.0%',
                  'status': 'CRITICAL',
                },
                {
                  'metric': 'Canopy Temperature',
                  'observed': '34.5°C',
                  'threshold': '> 32.0°C',
                  'status': 'ELEVATED',
                }
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    });
  }

  Future<void> saveTestSession(ISessionStore store) async {
    await store.saveSession(
      accessToken: 'jwt-phase8-test-token',
      refreshToken: 'rf-phase8-token',
      user: const FarmerUser(
        id: 'farmer-phase8-1',
        email: 'ramesh.patil@prahar.org',
        role: 'FARMER',
        fullName: 'Ramesh Patil',
      ),
    );
  }

  group('Phase 8: DemoScenariosProvider Unit Tests', () {
    test('fetches scenarios and updates active scenario', () async {
      final mockClient = createMockPhase8Gateway();
      final provider = DemoScenariosProvider(client: mockClient, baseUrl: 'http://127.0.0.1:3001');

      await provider.fetchScenarios();

      expect(provider.scenarios.length, 2);
      expect(provider.activeScenarioId, DemoScenarioId.waterStress);
      expect(provider.activeScenario.name, contains('Zone 2 Acute Water Stress'));

      await provider.selectScenario(DemoScenarioId.fullFieldScan);
      expect(provider.activeScenarioId, DemoScenarioId.fullFieldScan);

      await provider.resetFieldState();
      expect(provider.activeScenarioId, DemoScenarioId.waterStress);
    });
  });

  group('Phase 8: Home Screen Scenario Selector and Judge Mode Integration Tests', () {
    testWidgets('Renders scenario selector card, chips, reset button, and judge mode card', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);

      final mockClient = createMockPhase8Gateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final scenariosProvider = DemoScenariosProvider(client: mockClient, baseUrl: 'http://127.0.0.1:3001');

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          demoScenariosProvider: scenariosProvider,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Verify Scenario Selector Card and Reset Button exist
      expect(find.byKey(const Key('demo_scenario_selector_card')), findsOneWidget);
      expect(find.byKey(const Key('reset_scenario_button')), findsOneWidget);

      // 2. Tap reset button
      await tester.tap(find.byKey(const Key('reset_scenario_button')));
      await tester.pumpAndSettle();

      // 3. Verify Judge Mode Entry Card exists
      expect(find.byKey(const Key('judge_mode_entry_card')), findsOneWidget);
      final judgeButton = find.byKey(const Key('open_judge_mode_button'));
      expect(judgeButton, findsOneWidget);

      // 4. Tap Judge Mode Entry button to open Judge Mode Sheet
      await tester.tap(judgeButton);
      await tester.pumpAndSettle();

      // 5. Verify Judge Mode Sheet opened
      expect(find.byKey(const Key('judge_mode_bottom_sheet')), findsOneWidget);
      expect(find.byKey(const Key('judge_mode_next_btn')), findsOneWidget);

      // Advance to step 2
      await tester.tap(find.byKey(const Key('judge_mode_next_btn')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Step 2 of 12'), findsOneWidget);
    });
  });

  group('Phase 8: Field Assistant Intelligence & Voice UI Tests', () {
    testWidgets('Shows Provider Badge, Prediction Banner, Evidence Breakdown, and Mic button', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);

      final mockClient = createMockPhase8Gateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final assistantRepo = FieldAssistantRepository(apiClient: apiClient);
      final scenariosProvider = DemoScenariosProvider(client: mockClient, baseUrl: 'http://127.0.0.1:3001');

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          fieldAssistantRepository: assistantRepo,
          demoScenariosProvider: scenariosProvider,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Open Field Assistant
      final entryButton = find.byKey(const Key('open_field_assistant_button'));
      await tester.tap(entryButton);
      await tester.pumpAndSettle();

      // 2. Verify mic button exists
      expect(find.byKey(const Key('assistant_mic_button')), findsOneWidget);

      // 3. Verify new Phase 8 quick chips exist
      expect(find.byKey(const Key('assistant_chip_prediction')), findsOneWidget);
      expect(find.byKey(const Key('assistant_chip_analysis')), findsOneWidget);
      expect(find.byKey(const Key('assistant_chip_compare')), findsOneWidget);

      // 4. Tap prediction chip
      await tester.tap(find.byKey(const Key('assistant_chip_prediction')));
      await tester.pumpAndSettle();

      // 5. Verify Provider Badge renders
      expect(find.byKey(const Key('assistant_provider_badge')), findsOneWidget);
      expect(find.text('Qwen3 8B'), findsOneWidget);

      // 6. Verify Prediction Banner renders
      expect(find.byKey(const Key('assistant_prediction_banner')), findsOneWidget);
      expect(find.textContaining('PRAHAR Scenario Estimate'), findsWidgets);

      // 7. Verify Evidence Breakdown Table renders
      expect(find.byKey(const Key('assistant_evidence_breakdown_card')), findsOneWidget);
      expect(find.textContaining('Soil Moisture'), findsOneWidget);
      expect(find.textContaining('16.8%'), findsOneWidget);
      expect(find.textContaining('Canopy Temperature'), findsOneWidget);
    });
  });
}
