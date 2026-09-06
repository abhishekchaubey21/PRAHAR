import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/auth_service.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/core/storage/offline_store.dart';
import 'package:farmer_app/data/repositories/farm_repository.dart';
import 'package:farmer_app/screens/login_screen.dart';
import 'package:farmer_app/screens/register_screen.dart';
import 'package:farmer_app/screens/home_screen.dart';
import 'package:farmer_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper mock client that returns safe empty defaults for any unhandled GET/POST
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

  group('PRAHAR Phase 6A-1: Login Screen & Validation', () {
    testWidgets('Scenario A: Login with empty email / password shows validation errors', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final authService = AuthService(sessionStore: sessionStore);

      await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: authService)));
      await tester.pumpAndSettle();

      // Tap Sign In button without typing
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('Scenario B: Login with invalid email format shows error', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final authService = AuthService(sessionStore: sessionStore);

      await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: authService)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('login_email_field')), 'invalid-email-address');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'password123');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address'), findsOneWidget);
    });

    testWidgets('Scenario C: Login with short password (<6 chars) shows error', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final authService = AuthService(sessionStore: sessionStore);

      await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: authService)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('login_email_field')), 'farmer@kisan.in');
      await tester.enterText(find.byKey(const Key('login_password_field')), '12345');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('Scenario D: Login failure with 401 surfaces ApiException to UI without fallback', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway(customHandler: (request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({'success': false, 'error': 'Invalid credentials'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final authService = AuthService(sessionStore: sessionStore, apiClient: apiClient);

      await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: authService)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('login_email_field')), 'farmer@kisan.in');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'wrongpassword');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(find.textContaining('401'), findsOneWidget);
      expect(await sessionStore.loadSession(), isNull);
    });

    testWidgets('Scenario E: Login network failure surfaces NetworkUnavailableException message', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway(customHandler: (request) async {
        if (request.url.path == '/api/auth/login') {
          throw const SocketException('Connection refused');
        }
        return http.Response('Not found', 404);
      });
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final authService = AuthService(sessionStore: sessionStore, apiClient: apiClient);

      await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: authService)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('login_email_field')), 'farmer@kisan.in');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'correctpassword');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
      expect(find.textContaining('Network'), findsOneWidget);
    });

    testWidgets('Scenario F: Login success saves session and navigates to HomeScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway(customHandler: (request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({
              'success': true,
              'session': {
                'access_token': 'jwt-real-token-123',
                'user': {
                  'id': 'usr-farmer-01',
                  'email': 'ramesh@kisan.in',
                  'full_name': 'Ramesh Patel',
                  'role': 'FARMER',
                  'farmer_id': 'FAR-01',
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final authService = AuthService(sessionStore: sessionStore, apiClient: apiClient);

      await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: authService)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('login_email_field')), 'ramesh@kisan.in');
      await tester.enterText(find.byKey(const Key('login_password_field')), 'password123');
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // Session saved
      final session = await sessionStore.loadSession();
      expect(session, isNotNull);
      expect(session!.accessToken, 'jwt-real-token-123');
      expect(session.user.fullName, 'Ramesh Patel');

      // Navigated to HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('PRAHAR Phase 6A-1: Registration Screen & Validation', () {
    testWidgets('Scenario G: Registration with mismatched passwords shows validation error', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final authService = AuthService(sessionStore: sessionStore);

      await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: authService)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_name_field')), 'Ramesh Patel');
      await tester.enterText(find.byKey(const Key('register_email_field')), 'ramesh@kisan.in');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'secret123');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'mismatched123');
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('Scenario H: Registration with valid data calls register, forces FARMER role, and logs in', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway(customHandler: (request) async {
        if (request.url.path == '/api/auth/register') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['full_name'], 'Suresh Kumar');
          expect(body['email'], 'suresh@kisan.in');

          return http.Response(
            jsonEncode({
              'success': true,
              'session': {
                'access_token': 'jwt-registered-token-456',
                'user': {
                  'id': 'usr-farmer-02',
                  'email': 'suresh@kisan.in',
                  'full_name': 'Suresh Kumar',
                  'role': 'FARMER',
                  'farmer_id': 'FAR-02',
                },
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final authService = AuthService(sessionStore: sessionStore, apiClient: apiClient);

      await tester.pumpWidget(MaterialApp(home: RegisterScreen(authService: authService)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('register_name_field')), 'Suresh Kumar');
      await tester.enterText(find.byKey(const Key('register_email_field')), 'suresh@kisan.in');
      await tester.enterText(find.byKey(const Key('register_password_field')), 'secret123');
      await tester.enterText(find.byKey(const Key('register_confirm_password_field')), 'secret123');
      await tester.tap(find.byKey(const Key('register_submit_button')));
      await tester.pumpAndSettle();

      final session = await sessionStore.loadSession();
      expect(session, isNotNull);
      expect(session!.accessToken, 'jwt-registered-token-456');
      expect(session.user.role, 'FARMER');
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('PRAHAR Phase 6A-1: Session-Aware App Boot & Logout UI', () {
    testWidgets('Scenario I: App boot without session opens LoginScreen directly', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const PraharFarmerApp(initialHome: LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byKey(const Key('login_submit_button')), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('Scenario J: App boot with existing valid session opens HomeScreen directly', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await sessionStore.saveSession(
        accessToken: 'jwt-valid-token',
        refreshToken: 'ref-valid-token',
        user: const FarmerUser(
          id: 'usr-farmer-01',
          email: 'farmer@kisan.in',
          fullName: 'Kisan Ramesh',
          role: 'FARMER',
        ),
      );

      final mockClient = createMockGateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(apiClient: apiClient),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('Scenario K: Logout confirmation dialog clears session and cache and navigates to LoginScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await sessionStore.saveSession(
        accessToken: 'jwt-logout-token',
        refreshToken: 'ref-logout-token',
        user: const FarmerUser(
          id: 'usr-farmer-01',
          email: 'farmer@kisan.in',
          fullName: 'Kisan Ramesh',
          role: 'FARMER',
        ),
      );

      final mockClient = createMockGateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final authService = AuthService(sessionStore: sessionStore, apiClient: apiClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          authService: authService,
        ),
      ));
      await tester.pumpAndSettle();

      // Tap logout button
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();

      // Confirmation dialog shown
      expect(find.text('Confirm Logout'), findsOneWidget);
      expect(find.byKey(const Key('confirm_logout_button')), findsOneWidget);

      // Confirm logout
      await tester.tap(find.byKey(const Key('confirm_logout_button')));
      await tester.pumpAndSettle();

      // Session cleared
      expect(await sessionStore.loadSession(), isNull);
      // Navigated to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('PRAHAR Phase 6A-1: Real Farm & Zone Data Binding', () {
    testWidgets('Scenario L: Real farm data binding replaces Demo Farm Alpha with live data', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway(customHandler: (request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(
            jsonEncode({
              'success': true,
              'farms': [
                {
                  'farm_id': 'FARM-NARMADA-01',
                  'name': 'Narmada Valley Organic Farm',
                  'location': 'Khargone, MP',
                  'total_hectares': 8.5,
                  'farmer_id': 'usr-farmer-01',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/zones') {
          return http.Response(
            jsonEncode({
              'success': true,
              'zones': [
                {
                  'id': 'ZONE-NV-01',
                  'name': 'North Orchard',
                  'soil_type': 'Black Cotton',
                  'moisture_pct': 24.5,
                  'temperature_c': 29.0,
                  'humidity_pct': 62.0,
                  'ph': 6.8,
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(apiClient: apiClient),
      ));
      await tester.pumpAndSettle();

      // Real farm name displayed
      expect(find.text('Narmada Valley Organic Farm'), findsOneWidget);
      expect(find.textContaining('Khargone, MP • 8.5 ha'), findsOneWidget);
      // Hardcoded Demo Farm Alpha is NOT displayed
      expect(find.text('Demo Farm Alpha'), findsNothing);
    });

    testWidgets('Scenario M: Real zone data binding renders dynamic chips and handles 0 zones gracefully', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway(customHandler: (request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(
            jsonEncode({
              'success': true,
              'farms': [
                {
                  'farm_id': 'FARM-01',
                  'name': 'Malwa Field',
                  'location': 'Dewas, MP',
                  'total_hectares': 3.2,
                  'farmer_id': 'usr-farmer-01',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/zones') {
          return http.Response(
            jsonEncode({
              'success': true,
              'zones': [
                {
                  'id': 'Z-101',
                  'name': 'Zone East (Wheat)',
                  'soil_type': 'Loam',
                  'moisture_pct': 19.4,
                  'temperature_c': 27.5,
                  'humidity_pct': 55.0,
                  'ph': 7.0,
                },
                {
                  'id': 'Z-102',
                  'name': 'Zone West (Gram)',
                  'soil_type': 'Clay',
                  'moisture_pct': 26.1,
                  'temperature_c': 28.0,
                  'humidity_pct': 58.0,
                  'ph': 6.9,
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(apiClient: apiClient),
      ));
      await tester.pumpAndSettle();

      // Zone chips rendered
      expect(find.byKey(const Key('zone_chip_Z-101')), findsOneWidget);
      expect(find.byKey(const Key('zone_chip_Z-102')), findsOneWidget);
      expect(find.textContaining('Zone East (Wheat)'), findsOneWidget);
      expect(find.textContaining('19.4%'), findsOneWidget);
    });

    testWidgets('Scenario N: Zero farms state renders empty state card without demo fallback', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final mockClient = createMockGateway(customHandler: (request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(
            jsonEncode({'success': true, 'farms': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(apiClient: apiClient),
      ));
      await tester.pumpAndSettle();

      // Empty state card shown
      expect(find.byKey(const Key('empty_farm_card')), findsOneWidget);
      expect(find.text('No farms registered yet'), findsOneWidget);
      // Demo Farm Alpha must NOT appear
      expect(find.text('Demo Farm Alpha'), findsNothing);
    });

    testWidgets('Manager Amendment: ApiException (500) surfaces actual error and never falls back to demo or cache', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final offlineStore = InMemoryOfflineStore();
      // Pre-seed cache to prove it must NOT fall back to cache on ApiException
      await offlineStore.cacheData('farms', [{'id': 'CACHE-01', 'name': 'Cached Fake Farm'}]);

      final mockClient = createMockGateway(customHandler: (request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(
            jsonEncode({'success': false, 'error': 'Database replication failure'}),
            500,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final farmRepo = FarmRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          farmRepository: farmRepo,
        ),
      ));
      await tester.pumpAndSettle();

      // Backend error banner must surface the 500 error
      expect(find.byKey(const Key('backend_error_banner')), findsOneWidget);
      expect(find.textContaining('500'), findsOneWidget);
      expect(find.textContaining('Database replication failure'), findsOneWidget);

      // Must NEVER display cached or demo farm
      expect(find.text('Cached Fake Farm'), findsNothing);
      expect(find.text('Demo Farm Alpha'), findsNothing);
    });

    testWidgets('Manager Amendment: NetworkUnavailableException uses cached data when available', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      final offlineStore = InMemoryOfflineStore();
      // Pre-seed cache for offline availability
      await offlineStore.cacheData('farms', [
        {
          'id': 'CACHE-FARM-01',
          'name': 'Cached Bundelkhand Plot',
          'location': 'Jhansi, UP',
          'total_hectares': 4.0,
          'farmer_id': 'usr-farmer-01',
        }
      ]);

      final mockClient = createMockGateway(customHandler: (request) async {
        if (request.url.path == '/api/farms') {
          throw const SocketException('No cellular network');
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final farmRepo = FarmRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          farmRepository: farmRepo,
        ),
      ));
      await tester.pumpAndSettle();

      // Uses cached farm on genuine network failure
      expect(find.text('Cached Bundelkhand Plot'), findsOneWidget);
      expect(find.textContaining('Jhansi, UP • 4.0 ha'), findsOneWidget);
    });
  });
}
