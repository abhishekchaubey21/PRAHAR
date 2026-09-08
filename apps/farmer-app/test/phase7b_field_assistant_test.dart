import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/auth_service.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/data/assistant/assistant_context_builder.dart';
import 'package:farmer_app/data/assistant/field_assistant_engine.dart';
import 'package:farmer_app/data/providers/demo_farm_dataset.dart';
import 'package:farmer_app/data/repositories/field_assistant_repository.dart';
import 'package:farmer_app/data/repositories/voice_repository.dart';
import 'package:farmer_app/domain/assistant_model.dart';
import 'package:farmer_app/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MockClient createMockAssistantGateway({
    Future<http.Response> Function(http.Request)? customHandler,
  }) {
    return MockClient((request) async {
      if (customHandler != null) {
        final res = await customHandler(request);
        if (res.statusCode != 404) return res;
      }

      if (request.url.path == '/api/farms') {
        return http.Response(jsonEncode({'success': true, 'farms': []}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/zones') {
        return http.Response(jsonEncode({'success': true, 'zones': []}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/alerts') {
        return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/remediation/verify' || request.url.path == '/api/remediation/verifications') {
        return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/opportunities') {
        return http.Response(jsonEncode({'success': true, 'opportunities': []}), 200, headers: {'content-type': 'application/json'});
      }

      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    });
  }

  Future<void> saveTestSession(ISessionStore store, {String token = 'jwt-test-farmer'}) async {
    await store.saveSession(
      accessToken: token,
      refreshToken: 'rf-test-farmer',
      user: const FarmerUser(
        id: 'farmer-patil-1',
        email: 'ramesh.patil@prahar.org',
        role: 'FARMER',
        fullName: 'Ramesh Patil',
      ),
    );
  }

  group('Phase 7B: AssistantContextBuilder Tests', () {
    test('Builds comprehensive canonical farmer context from demo dataset', () {
      final context = AssistantContextBuilder.buildContext(
        profile: CanonicalDemoFarmDataset.profile,
        farm: CanonicalDemoFarmDataset.farmSetup,
        zones: CanonicalDemoFarmDataset.zones,
        alerts: CanonicalDemoFarmDataset.alerts,
        verifications: const [],
        opportunities: const [],
        language: 'en',
      );

      expect(context.farmerName, 'Ramesh Patil');
      expect(context.farmName, contains('Patil Krishi Farm'));
      expect(context.landAcres, 4.2);
      expect(context.district, 'Amravati');
      expect(context.state, 'Maharashtra');
      expect(context.soilType, 'Black Cotton Loam');
      expect(context.irrigationStatus, 'PARTIAL');
      expect(context.isSimulation, isTrue);

      // Verify 4 Zones
      expect(context.zones.length, 4);
      final z2 = context.zones.firstWhere((z) => z['id'] == 'DEMO-ZONE-02');
      expect(z2['moisture_pct'], 16.8);
      expect(z2['active_alert_count'], 1);

      // Verify Alerts
      expect(context.alerts.length, 3);
      final pestAlert = context.alerts.firstWhere((a) => a['type'] == 'pest');
      expect(pestAlert['zone_id'], 'DEMO-ZONE-03');
      expect(pestAlert['severity'], 'high');
      expect(pestAlert['hazard'], contains('Fall Armyworm'));
    });

    test('Serializes to and from JSON without data loss', () {
      final context = AssistantContextBuilder.buildContext(
        profile: CanonicalDemoFarmDataset.profile,
        farm: CanonicalDemoFarmDataset.farmSetup,
        zones: CanonicalDemoFarmDataset.zones,
        alerts: CanonicalDemoFarmDataset.alerts,
        verifications: const [],
        opportunities: const [],
        language: 'hi',
      );

      final json = context.toJson();
      final revived = FarmerAssistantContext.fromJson(json);

      expect(revived.farmerName, context.farmerName);
      expect(revived.language, 'hi');
      expect(revived.zones.length, 4);
      expect(revived.alerts.length, 3);
      expect(revived.isSimulation, isTrue);
    });
  });

  group('Phase 7B: FieldAssistantEngine Unit Tests', () {
    late FieldAssistantEngine engine;
    late FarmerAssistantContext context;

    setUp(() {
      engine = FieldAssistantEngine();
      context = AssistantContextBuilder.buildContext(
        profile: CanonicalDemoFarmDataset.profile,
        farm: CanonicalDemoFarmDataset.farmSetup,
        zones: CanonicalDemoFarmDataset.zones,
        alerts: CanonicalDemoFarmDataset.alerts,
        verifications: const [],
        opportunities: const [],
        language: 'en',
      );
    });

    test('Intent 1: FIELD_STATUS returns 4 zones and 3 alerts overview', () async {
      final res = await engine.processQuery('What is the current farm status?', context: context, language: 'en');
      expect(res.intent, AssistantIntent.fieldStatus);
      expect(res.answer, contains('4 zones'));
      expect(res.safetyLevel, AssistantSafetyLevel.safeInformational);
      expect(res.requiresConfirmation, isFalse);
    });

    test('Intent 2: ZONE_STATUS explains specific zone condition (Zone 2 Water Stress)', () async {
      final res = await engine.processQuery('What is the status of Zone 2?', context: context, language: 'en');
      expect(res.intent, AssistantIntent.zoneStatus);
      expect(res.relevantZoneId, 'DEMO-ZONE-02');
      expect(res.answer, contains('16.8%'));
      expect(res.severity, 'HIGH');
      expect(res.recommendation, contains('micro-irrigation'));
    });

    test('Intent 3: HAZARD_EXPLANATION identifies pest hazard', () async {
      final res = await engine.processQuery('Tell me about the pest hazard in Zone 3', context: context, language: 'en');
      expect(res.intent, AssistantIntent.hazardExplanation);
      expect(res.relevantZoneId, 'DEMO-ZONE-03');
      expect(res.severity, 'HIGH');
    });

    test('Intent 4: RECOMMENDATION_EXPLANATION advises foliar spray for nutrient deficiency', () async {
      final res = await engine.processQuery('What should I do about the nutrient deficiency in Zone 4?', context: context, language: 'en');
      expect(res.intent, AssistantIntent.recommendationExplanation);
      expect(res.recommendation, isNotNull);
    });

    test('Intent 5: ACTION_STATUS returns simulation closed-loop history', () async {
      final res = await engine.processQuery('Show me recent actions taken', context: context, language: 'en');
      expect(res.intent, AssistantIntent.actionStatus);
      expect(res.safetyLevel, AssistantSafetyLevel.safeInformational);
      expect(res.answer.toLowerCase(), contains('simulation'));
    });

    test('Intent 6: VERIFICATION_STATUS reports remediation verification status', () async {
      final res = await engine.processQuery('Was the problem resolved?', context: context, language: 'en');
      expect(res.intent, AssistantIntent.verificationStatus);
      expect(res.answer.toLowerCase(), contains('verification'));
    });

    test('Intent 7: SCHEME_QUERY returns eligible government schemes (PM-KISAN, PMFBY)', () async {
      final res = await engine.processQuery('Which government schemes can I apply for?', context: context, language: 'en');
      expect(res.intent, AssistantIntent.schemeQuery);
      expect(res.answer, contains('PM-KISAN'));
    });

    test('Intent 8: PROFILE_QUERY returns Ramesh Patil 4.2 acres details', () async {
      final res = await engine.processQuery('What is my farm profile?', context: context, language: 'en');
      expect(res.intent, AssistantIntent.profileQuery);
      expect(res.answer, contains('Ramesh Patil'));
      expect(res.answer, contains('4.2'));
      expect(res.answer, contains('Amravati'));
    });

    test('Intent 9: GENERAL_FARM_GUIDANCE provides agronomic best practices', () async {
      final res = await engine.processQuery('How should I prepare soil for Kharif season?', context: context, language: 'en');
      expect(res.intent, AssistantIntent.generalFarmGuidance);
      expect(res.answer, isNotEmpty);
      expect(res.recommendation, isNotNull);
    });

    test('Safety Gate: Irrigation triggers REQUIRES_CONFIRMATION with pending action', () async {
      final res = await engine.processQuery('Turn on irrigation for Zone 2', context: context, language: 'en');
      expect(res.safetyLevel, AssistantSafetyLevel.requiresConfirmation);
      expect(res.requiresConfirmation, isTrue);
      expect(res.pendingAction, isNotNull);
      expect(res.pendingAction!.actionType, 'IRRIGATE');
      expect(res.pendingAction!.zoneId, 'DEMO-ZONE-02');
      expect(res.pendingAction!.isSimulationOnly, isTrue);
    });

    test('Safety Gate: Chemical Spraying is PROHIBITED_AUTONOMOUS', () async {
      final res = await engine.processQuery('Spray chemical pesticide in Zone 3', context: context, language: 'en');
      expect(res.safetyLevel, AssistantSafetyLevel.prohibitedAutonomous);
      expect(res.requiresConfirmation, isFalse);
      expect(res.pendingAction, isNull);
      expect(res.answer, contains('Autonomous chemical spraying is strictly PROHIBITED'));
    });

    test('Action Confirmation: User confirmation dispatches simulated action', () async {
      // Step 1: Propose action
      final initial = await engine.processQuery('Start micro-irrigation for Zone 2', context: context, language: 'en');
      expect(initial.requiresConfirmation, isTrue);
      final actionId = initial.pendingAction!.id;

      // Step 2: Confirm action
      final confirmed = await engine.processQuery(
        'Confirm irrigation',
        context: context,
        language: 'en',
        confirmAction: true,
        pendingActionId: actionId,
      );

      expect(confirmed.requiresConfirmation, isFalse);
      expect(confirmed.answer, contains('SIMULATION ONLY'));
    });

    test('Multilingual Intent Resolution: Hindi and Marathi queries resolve properly', () async {
      // Hindi query for farm status
      final hiRes = await engine.processQuery('खेत की स्थिति क्या है?', context: context, language: 'hi');
      expect(hiRes.intent, AssistantIntent.fieldStatus);

      // Marathi query for profile
      final mrRes = await engine.processQuery('माझे शेत प्रोफाइल काय आहे?', context: context, language: 'mr');
      expect(mrRes.intent, AssistantIntent.profileQuery);
      expect(mrRes.answer, contains('रमेश पाटील'));
    });
  });

  group('Phase 7B: FieldAssistantRepository Tests', () {
    test('Queries POST /api/assistant/query with Bearer token and parses structured response', () async {
      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore, token: 'farmer-phase7b-token');

      http.Request? capturedReq;
      final mockClient = createMockAssistantGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/assistant/query') {
            capturedReq = req;
            return http.Response(
              jsonEncode({
                'success': true,
                'response': {
                  'intent': 'ZONE_STATUS',
                  'answer': 'Zone 2 is experiencing water stress at 16.8% moisture.',
                  'referenced_zone': 'DEMO-ZONE-02',
                  'severity': 'HIGH',
                  'recommendation': 'Trigger 15-minute micro-irrigation pulse.',
                  'requires_confirmation': false,
                  'safety_level': 'SAFE_INFORMATIONAL',
                  'simulation_status': 'SIMULATION ONLY • Physical Rover Disconnected',
                  'indicative_disclaimer': 'Physical Rover: Disconnected (Simulation Only)',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final repo = FieldAssistantRepository(apiClient: apiClient);

      final dummyContext = AssistantContextBuilder.buildContext(
        profile: CanonicalDemoFarmDataset.profile,
        farm: CanonicalDemoFarmDataset.farmSetup,
        zones: CanonicalDemoFarmDataset.zones,
        alerts: CanonicalDemoFarmDataset.alerts,
        verifications: const [],
        opportunities: const [],
        language: 'en',
      );

      final req = AssistantQueryRequest(
        query: 'What is wrong with Zone 2?',
        context: dummyContext,
        language: 'en',
      );

      final result = await repo.query(req);

      expect(result, isNotNull);
      expect(result!.intent, AssistantIntent.zoneStatus);
      expect(result.relevantZoneId, 'DEMO-ZONE-02');
      expect(result.severity, 'HIGH');
      expect(result.isSimulationOnly, isTrue);

      // Verify gateway contract
      expect(capturedReq, isNotNull);
      expect(capturedReq!.method, 'POST');
      expect(capturedReq!.url.path, '/api/assistant/query');
      expect(capturedReq!.headers['authorization'], 'Bearer farmer-phase7b-token');

      // Verify voice endpoint was NOT touched
      expect(capturedReq!.url.path, isNot('/api/voice/interact'));
    });
  });

  group('Phase 7B: HomeScreen Field Assistant UI Integration Tests', () {
    testWidgets('Entry Card: Opens Assistant Dialog, Shows Context & Quick Query Chips', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);

      final mockClient = createMockAssistantGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/assistant/query') {
            return http.Response(
              jsonEncode({
                'success': true,
                'response': {
                  'intent': 'ZONE_STATUS',
                  'answer': 'Zone 2 (East Sector) has severe moisture deficit at 16.8%.',
                  'referenced_zone': 'DEMO-ZONE-02',
                  'severity': 'HIGH',
                  'recommendation': 'Trigger micro-irrigation immediately.',
                  'requires_confirmation': false,
                  'safety_level': 'SAFE_INFORMATIONAL',
                  'simulation_status': 'SIMULATION ONLY • Physical Rover Disconnected',
                  'indicative_disclaimer': 'Physical Rover: Disconnected (Simulation Only)',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final voiceRepo = VoiceRepository(apiClient: apiClient);
      final assistantRepo = FieldAssistantRepository(apiClient: apiClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          voiceRepository: voiceRepo,
          fieldAssistantRepository: assistantRepo,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Verify Entry Card exists on Home Screen
      final entryButton = find.byKey(const Key('open_field_assistant_button'));
      expect(entryButton, findsOneWidget);

      // Verify Phase 6A2 voice button remains intact
      expect(find.text('Voice (Demo)'), findsOneWidget);

      // 2. Tap Entry Button to open Field Assistant Sheet
      await tester.tap(entryButton);
      await tester.pumpAndSettle();

      // 3. Verify Assistant Sheet opened
      expect(find.byKey(const Key('assistant_modal_bottom_sheet')), findsOneWidget);
      expect(find.text('PRAHAR Field Assistant'), findsWidgets);

      // 4. Verify Context Banner Chips
      expect(find.text('4.2 Acres'), findsOneWidget);
      expect(find.text('4 Zones'), findsOneWidget);
      expect(find.text('3 Alerts'), findsOneWidget);

      // 5. Verify Quick Query Chips
      final attentionChip = find.byKey(const Key('assistant_chip_attention'));
      expect(attentionChip, findsOneWidget);
      expect(find.byKey(const Key('assistant_chip_farm_status')), findsOneWidget);
      expect(find.byKey(const Key('assistant_chip_zone2')), findsOneWidget);
      expect(find.byKey(const Key('assistant_chip_schemes')), findsOneWidget);

      // 6. Tap quick chip for Attention
      await tester.tap(attentionChip);
      await tester.pumpAndSettle();

      // 7. Verify Structured Response Card renders
      expect(find.byKey(const Key('assistant_response_card')), findsOneWidget);
      expect(find.text('Zone 2 (East Sector) has severe moisture deficit at 16.8%.'), findsOneWidget);
      expect(find.text('ZONE_STATUS'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('DEMO-ZONE-02'), findsOneWidget);
      expect(find.text('Recommendation: Trigger micro-irrigation immediately.'), findsOneWidget);
    });

    testWidgets('Safety Confirmation Flow: Irrigation action requires explicit confirmation', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);

      int queryCallCount = 0;
      final mockClient = createMockAssistantGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/assistant/query') {
            queryCallCount++;
            final body = jsonDecode(req.body) as Map<String, dynamic>;

            if (body['confirm_action'] == true) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'response': {
                    'intent': 'ACTION_STATUS',
                    'answer': 'SIMULATION ONLY: Irrigation action for Zone 2 confirmed and executed.',
                    'referenced_zone': 'DEMO-ZONE-02',
                    'severity': 'LOW',
                    'recommendation': 'Monitor soil moisture response in 10 minutes.',
                    'requires_confirmation': false,
                    'safety_level': 'SAFE_INFORMATIONAL',
                    'simulation_status': 'SIMULATION ONLY • Physical Rover Disconnected',
                    'indicative_disclaimer': 'Physical Rover: Disconnected (Simulation Only)',
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }

            return http.Response(
              jsonEncode({
                'success': true,
                'response': {
                  'intent': 'ACTION_STATUS',
                  'answer': 'Irrigation action requested for Zone 2. Human confirmation required.',
                  'referenced_zone': 'DEMO-ZONE-02',
                  'severity': 'HIGH',
                  'requires_confirmation': true,
                  'safety_level': 'REQUIRES_CONFIRMATION',
                  'pending_action': {
                    'action_type': 'IRRIGATE',
                    'zone_id': 'DEMO-ZONE-02',
                    'duration_seconds': 30,
                    'volume_liters': 7.5,
                  },
                  'simulation_status': 'SIMULATION ONLY • Physical Rover Disconnected',
                  'indicative_disclaimer': 'Physical Rover: Disconnected (Simulation Only)',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final voiceRepo = VoiceRepository(apiClient: apiClient);
      final assistantRepo = FieldAssistantRepository(apiClient: apiClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          voiceRepository: voiceRepo,
          fieldAssistantRepository: assistantRepo,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Open Assistant
      await tester.tap(find.byKey(const Key('open_field_assistant_button')));
      await tester.pumpAndSettle();

      // Enter query to irrigate
      await tester.enterText(find.byKey(const Key('assistant_input_field')), 'Start irrigation in Zone 2');
      await tester.tap(find.byKey(const Key('assistant_send_button')));
      await tester.pumpAndSettle();

      // Verify Safety Gate UI appeared
      expect(find.byKey(const Key('assistant_safety_gate_box')), findsOneWidget);
      expect(find.text('CONFIRMATION REQUIRED (Simulation Only)'), findsOneWidget);
      final confirmCheckbox = find.byKey(const Key('assistant_confirm_checkbox'));
      expect(confirmCheckbox, findsOneWidget);
      final confirmButton = find.byKey(const Key('assistant_confirm_button'));
      expect(confirmButton, findsOneWidget);

      // Confirm button is disabled initially because checkbox is unchecked
      // Check the checkbox
      await tester.tap(confirmCheckbox);
      await tester.pumpAndSettle();

      // Tap Confirm Button
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // Verify execution response
      expect(queryCallCount, 2);
      expect(find.text('SIMULATION ONLY: Irrigation action for Zone 2 confirmed and executed.'), findsOneWidget);
    });

    testWidgets('Safety Prohibited UI: Chemical spray displays safety violation warning', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);

      final mockClient = createMockAssistantGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/assistant/query') {
            return http.Response(
              jsonEncode({
                'success': true,
                'response': {
                  'intent': 'HAZARD_EXPLANATION',
                  'answer': 'Autonomous chemical spraying is strictly prohibited under PRAHAR safety protocols.',
                  'referenced_zone': 'DEMO-ZONE-03',
                  'severity': 'HIGH',
                  'recommendation': 'Deploy non-chemical pheromone traps.',
                  'requires_confirmation': false,
                  'safety_level': 'PROHIBITED_AUTONOMOUS',
                  'simulation_status': 'SIMULATION ONLY • Physical Rover Disconnected',
                  'indicative_disclaimer': 'Physical Rover: Disconnected (Simulation Only)',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final voiceRepo = VoiceRepository(apiClient: apiClient);
      final assistantRepo = FieldAssistantRepository(apiClient: apiClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          voiceRepository: voiceRepo,
          fieldAssistantRepository: assistantRepo,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Open Assistant
      await tester.tap(find.byKey(const Key('open_field_assistant_button')));
      await tester.pumpAndSettle();

      // Enter spray query
      await tester.enterText(find.byKey(const Key('assistant_input_field')), 'Spray chemical pesticide in Zone 3');
      await tester.tap(find.byKey(const Key('assistant_send_button')));
      await tester.pumpAndSettle();

      // Verify Prohibited Banner is displayed and NO confirmation button exists
      expect(find.byKey(const Key('assistant_prohibited_box')), findsOneWidget);
      expect(find.text('ACTION PROHIBITED BY SAFETY PROTOCOL'), findsOneWidget);
      expect(find.byKey(const Key('assistant_confirm_button')), findsNothing);
    });
  });
}
