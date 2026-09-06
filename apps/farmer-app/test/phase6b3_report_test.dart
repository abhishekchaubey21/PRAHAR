import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/auth_service.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/core/storage/offline_store.dart';
import 'package:farmer_app/data/repositories/report_repository.dart';
import 'package:farmer_app/domain/models.dart';
import 'package:farmer_app/screens/field_evidence_report_screen.dart';
import 'package:farmer_app/screens/field_health_analytics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const exactDisclaimer =
      'This report is an informational field-evidence summary generated from PRAHAR system observations and AI/edge outputs. It is not an official government certificate, legal warranty, or guaranteed diagnosis.';

  final demoFarm = {
    'id': 'farm-01',
    'name': 'Alpha Precision Farm',
    'location': 'Wardha, Maharashtra',
    'crop_type': 'Tomato',
    'area_acres': 3.5,
  };

  final demoZone1 = {
    'id': 'zone-01',
    'farm_id': 'farm-01',
    'name': 'North Plot (Zone 1)',
    'zone_name': 'North Plot (Zone 1)',
    'soil_type': 'Clay Loam',
  };

  final demoReportJson = {
    'report_id': 'PFER-FARM01-20260906-120000',
    'report_title': 'PRAHAR Field Evidence Report',
    'generated_at': '2026-09-06T12:00:00Z',
    'scan_time': '2026-09-06T11:45:00Z',
    'farm_id': 'farm-01',
    'farm_name': 'Alpha Precision Farm',
    'zone_id': 'zone-01',
    'zone_name': 'North Plot (Zone 1)',
    'crop_type': 'Tomato',
    'soil_type': 'Clay Loam',
    'location': 'Wardha, Maharashtra',
    'period': {
      'from': '2026-08-30T12:00:00Z',
      'to': '2026-09-06T12:00:00Z',
    },
    'field_health_summary': {
      'status': 'ATTENTION_REQUIRED',
      'health_label': 'PRAHAR Field-Health & Risk Summary',
      'summary_en': 'Attention required: Elevated water stress detected in North Plot.',
      'summary_hi': 'ध्यान आवश्यक: नॉर्थ प्लॉट में बढ़ा हुआ जल तनाव देखा गया।',
    },
    'sensor_evidence': {
      'moisture': 18.2,
      'temperature': 33.5,
      'humidity': 45.0,
      'ph': 6.4,
    },
    'hazard_history': [
      {
        'hazard_type': 'WATER_STRESS',
        'hazard_name': 'Severe Moisture Stress',
        'severity': 'HIGH',
        'confidence': 0.94,
        'timestamp': '2026-09-06T10:15:00Z',
      }
    ],
    'alerts_history': [
      {
        'id': 'alt-101',
        'title': 'Soil moisture in Zone 1 is critically low (18.2%)',
        'severity': 'HIGH',
        'status': 'OPEN',
        'created_at': '2026-09-06T10:16:00Z',
      }
    ],
    'interventions_history': [
      {
        'action_id': 'act-201',
        'zone_id': 'zone-01',
        'action_type': 'IRRIGATE',
        'duration_seconds': 30,
        'volume_liters': 7.5,
        'approved_by': 'dr_sharma_kvk_expert',
        'approved_at': '2026-09-06T10:30:00Z',
        'status': 'COMPLETED',
        'created_at': '2026-09-06T10:20:00Z',
        'verification': {
          'verification_id': 'verif-301',
          'pre_moisture': 18.2,
          'post_moisture': 28.5,
          'moisture_delta': 10.3,
          'resolved': true,
          'verification_timestamp': '2026-09-06T11:15:00Z',
          'summary_en': 'Moisture recovered (+10.3%). Resolved.',
          'summary_hi': 'नमी में सुधार हुआ (+10.3%)। समाधान हुआ।',
        }
      }
    ],
    'action_executed': 'IRRIGATE (30s, ~7.5L)',
    'verification_outcome': 'Moisture recovered (+10.3%). Resolved.',
    'recommendations': [
      'Maintain active precision irrigation schedules during afternoon heat peaks.',
      'Check drip emitters along the north perimeter for potential blockages.',
    ],
    'disclaimer': exactDisclaimer,
    'pdf_base64': base64Encode(utf8.encode('%PDF-1.4 mock binary content %%EOF')),
  };

  group('Phase 6B-3: ReportRepository Unit Tests', () {
    late ISessionStore sessionStore;

    setUp(() async {
      sessionStore = InMemorySessionStore();
      await sessionStore.saveSession(
        accessToken: 'jwt-test-token',
        refreshToken: 'rf-test-token',
        user: const FarmerUser(
          id: 'farmer-user-1',
          email: 'farmer@prahar.org',
          role: 'FARMER',
          fullName: 'Suresh Kumar',
        ),
      );
    });

    test('getReport: parses authoritative response correctly', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/reports/field-evidence');
        expect(request.url.queryParameters['farm_id'], 'farm-01');
        expect(request.url.queryParameters['zone_id'], 'zone-01');
        expect(request.headers['authorization'], 'Bearer jwt-test-token');

        return http.Response(
          jsonEncode({'success': true, 'data': demoReportJson}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final repo = ReportRepository(apiClient: apiClient);

      final report = await repo.getReport(farmId: 'farm-01', zoneId: 'zone-01');
      expect(report.reportId, 'PFER-FARM01-20260906-120000');
      expect(report.farmName, 'Alpha Precision Farm');
      expect(report.zoneName, 'North Plot (Zone 1)');
      expect(report.cropType, 'Tomato');
      expect(report.disclaimer, exactDisclaimer);
      expect(report.moisture, 18.2);
      expect(report.hazardHistory.length, 1);
      expect(report.hazardHistory.first.hazardType, 'WATER_STRESS');
      expect(report.alertsHistory.length, 1);
      expect(report.alertsHistory.first.id, 'alt-101');
      expect(report.interventionsHistory.length, 1);
      expect(report.interventionsHistory.first.verification?.resolved, true);
      expect(report.recommendations.length, 2);
      expect(report.pdfBase64, isNotNull);
    });

    test('generateReport: posts options and returns report model', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/reports/field-evidence/generate');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body);
        expect(body['farm_id'], 'farm-01');
        expect(body['format'], 'all');

        return http.Response(
          jsonEncode({'success': true, 'data': demoReportJson}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final repo = ReportRepository(apiClient: apiClient);

      final report = await repo.generateReport(farmId: 'farm-01', zoneId: 'zone-01', format: 'all');
      expect(report.reportId, startsWith('PFER-'));
      expect(report.disclaimer, exactDisclaimer);
    });

    test('extractPdfBytesFromReport: extracts bytes directly from report.pdfBase64', () {
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: MockClient((_) async => http.Response('', 404)));
      final repo = ReportRepository(apiClient: apiClient);

      final report = FieldEvidenceReportModel.fromJson(demoReportJson);
      final bytes = repo.extractPdfBytesFromReport(report);
      expect(bytes, isNotNull);
      expect(utf8.decode(bytes!), startsWith('%PDF-1.4'));
    });

    test('downloadPdf: downloads bytes directly from binary endpoint', () async {
      final mockPdfBytes = Uint8List.fromList(utf8.encode('%PDF-1.4 server streamed %%EOF'));
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/reports/field-evidence');
        expect(request.url.queryParameters['format'], 'pdf');
        return http.Response.bytes(
          mockPdfBytes,
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-disposition': 'attachment; filename="PFER-test.pdf"',
          },
        );
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final repo = ReportRepository(apiClient: apiClient);

      final bytes = await repo.downloadPdf(farmId: 'farm-01', zoneId: 'zone-01');
      expect(bytes, isNotEmpty);
      expect(utf8.decode(bytes), startsWith('%PDF-1.4 server streamed'));
    });

    test('Strict Network Requirement: offline failure throws NetworkUnavailableException and never caches', () async {
      final mockClient = MockClient((request) async {
        throw const SocketException('No active network connection');
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final repo = ReportRepository(apiClient: apiClient);

      expect(
        () async => await repo.getReport(farmId: 'farm-01'),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    test('API Error: 403 Forbidden throws ApiException and never returns demo data', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'error': 'Cross-tenant access forbidden'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final repo = ReportRepository(apiClient: apiClient);

      expect(
        () async => await repo.getReport(farmId: 'farm-02'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
      );
    });
  });

  group('Phase 6B-3: FieldEvidenceReportScreen Widget Tests', () {
    late ISessionStore sessionStore;
    late IOfflineStore offlineStore;

    setUp(() async {
      sessionStore = InMemorySessionStore();
      await sessionStore.saveSession(
        accessToken: 'jwt-test-token',
        refreshToken: 'rf-test-token',
        user: const FarmerUser(
          id: 'farmer-user-1',
          email: 'farmer@prahar.org',
          role: 'FARMER',
          fullName: 'Suresh Kumar',
        ),
      );
      offlineStore = InMemoryOfflineStore();
    });

    Widget createWidgetUnderTest({required http.Client httpClient}) {
      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: httpClient);
      return MaterialApp(
        home: FieldEvidenceReportScreen(
          apiClient: apiClient,
          offlineStore: offlineStore,
        ),
      );
    }

    testWidgets('UI Elements Rendered: selectors, period chips, and generate button', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(jsonEncode({'success': true, 'farms': [demoFarm]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/zones') {
          return http.Response(jsonEncode({'success': true, 'zones': [demoZone1]}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      });

      await tester.pumpWidget(createWidgetUnderTest(httpClient: mockClient));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report_farm_selector')), findsOneWidget);
      expect(find.byKey(const Key('report_zone_selector')), findsOneWidget);
      expect(find.byKey(const Key('period_selector_24h')), findsOneWidget);
      expect(find.byKey(const Key('period_selector_7d')), findsOneWidget);
      expect(find.byKey(const Key('period_selector_30d')), findsOneWidget);
      expect(find.byKey(const Key('generate_report_button')), findsOneWidget);
    });

    testWidgets('Generate and Preview: loads authoritative report and displays exact disclaimer', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(jsonEncode({'success': true, 'farms': [demoFarm]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/zones') {
          return http.Response(jsonEncode({'success': true, 'zones': [demoZone1]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.startsWith('/api/reports/field-evidence')) {
          return http.Response(
            jsonEncode({'success': true, 'data': demoReportJson}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      });

      await tester.pumpWidget(createWidgetUnderTest(httpClient: mockClient));
      await tester.pumpAndSettle();

      // Tap generate
      await tester.tap(find.byKey(const Key('generate_report_button')));
      await tester.pumpAndSettle();

      // Expect preview card to be rendered
      expect(find.byKey(const Key('report_preview_card')), findsOneWidget);

      // Verify exact disclaimer is displayed
      expect(find.byKey(const Key('report_disclaimer_banner')), findsOneWidget);
      expect(find.text(exactDisclaimer), findsOneWidget);

      // Verify report metadata and contents
      expect(find.text('ID: PFER-FARM01-20260906-120000'), findsOneWidget);
      expect(find.text('Alpha Precision Farm'), findsWidgets);
      expect(find.text('Severe Moisture Stress'), findsOneWidget);
      expect(find.text('Moisture recovered (+10.3%). Resolved.'), findsOneWidget);

      // Verify download PDF button
      final downloadBtn = find.byKey(const Key('download_pdf_button'));
      expect(downloadBtn, findsOneWidget);
      await tester.ensureVisible(downloadBtn);
      await tester.pumpAndSettle();

      // Tap download button
      await tester.runAsync(() async {
        await tester.tap(downloadBtn);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify download success snackbar
      expect(find.byKey(const Key('report_download_success')), findsOneWidget);
    });

    testWidgets('Offline Handling: displays offline refusal banner when disconnected', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(jsonEncode({'success': true, 'farms': [demoFarm]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/zones') {
          return http.Response(jsonEncode({'success': true, 'zones': [demoZone1]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.startsWith('/api/reports/field-evidence')) {
          throw const SocketException('No internet');
        }
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      });

      await tester.pumpWidget(createWidgetUnderTest(httpClient: mockClient));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('generate_report_button')));
      await tester.pumpAndSettle();

      // Expect offline banner and NO report preview card
      expect(find.byKey(const Key('report_offline_banner')), findsOneWidget);
      expect(find.byKey(const Key('report_preview_card')), findsNothing);
    });

    testWidgets('API Error Handling: displays error banner on 403 Forbidden', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(jsonEncode({'success': true, 'farms': [demoFarm]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/zones') {
          return http.Response(jsonEncode({'success': true, 'zones': [demoZone1]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.startsWith('/api/reports/field-evidence')) {
          return http.Response(
            jsonEncode({'success': false, 'error': 'Forbidden access to unowned farm'}),
            403,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      });

      await tester.pumpWidget(createWidgetUnderTest(httpClient: mockClient));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('generate_report_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report_error_banner')), findsOneWidget);
      expect(find.byKey(const Key('report_preview_card')), findsNothing);
    });

    testWidgets('Language Toggle: updates UI to Hindi and displays Hindi content', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(jsonEncode({'success': true, 'farms': [demoFarm]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/zones') {
          return http.Response(jsonEncode({'success': true, 'zones': [demoZone1]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path.startsWith('/api/reports/field-evidence')) {
          return http.Response(
            jsonEncode({'success': true, 'data': demoReportJson}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      });

      await tester.pumpWidget(createWidgetUnderTest(httpClient: mockClient));
      await tester.pumpAndSettle();

      // Switch language to Hindi
      await tester.tap(find.byKey(const Key('report_language_toggle')));
      await tester.pumpAndSettle();

      // Verify Hindi label on generate button
      expect(find.text('साक्ष्य रिपोर्ट तैयार करें'), findsOneWidget);

      // Generate report
      await tester.tap(find.byKey(const Key('generate_report_button')));
      await tester.pumpAndSettle();

      // Verify Hindi summary from report is displayed
      expect(find.text('ध्यान आवश्यक: नॉर्थ प्लॉट में बढ़ा हुआ जल तनाव देखा गया।'), findsOneWidget);
    });

    testWidgets('Navigation: Analytics screen export button navigates to report screen', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(jsonEncode({'success': true, 'farms': [demoFarm]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/zones') {
          return http.Response(jsonEncode({'success': true, 'zones': [demoZone1]}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/analytics/summary') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'farm_id': 'farm-01',
                'farm_name': 'Alpha Precision Farm',
                'total_zones': 1,
                'overall_status': 'OPTIMAL',
                'health_label': 'PRAHAR Field-Health & Risk Summary',
                'summary_en': 'All zones optimal.',
                'summary_hi': 'सभी ज़ोन इष्टतम हैं।',
                'active_alerts_count': 0,
                'zones': [],
                'evaluated_at': '2026-09-06T10:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
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

      // Find export report button in AppBar
      final exportBtn = find.byKey(const Key('export_report_button'));
      expect(exportBtn, findsOneWidget);

      await tester.tap(exportBtn);
      await tester.pumpAndSettle();

      // Verify we navigated to FieldEvidenceReportScreen
      expect(find.byKey(const Key('generate_report_button')), findsOneWidget);
    });
  });
}
