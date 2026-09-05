import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:farmer_app/main.dart';
import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/offline_storage.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/core/storage/offline_store.dart';
import 'package:farmer_app/data/repositories/farm_repository.dart';
import 'package:farmer_app/data/repositories/alert_repository.dart';
import 'package:farmer_app/screens/home_screen.dart';

Widget createTestApp() {
  final sessionStore = InMemorySessionStore();
  final offlineStore = InMemoryOfflineStore();
  final mockClient = MockClient((request) async {
    if (request.url.path == '/api/farms') {
      return http.Response(
        jsonEncode({
          'success': true,
          'farms': [
            {
              'farm_id': 'FARM-01',
              'name': 'Demo Farm Alpha',
              'location': 'Indore, MP',
              'total_hectares': 3.5,
              'farmer_id': 'FAR-01',
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (request.url.path == '/api/alerts') {
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'alert_id': 'alert-01',
              'zone_id': 'DEMO-ZONE-02',
              'zone_name': 'Zone 2 (East Sector)',
              'type': 'WATER_STRESS',
              'severity': 'HIGH',
              'message': 'High Water Stress: Soil moisture at 17.5% (below 20% critical threshold).',
              'message_hi': 'गंभीर जल तनाव: मिट्टी की नमी 17.5% है (20% गंभीर सीमा से कम)।',
              'recommended_action': 'Micro-irrigation recommended for 30s. Awaiting your approval.',
              'recommended_action_hi': '30 सेकंड सूक्ष्म-सिंचाई की सिफारिश। आपकी स्वीकृति आवश्यक है।',
              'status': 'NEW',
            }
          ]
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
  });

  final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
  final farmRepo = FarmRepository(apiClient: apiClient, offlineStore: offlineStore);
  final alertRepo = AlertRepository(apiClient: apiClient, offlineStore: offlineStore);

  return PraharFarmerApp(
    initialHome: HomeScreen(
      apiClient: apiClient,
      farmRepository: farmRepo,
      alertRepository: alertRepo,
    ),
  );
}

void main() {
  testWidgets('PRAHAR Farmer App - renders, toggles Hindi, and approves remediation', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Verify initial English render & Phase 4 widgets
    expect(find.text('PRAHAR'), findsOneWidget);
    expect(find.text('Demo Farm Alpha'), findsOneWidget);
    expect(find.text('Approve Micro-Irrigation (30s)'), findsOneWidget);
    expect(find.text('Voice (Demo)'), findsOneWidget);
    expect(find.text('Evidence Report'), findsOneWidget);
    expect(find.text('Opportunities'), findsOneWidget);

    // Test Language Toggle to Hindi (Requirement 9)
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('सिंचाई स्वीकृत करें (30 सेकंड)'), findsOneWidget);
    expect(find.text('आवाज़ सहायक'), findsOneWidget);
    expect(find.text('साक्ष्य रिपोर्ट'), findsOneWidget);
    expect(find.text('योजनाएं'), findsOneWidget);

    // Test Safety Gate Approval & Remediation (Requirement 1 & 9)
    await tester.ensureVisible(find.text('सिंचाई स्वीकृत करें (30 सेकंड)'));
    await tester.tap(find.text('सिंचाई स्वीकृत करें (30 सेकंड)'));
    await tester.pumpAndSettle();

    // Verify verification card appears
    expect(find.text('उपचार सत्यापन सफल'), findsOneWidget);
    expect(find.text('स्वीकृत - रोवर द्वारा उपचार पूरा'), findsOneWidget);
  });

  testWidgets('PRAHAR Farmer App - Phase 4 Voice modal, Report disclaimer, and Opportunity Center', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestApp());
    await tester.pumpAndSettle();

    // Open Field Evidence Report and verify mandatory disclaimer
    await tester.tap(find.text('Evidence Report'));
    await tester.pumpAndSettle();

    expect(find.text('PRAHAR Field Evidence Report'), findsOneWidget);
    expect(find.textContaining('LEGAL DISCLAIMER'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Open Farmer Opportunity Center and verify official portal notice
    await tester.tap(find.text('Opportunities'));
    await tester.pumpAndSettle();

    expect(find.text('Farmer Opportunity Center'), findsOneWidget);
    expect(find.textContaining('PM-KUSUM'), findsOneWidget);
    expect(find.textContaining('PMKSY - Per Drop More Crop'), findsOneWidget);
    expect(find.textContaining('SMAM'), findsOneWidget);
    expect(find.textContaining('PMFBY'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Open Voice Assistant and verify honest simulation notice
    await tester.tap(find.text('Voice (Demo)'));
    await tester.pumpAndSettle();

    expect(find.text('PRAHAR Voice Assistant'), findsOneWidget);
    expect(find.text('SIMULATION / DEMO INTENT'), findsOneWidget);
    expect(find.textContaining('Honest STT Notice'), findsOneWidget);
  });

  test('OfflineStorageService - 5-state queueing, retry, and language preference', () async {
    final storage = OfflineStorageService();

    // Default language
    expect(storage.languagePreference, 'hi');
    storage.languagePreference = 'en';
    expect(storage.languagePreference, 'en');

    // Queue action
    expect(storage.pendingCount, 0);
    final action = storage.queueAction('APPROVE_IRRIGATION', {'zone_id': 'DEMO-ZONE-02'});
    expect(action.status, SyncStatus.pending);
    expect(action.idempotencyKey.isNotEmpty, true);
    expect(storage.pendingCount, 1);

    // Synchronize while offline
    storage.isOnline = false;
    final syncedWhenOffline = await storage.synchronize();
    expect(syncedWhenOffline, 0);
    expect(storage.pendingCount, 1);

    // Synchronize while online
    storage.isOnline = true;
    final syncedWhenOnline = await storage.synchronize(
      remoteSyncHandler: (act) async => true,
    );
    expect(syncedWhenOnline, 1);
    expect(action.status, SyncStatus.synced);
    expect(storage.pendingCount, 0);
  });
}
