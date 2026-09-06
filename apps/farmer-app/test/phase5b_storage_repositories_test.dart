import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/auth_service.dart';
import 'package:farmer_app/core/offline_storage.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/core/storage/offline_store.dart';
import 'package:farmer_app/data/repositories/farm_repository.dart';
import 'package:farmer_app/data/repositories/alert_repository.dart';
import 'package:farmer_app/data/repositories/remediation_repository.dart';

void main() {
  group('Phase 5B: Storage Abstractions & Session Isolation', () {
    test('SessionStore abstraction: saves, loads, and clears session', () async {
      final sessionStore = InMemorySessionStore();
      expect(await sessionStore.loadSession(), isNull);

      const user = FarmerUser(
        id: 'usr-farmer-test',
        email: 'test@kisan.in',
        fullName: 'Test Kisan',
        farmerId: 'FARMER-01',
      );

      await sessionStore.saveSession(
        accessToken: 'jwt-test-token',
        refreshToken: 'refresh-test-token',
        user: user,
      );

      final loaded = await sessionStore.loadSession();
      expect(loaded, isNotNull);
      expect(loaded!.accessToken, 'jwt-test-token');
      expect(loaded.user.email, 'test@kisan.in');

      await sessionStore.clearSession();
      expect(await sessionStore.loadSession(), isNull);
    });

    test('OfflineStore abstraction: queues actions, stores cache, and handles 5 states', () async {
      final offlineStore = InMemoryOfflineStore();
      expect((await offlineStore.getPendingActions()).isEmpty, isTrue);

      final action = OfflineSyncAction(
        eventId: 'evt-01',
        idempotencyKey: 'idemp-01',
        actionType: 'APPROVE_IRRIGATION',
        payload: {'zone_id': 'ZONE-01', 'duration_seconds': 30},
        createdAt: DateTime.now().toIso8601String(),
        status: SyncStatus.pending,
      );

      await offlineStore.saveAction(action);
      expect((await offlineStore.getPendingActions()).length, 1);

      // Cache test
      await offlineStore.cacheData('farms', [{'id': 'FARM-01', 'name': 'Kisan Farm'}]);
      final cached = await offlineStore.getCachedData('farms');
      expect(cached, isA<List>());
      expect((cached as List).first['name'], 'Kisan Farm');

      await offlineStore.clear();
      expect((await offlineStore.getPendingActions()).isEmpty, isTrue);
    });
  });

  group('Phase 5B: ApiClient & Mandatory Amendment 1 (Authoritative vs Fallback)', () {
    test('Auth error (401/403) throws ApiException and does NOT silently fall back', () async {
      final sessionStore = InMemorySessionStore();
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'error': 'Unauthorized: Token expired'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      expect(
        () async => await apiClient.get('/api/farms'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('Network failure throws NetworkUnavailableException allowing offline fallback', () async {
      final sessionStore = InMemorySessionStore();
      final mockClient = MockClient((request) async {
        throw const SocketException('Connection refused');
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);

      expect(
        () async => await apiClient.get('/api/farms'),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });
  });

  group('Phase 5B: Repositories with Authoritative Online & Genuine Offline Fallback', () {
    test('FarmRepository: parses remote Supabase farms and updates cache', () async {
      final sessionStore = InMemorySessionStore();
      final offlineStore = InMemoryOfflineStore();

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/farms') {
          return http.Response(
            jsonEncode({
              'success': true,
              'farms': [
                {
                  'farm_id': 'FARM-REMOTE-01',
                  'name': 'Malwa Organic Fields',
                  'location': 'Indore, MP',
                  'total_hectares': 12.5,
                  'farmer_id': 'usr-farmer-01',
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final repo = FarmRepository(apiClient: apiClient, offlineStore: offlineStore);

      final farms = await repo.getFarms();
      expect(farms.length, 1);
      expect(farms.first.id, 'FARM-REMOTE-01');
      expect(farms.first.name, 'Malwa Organic Fields');

      // Check offline cache was populated
      final cached = await offlineStore.getCachedData('farms');
      expect(cached, isNotNull);
    });

    test('AlertRepository: returns remote alerts when online, falls back when offline', () async {
      final sessionStore = InMemorySessionStore();
      final offlineStore = InMemoryOfflineStore();

      bool networkDown = false;
      final mockClient = MockClient((request) async {
        if (networkDown) throw const SocketException('No Internet');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'alert_id': 'alert-live-99',
                'zone_id': 'DEMO-ZONE-02',
                'type': 'WATER_STRESS',
                'severity': 'HIGH',
                'message': 'Severe moisture deficit.',
                'message_hi': 'गंभीर जल तनाव।',
                'recommended_action': 'Irrigate 30s',
                'recommended_action_hi': '30s सिंचाई',
                'status': 'NEW',
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final repo = AlertRepository(apiClient: apiClient, offlineStore: offlineStore);

      // Online fetch
      final onlineAlerts = await repo.getAlerts();
      expect(onlineAlerts.length, 1);
      expect(onlineAlerts.first.id, 'alert-live-99');

      // Offline fetch -> uses cache
      networkDown = true;
      final offlineAlerts = await repo.getAlerts();
      expect(offlineAlerts.length, 1);
      expect(offlineAlerts.first.id, 'alert-live-99');
    });

    test('RemediationRepository: executes and verifies closed-loop intervention', () async {
      final sessionStore = InMemorySessionStore();
      final offlineStore = InMemoryOfflineStore();

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/remediation/execute') {
          return http.Response(
            jsonEncode({'success': true, 'message': 'Intervention executed'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/remediation/verify') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'zone_id': 'DEMO-ZONE-02',
                'pre_moisture': 17.5,
                'post_moisture': 28.2,
                'moisture_delta': 10.7,
                'resolved': true,
                'summary_en': 'Verified',
                'summary_hi': 'सत्यापित',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final repo = RemediationRepository(apiClient: apiClient, offlineStore: offlineStore);

      final executed = await repo.executeIntervention('action-123');
      expect(executed, isTrue);

      final verif = await repo.verifyIntervention('action-123');
      expect(verif, isNotNull);
      expect(verif!.resolved, isTrue);
      expect(verif.moistureDelta, 10.7);
    });
  });
}
