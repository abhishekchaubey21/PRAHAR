import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/auth_service.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/core/storage/offline_store.dart';
import 'package:farmer_app/domain/models.dart';
import 'package:farmer_app/data/repositories/farm_repository.dart';
import 'package:farmer_app/data/repositories/zone_repository.dart';
import 'package:farmer_app/data/repositories/analytics_repository.dart';
import 'package:farmer_app/screens/field_health_analytics_screen.dart';
import 'package:farmer_app/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final demoFarm = {
    'id': 'farm-01',
    'name': 'Alpha Precision Farm',
    'location': 'Wardha, Maharashtra',
    'total_hectares': 3.5,
    'crop_type': 'Tomato',
    'zones_count': 2,
    'monitored_zones': 2,
  };

  final demoZone1 = {
    'id': 'zone-01',
    'farm_id': 'farm-01',
    'name': 'North Plot (Zone 1)',
    'zone_name': 'North Plot (Zone 1)',
    'soil_type': 'Clay Loam',
    'moisture_pct': 24.5,
    'temperature_c': 28.0,
    'humidity_pct': 60.0,
    'ph': 6.5,
  };

  final demoZone2 = {
    'id': 'zone-02',
    'farm_id': 'farm-01',
    'name': 'East Plot (Zone 2)',
    'zone_name': 'East Plot (Zone 2)',
    'soil_type': 'Sandy Loam',
    'moisture_pct': 17.5,
    'temperature_c': 34.0,
    'humidity_pct': 42.0,
    'ph': 6.2,
  };

  final demoSummary = {
    'farm_id': 'farm-01',
    'farm_name': 'Alpha Precision Farm',
    'total_zones': 2,
    'overall_status': 'ATTENTION_REQUIRED',
    'health_label': 'PRAHAR Field-Health & Risk Summary',
    'summary_en': 'Zone 2 exhibits sub-20% moisture depletion.',
    'summary_hi': 'ज़ोन 2 में 20% से कम नमी देखी गई है।',
    'active_alerts_count': 1,
    'zones': [
      {
        'zone_id': 'zone-01',
        'zone_name': 'North Plot (Zone 1)',
        'farm_id': 'farm-01',
        'soil_type': 'Clay Loam',
        'health_status': 'OPTIMAL',
        'health_label': 'PRAHAR Field-Health & Risk Summary',
        'summary_en': 'Operating within optimal threshold.',
        'summary_hi': 'इष्टतम सीमा में काम कर रहा है।',
        'latest_metrics': {
          'moisture_pct': 28.5,
          'temperature_c': 29.5,
          'humidity_pct': 60.0,
          'ph': 6.5,
          'last_recorded_at': '2026-09-06T10:00:00Z',
        },
        'active_alerts_count': 0,
        'recent_hazard_count': 0,
        'evaluated_at': '2026-09-06T10:00:00Z',
      },
      {
        'zone_id': 'zone-02',
        'zone_name': 'East Plot (Zone 2)',
        'farm_id': 'farm-01',
        'soil_type': 'Sandy Loam',
        'health_status': 'ATTENTION_REQUIRED',
        'health_label': 'PRAHAR Field-Health & Risk Summary',
        'summary_en': 'Attention required: Elevated water stress.',
        'summary_hi': 'ध्यान आवश्यक: बढ़ा हुआ जल तनाव।',
        'latest_metrics': {
          'moisture_pct': 17.5,
          'temperature_c': 34.0,
          'humidity_pct': 42.0,
          'ph': 6.2,
          'last_recorded_at': '2026-09-06T10:00:00Z',
        },
        'active_alerts_count': 1,
        'recent_hazard_count': 1,
        'evaluated_at': '2026-09-06T10:00:00Z',
      }
    ],
    'evaluated_at': '2026-09-06T10:00:00Z',
  };

  final demoTrends = {
    'zone_id': 'zone-01',
    'zone_name': 'North Plot (Zone 1)',
    'has_sufficient_data': true,
    'sensor_trends': [
      {'timestamp': '2026-09-06T06:00:00Z', 'moisture_pct': 28.0, 'temperature_c': 26.0, 'humidity_pct': 65.0, 'ph': 6.5},
      {'timestamp': '2026-09-06T08:00:00Z', 'moisture_pct': 26.5, 'temperature_c': 29.0, 'humidity_pct': 58.0, 'ph': 6.5},
      {'timestamp': '2026-09-06T10:00:00Z', 'moisture_pct': 24.5, 'temperature_c': 32.0, 'humidity_pct': 50.0, 'ph': 6.5},
    ],
    'hazard_breakdown': [
      {
        'hazard_type': 'WATER_STRESS',
        'hazard_name': 'Moisture Depletion',
        'highest_severity': 'HIGH',
        'occurrence_count': 2,
        'latest_recorded_at': '2026-09-06T10:00:00Z',
        'latest_confidence': 0.92,
      },
    ],
    'evaluated_at': '2026-09-06T10:00:00Z',
  };

  final demoInterventions = {
    'farm_id': 'farm-01',
    'zone_id': 'zone-01',
    'total_count': 1,
    'interventions': [
      {
        'action_id': 'act-01',
        'zone_id': 'zone-01',
        'action_type': 'IRRIGATE',
        'duration_seconds': 30,
        'volume_liters': 7.5,
        'approved_by': 'dr_sharma_kvk_expert',
        'approved_at': '2026-09-06T09:00:00Z',
        'status': 'COMPLETED',
        'created_at': '2026-09-06T09:00:00Z',
        'verification': {
          'verification_id': 'verif-01',
          'pre_moisture': 17.5,
          'post_moisture': 28.2,
          'moisture_delta': 10.7,
          'resolved': true,
          'verification_timestamp': '2026-09-06T09:30:00Z',
          'summary_en': 'Moisture recovered (+10.7%). Resolved.',
          'summary_hi': 'नमी में सुधार हुआ (+10.7%)। समाधान हुआ।',
        },
      }
    ],
    'evaluated_at': '2026-09-06T10:00:00Z',
  };

  MockClient createMockGateway({
    Future<http.Response> Function(http.Request)? customHandler,
  }) {
    return MockClient((request) async {
      if (customHandler != null) {
        final res = await customHandler(request);
        if (res.statusCode != 404) return res;
      }

      if (request.url.path == '/api/farms') {
        return http.Response(jsonEncode({'success': true, 'farms': [demoFarm]}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/zones') {
        return http.Response(jsonEncode({'success': true, 'zones': [demoZone1, demoZone2]}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/alerts') {
        return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/remediation/verify' || request.url.path == '/api/remediation/verifications') {
        return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/notifications/unread-count') {
        return http.Response(jsonEncode({'success': true, 'count': 0}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/analytics/summary') {
        return http.Response(jsonEncode({'success': true, 'data': demoSummary}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/analytics/trends') {
        return http.Response(jsonEncode({'success': true, 'data': demoTrends}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/analytics/interventions') {
        return http.Response(jsonEncode({'success': true, 'data': demoInterventions}), 200, headers: {'content-type': 'application/json'});
      }

      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    });
  }

  group('PRAHAR Phase 6B-2: Farmer Analytics UI & Offline Scenarios (L–P)', () {
    testWidgets('Scenario N: Analytics UI renders selectors, health summary, trend chart, and interventions', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await sessionStore.saveSession(
        accessToken: 'jwt-test',
        refreshToken: 'rf-test',
        user: const FarmerUser(id: 'farmer-1', email: 'farmer@prahar.org', role: 'FARMER', fullName: 'Ramesh Patel'),
      );
      final offlineStore = InMemoryOfflineStore();
      final mockClient = createMockGateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: FieldHealthAnalyticsScreen(
            apiClient: apiClient,
            offlineStore: offlineStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Selectors
      expect(find.byKey(const Key('analytics_farm_selector')), findsOneWidget);
      expect(find.byKey(const Key('analytics_zone_selector')), findsOneWidget);

      // Verify Health Summary Card
      expect(find.byKey(const Key('field_health_summary_card')), findsOneWidget);
      expect(find.byKey(const Key('field_health_status_badge')), findsOneWidget);
      expect(find.byKey(const Key('metric_moisture')), findsOneWidget);
      expect(find.byKey(const Key('metric_temperature')), findsOneWidget);
      expect(find.byKey(const Key('metric_humidity')), findsOneWidget);
      expect(find.byKey(const Key('metric_ph')), findsOneWidget);

      // Verify Trend Chart
      expect(find.byKey(const Key('historical_trends_card')), findsOneWidget);
      expect(find.byKey(const Key('sensor_trend_chart')), findsOneWidget);

      // Verify Hazard Section
      expect(find.byKey(const Key('hazard_trends_section')), findsOneWidget);
      expect(find.text('Moisture Depletion'), findsOneWidget);

      // Verify Interventions Section
      expect(find.byKey(const Key('interventions_history_section')), findsOneWidget);
      expect(find.textContaining('IRRIGATE (30s, ~7.5L)'), findsOneWidget);
      expect(find.textContaining('Verification Succeeded'), findsOneWidget);
    });

    testWidgets('Scenario L: Offline cache fallback on NetworkUnavailableException shows cached data and banner', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await sessionStore.saveSession(
        accessToken: 'jwt-test',
        refreshToken: 'rf-test',
        user: const FarmerUser(id: 'farmer-1', email: 'farmer@prahar.org', role: 'FARMER', fullName: 'Ramesh Patel'),
      );
      final offlineStore = InMemoryOfflineStore();

      // Prime cache
      await offlineStore.cacheData('farms', [demoFarm]);
      await offlineStore.cacheData('zones_farm-01', [demoZone1, demoZone2]);
      await offlineStore.cacheData('analytics_summary_farm-01_zone-01', demoSummary);
      await offlineStore.cacheData('analytics_trends_zone-01', demoTrends);
      await offlineStore.cacheData('analytics_interventions_farm-01_zone-01', demoInterventions);

      // Client throws NetworkUnavailableException on all calls
      final mockClient = MockClient((request) async {
        throw const NetworkUnavailableException('Connection refused');
      });
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: FieldHealthAnalyticsScreen(
            apiClient: apiClient,
            offlineStore: offlineStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Offline Banner is displayed
      expect(find.byKey(const Key('analytics_offline_banner')), findsOneWidget);
      expect(find.textContaining('Offline Mode'), findsOneWidget);

      // Verify cached content rendered
      expect(find.byKey(const Key('field_health_summary_card')), findsOneWidget);
      expect(find.byKey(const Key('sensor_trend_chart')), findsOneWidget);
    });

    testWidgets('Scenario O: Localization switch from English to Hindi updates labels and badge', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await sessionStore.saveSession(
        accessToken: 'jwt-test',
        refreshToken: 'rf-test',
        user: const FarmerUser(id: 'farmer-1', email: 'farmer@prahar.org', role: 'FARMER', fullName: 'Ramesh Patel'),
      );
      final offlineStore = InMemoryOfflineStore();
      final mockClient = createMockGateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: FieldHealthAnalyticsScreen(
            apiClient: apiClient,
            offlineStore: offlineStore,
            initialIsHindi: false,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Field Health & Trends'), findsOneWidget);

      // Tap language toggle
      await tester.tap(find.byKey(const Key('analytics_language_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('खेत स्वास्थ्य एवं रुझान'), findsOneWidget);
      expect(find.text('प्रहार खेत-स्वास्थ्य सारांश'), findsOneWidget);
      expect(find.text('नमी'), findsWidgets);
    });

    testWidgets('Scenario P: Empty historical state displays friendly empty message', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await sessionStore.saveSession(
        accessToken: 'jwt-test',
        refreshToken: 'rf-test',
        user: const FarmerUser(id: 'farmer-1', email: 'farmer@prahar.org', role: 'FARMER', fullName: 'Ramesh Patel'),
      );
      final offlineStore = InMemoryOfflineStore();

      final emptyTrends = {
        'zone_id': 'zone-01',
        'has_sufficient_data': false,
        'sensor_trends': [],
        'hazard_breakdown': [],
        'evaluated_at': '2026-09-06T10:00:00Z',
      };

      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/analytics/trends') {
            return http.Response(jsonEncode({'success': true, 'data': emptyTrends}), 200, headers: {'content-type': 'application/json'});
          }
          return http.Response(jsonEncode({'success': false}), 404);
        },
      );
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: FieldHealthAnalyticsScreen(
            apiClient: apiClient,
            offlineStore: offlineStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Empty Trends State widget
      expect(find.byKey(const Key('empty_trends_state')), findsOneWidget);
      expect(find.textContaining('No historical sensor telemetry recorded yet'), findsOneWidget);
    });

    testWidgets('Scenario M: HomeScreen navigation button opens FieldHealthAnalyticsScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await sessionStore.saveSession(
        accessToken: 'jwt-test',
        refreshToken: 'rf-test',
        user: const FarmerUser(id: 'farmer-1', email: 'farmer@prahar.org', role: 'FARMER', fullName: 'Ramesh Patel'),
      );
      final offlineStore = InMemoryOfflineStore();
      final mockClient = createMockGateway();
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            apiClient: apiClient,
            offlineStore: offlineStore,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find analytics nav button on AppBar
      final navBtn = find.byKey(const Key('analytics_nav_button'));
      expect(navBtn, findsOneWidget);

      await tester.tap(navBtn);
      await tester.pumpAndSettle();

      // Verify FieldHealthAnalyticsScreen rendered
      expect(find.byKey(const Key('field_health_summary_card')), findsOneWidget);
    });
  });
}
