import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/auth_service.dart';
import 'package:farmer_app/core/offline_storage.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/core/storage/offline_store.dart';
import 'package:farmer_app/data/repositories/voice_repository.dart';
import 'package:farmer_app/screens/home_screen.dart';
import 'package:farmer_app/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MockClient createMockGateway({
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
      if (request.url.path == '/api/auth/logout') {
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      }

      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    });
  }

  Future<void> saveTestSession(ISessionStore store, {String token = 'jwt-xyz'}) async {
    await store.saveSession(
      accessToken: token,
      refreshToken: 'rf-xyz',
      user: const FarmerUser(
        id: 'farmer-user-1',
        email: 'farmer@prahar.org',
        role: 'FARMER',
        fullName: 'Ramesh Patel',
      ),
    );
  }

  group('PRAHAR Phase 6A-2: 6A-2A Voice Gateway Integration & Safety Gate', () {
    testWidgets('Scenario A & B: Voice request reaches Gateway with payload & Authenticated Bearer JWT', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore, token: 'real-farmer-jwt-token-xyz');

      http.Request? capturedVoiceRequest;
      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/voice/interact') {
            capturedVoiceRequest = req;
            return http.Response(
              jsonEncode({
                'success': true,
                'intent': 'FARM_STATUS',
                'spoken_text_en': 'All 3 zones are normal. Moisture is at optimal 24%.',
                'spoken_text_hi': 'सभी 3 ज़ोन सामान्य हैं। नमी 24% पर है।',
                'requires_confirmation': false,
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

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          voiceRepository: voiceRepo,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Open Voice Assistant dialog
      await tester.tap(find.text('Voice (Demo)'));
      await tester.pumpAndSettle();

      // Enter simulated voice query
      await tester.enterText(find.byKey(const Key('voice_input_field')), 'What is the farm status?');
      await tester.tap(find.byKey(const Key('voice_send_button')));
      await tester.pumpAndSettle();

      // Verify Scenario A: Payload reached gateway
      expect(capturedVoiceRequest, isNotNull);
      expect(capturedVoiceRequest!.method, 'POST');
      expect(capturedVoiceRequest!.url.path, '/api/voice/interact');

      final body = jsonDecode(capturedVoiceRequest!.body) as Map<String, dynamic>;
      expect(body['query'], 'What is the farm status?');
      expect(body['language'], 'en');
      expect(body['input_type'], 'SIMULATED_VOICE_INTENT');
      expect(body['session_id'], isNotEmpty);

      // Verify Scenario B: Authenticated Bearer JWT attached
      expect(capturedVoiceRequest!.headers['authorization'], 'Bearer real-farmer-jwt-token-xyz');
    });

    testWidgets('Scenario C: Valid voice intent (FARM_STATUS) returns spoken text', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);

      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/voice/interact') {
            return http.Response(
              jsonEncode({
                'success': true,
                'intent': 'FARM_STATUS',
                'spoken_text_en': 'All 3 zones are normal. Moisture is at optimal 24%.',
                'spoken_text_hi': 'सभी 3 ज़ोन सामान्य हैं। नमी 24% पर है।',
                'requires_confirmation': false,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voice (Demo)'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('voice_input_field')), 'farm status');
      await tester.tap(find.byKey(const Key('voice_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('All 3 zones are normal. Moisture is at optimal 24%.'), findsOneWidget);
      expect(find.byKey(const Key('voice_safety_banner')), findsNothing);
    });

    testWidgets('Scenario D: Unknown voice intent fails safely without actuator action', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);

      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/voice/interact') {
            return http.Response(
              jsonEncode({
                'success': true,
                'intent': 'UNKNOWN_INTENT',
                'spoken_text_en': 'Unknown command. For safety, no actuator action was taken.',
                'spoken_text_hi': 'अज्ञात आदेश। सुरक्षा के लिए कोई मोटर नहीं चलाई गई।',
                'requires_confirmation': false,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voice (Demo)'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('voice_input_field')), 'fly to orbit');
      await tester.tap(find.byKey(const Key('voice_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('Unknown command. For safety, no actuator action was taken.'), findsOneWidget);
      expect(find.byKey(const Key('voice_safety_banner')), findsNothing);
    });

    testWidgets('Scenario E: Voice cannot directly execute protected action (Safety Gate requires confirmation)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);

      int interactionCount = 0;
      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/voice/interact') {
            interactionCount++;
            if (interactionCount == 1) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'intent': 'APPROVE_IRRIGATION',
                  'spoken_text_en': 'Zone 2 irrigation requested. Safety Gate requires explicit confirmation.',
                  'spoken_text_hi': 'ज़ोन 2 के लिए सिंचाई का अनुरोध। सुरक्षा द्वार पुष्टि आवश्यक है।',
                  'requires_confirmation': true,
                  'safety_notice_en': 'Safety Gate: Voice alone CANNOT drive actuators. Manual confirmation required.',
                  'safety_notice_hi': 'सुरक्षा द्वार: केवल आवाज़ से मोटर नहीं चल सकती। मैनुअल पुष्टि आवश्यक है।',
                  'confirmation_prompt_en': 'Confirm 30s micro-irrigation for Zone 2?',
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            } else {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'intent': 'CONFIRMED_ACTION',
                  'spoken_text_en': 'Action confirmed. Proceeding to explicit execution.',
                  'spoken_text_hi': 'कार्रवाई की पुष्टि हुई।',
                  'requires_confirmation': false,
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voice (Demo)'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('voice_input_field')), 'Start irrigation in Zone 2');
      await tester.tap(find.byKey(const Key('voice_send_button')));
      await tester.pumpAndSettle();

      // Verify Safety Gate Banner is displayed
      expect(find.byKey(const Key('voice_safety_banner')), findsOneWidget);
      expect(find.text('Safety Gate: Voice alone CANNOT drive actuators. Manual confirmation required.'), findsOneWidget);

      // Confirm button exists and is initially disabled
      final confirmBtnFinder = find.byKey(const Key('voice_confirm_button'));
      expect(confirmBtnFinder, findsOneWidget);
      ElevatedButton btnWidget = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(btnWidget.onPressed, isNull);

      // Check the confirmation checkbox
      await tester.tap(find.byKey(const Key('voice_confirm_checkbox')));
      await tester.pumpAndSettle();

      // Now button is enabled
      btnWidget = tester.widget<ElevatedButton>(confirmBtnFinder);
      expect(btnWidget.onPressed, isNotNull);

      // Tap confirm button
      await tester.tap(confirmBtnFinder);
      await tester.pumpAndSettle();

      expect(interactionCount, 2);
    });

    testWidgets('Scenario F: Voice network error and API error are surfaced cleanly', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);

      bool shouldFailNetwork = true;
      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/voice/interact') {
            if (shouldFailNetwork) {
              throw const SocketException('Failed to connect to gateway');
            } else {
              return http.Response(
                jsonEncode({'error': 'Internal Gateway Failure'}),
                500,
                headers: {'content-type': 'application/json'},
              );
            }
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voice (Demo)'));
      await tester.pumpAndSettle();

      // 1. Network failure
      await tester.enterText(find.byKey(const Key('voice_input_field')), 'status');
      await tester.tap(find.byKey(const Key('voice_send_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Network Error: Unable to reach PRAHAR Voice Gateway.'), findsOneWidget);

      // 2. API 500 failure
      shouldFailNetwork = false;
      await tester.enterText(find.byKey(const Key('voice_input_field')), 'status again');
      await tester.tap(find.byKey(const Key('voice_send_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Voice Gateway Error (500)'), findsOneWidget);
    });

    testWidgets('Scenario G: Simulated STT is explicitly labeled and distinguishable', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voice (Demo)'));
      await tester.pumpAndSettle();

      // Verify Simulation label & disclaimer
      expect(find.text('SIMULATION / DEMO INTENT'), findsOneWidget);
      expect(find.textContaining('Honest STT Notice: Real microphone hardware not connected'), findsOneWidget);
      expect(find.textContaining('Voice commands CANNOT directly drive motors'), findsOneWidget);
    });
  });

  group('PRAHAR Phase 6A-2: 6A-2B Persistent Language Selection', () {
    testWidgets('Scenario H & I: Language toggle persists en and hi to IOfflineStore', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final offlineStore = InMemoryOfflineStore();
      final mockClient = createMockGateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          offlineStore: offlineStore,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Initial state is English; toggle button offers Hindi
      expect(find.byKey(const Key('language_toggle_button')), findsOneWidget);
      expect(find.text('हिन्दी'), findsOneWidget);

      // Tap toggle -> switches to Hindi (Scenario I)
      await tester.tap(find.byKey(const Key('language_toggle_button')));
      await tester.pumpAndSettle();

      expect(await offlineStore.getCachedData('user_language_preference'), 'hi');
      expect(find.text('English'), findsOneWidget);

      // Tap toggle again -> switches back to English (Scenario H)
      await tester.tap(find.byKey(const Key('language_toggle_button')));
      await tester.pumpAndSettle();

      expect(await offlineStore.getCachedData('user_language_preference'), 'en');
      expect(find.text('हिन्दी'), findsOneWidget);
    });

    test('Scenario J: Language preference is restored on app restart', () async {
      final offlineStore = InMemoryOfflineStore();
      await offlineStore.cacheData('user_language_preference', 'hi');

      final storage = OfflineStorageService(store: offlineStore);
      final restored = await storage.loadLanguagePreference();
      expect(restored, 'hi');
    });
  });

  group('PRAHAR Phase 6A-2: 6A-2C Farmer UX State & Navigation Completion', () {
    testWidgets('Scenario K: Loading state indicator displayed during fetch', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = MockClient((req) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return http.Response(jsonEncode({'success': true, 'farms': []}), 200, headers: {'content-type': 'application/json'});
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));

      // Pump 1 frame to start initState
      await tester.pump();
      expect(find.byKey(const Key('loading_indicator')), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loading_indicator')), findsNothing);
    });

    testWidgets('Scenario L: Network error state displayed on connectivity failure', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = MockClient((req) async {
        throw const SocketException('Gateway offline');
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          offlineStore: InMemoryOfflineStore(),
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Verify network offline banner and offline empty card
      expect(find.byKey(const Key('network_offline_banner')), findsOneWidget);
      expect(find.byKey(const Key('offline_empty_card')), findsOneWidget);
    });

    testWidgets('Scenario M: API error state surfaces actual server error without fallback', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = MockClient((req) async {
        return http.Response(
          jsonEncode({'error': 'Critical database outage'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('backend_error_banner')), findsOneWidget);
      expect(find.textContaining('Server error (500)'), findsOneWidget);
      expect(find.byKey(const Key('farm_card')), findsNothing);
    });

    testWidgets('Scenario N: Zero farms state renders empty farm card', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('empty_farm_card')), findsOneWidget);
      expect(find.text('No farms registered yet'), findsOneWidget);
    });

    testWidgets('Scenario O: Zero zones state renders empty zones container', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/farms') {
            return http.Response(
              jsonEncode({
                'success': true,
                'farms': [
                  {
                    'farm_id': 'farm-123',
                    'name': 'Green Acre Estate',
                    'location': 'Karnal, HR',
                    'total_hectares': 5.0,
                    'farmer_id': 'farmer-1',
                  }
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == '/api/zones') {
            return http.Response(
              jsonEncode({'success': true, 'zones': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('farm_card')), findsOneWidget);
      expect(find.byKey(const Key('empty_zones_container')), findsOneWidget);
      expect(find.text('No zones configured for this farm.'), findsOneWidget);
    });

    testWidgets('Scenario P: Zero alerts state renders empty alerts card', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/alerts') {
            return http.Response(
              jsonEncode({'success': true, 'data': []}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('empty_alerts_card')), findsOneWidget);
      expect(find.text('No active alerts for this farm.'), findsOneWidget);
    });

    testWidgets('Scenario Q: Logout confirmation clears session and cache', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final offlineStore = InMemoryOfflineStore();
      await saveTestSession(sessionStore, token: 'jwt-to-clear');
      await offlineStore.cacheData('user_language_preference', 'hi');

      final mockClient = createMockGateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final authService = FarmerAuthService(sessionStore: sessionStore, apiClient: apiClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          authService: authService,
          offlineStore: offlineStore,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Click logout icon in app bar
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();

      // Confirmation dialog is shown
      expect(find.text('Confirm Logout'), findsOneWidget);
      expect(find.byKey(const Key('confirm_logout_button')), findsOneWidget);

      // Confirm logout
      await tester.tap(find.byKey(const Key('confirm_logout_button')));
      await tester.pumpAndSettle();

      // Verify session cleared
      expect(await sessionStore.loadSession(), isNull);
      // Verify cache cleared
      expect(await offlineStore.getCachedData('user_language_preference'), isNull);
      // Navigated to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('Scenario R: No production demo data in fresh runtime state', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Verify no hardcoded demo data
      expect(find.text('Demo Farm Alpha'), findsNothing);
      expect(find.text('alert-01'), findsNothing);
      expect(find.text('DEMO-ZONE-02'), findsNothing);
      expect(find.byKey(const Key('empty_farm_card')), findsOneWidget);
      expect(find.byKey(const Key('empty_alerts_card')), findsOneWidget);
    });
  });
}
