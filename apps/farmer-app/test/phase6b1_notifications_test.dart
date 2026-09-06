import 'dart:async';
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
import 'package:farmer_app/data/repositories/notification_repository.dart';
import 'package:farmer_app/screens/home_screen.dart';
import 'package:farmer_app/screens/notification_center_screen.dart';

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
      if (request.url.path == '/api/notifications/unread-count') {
        return http.Response(jsonEncode({'success': true, 'count': 0}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/notifications') {
        return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
      }
      if (request.url.path == '/api/auth/logout') {
        return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
      }

      return http.Response(jsonEncode({'success': true}), 200, headers: {'content-type': 'application/json'});
    });
  }

  Future<void> saveTestSession(ISessionStore store, {String token = 'jwt-farmer-test'}) async {
    await store.saveSession(
      accessToken: token,
      refreshToken: 'rf-test',
      user: const FarmerUser(
        id: 'farmer-user-1',
        email: 'farmer@prahar.org',
        role: 'FARMER',
        fullName: 'Ramesh Patel',
      ),
    );
  }

  group('PRAHAR Phase 6B-1: Farmer Notification Center & UI Scenarios (M–V)', () {
    testWidgets('Scenario M: Notification list rendering displays notifications with severity and type', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);
      final offlineStore = InMemoryOfflineStore();

      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/notifications') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'notif-01',
                    'notification_id': 'notif-01',
                    'user_id': 'farmer-user-1',
                    'farm_id': 'farm-01',
                    'type': 'ALERT_CREATED',
                    'severity': 'HIGH',
                    'title': 'High Soil Moisture Depletion',
                    'message': 'Zone 2 moisture level is below 15%',
                    'is_read': false,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                  {
                    'id': 'notif-02',
                    'notification_id': 'notif-02',
                    'user_id': 'farmer-user-1',
                    'farm_id': 'farm-01',
                    'type': 'ACTION_RECOMMENDED',
                    'severity': 'MEDIUM',
                    'title': 'Drip Irrigation Recommended',
                    'message': 'Irrigation recommended for 20 mins',
                    'is_read': true,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final notificationRepo = NotificationRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: NotificationCenterScreen(notificationRepository: notificationRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.text('High Soil Moisture Depletion'), findsOneWidget);
      expect(find.text('Zone 2 moisture level is below 15%'), findsOneWidget);
      expect(find.text('Drip Irrigation Recommended'), findsOneWidget);
      expect(find.byKey(const Key('notification_item_notif-01')), findsOneWidget);
      expect(find.byKey(const Key('notification_item_notif-02')), findsOneWidget);
      // Unread badge chip showing 1 unread in appbar
      expect(find.byKey(const Key('unread_count_badge_chip')), findsOneWidget);
    });

    testWidgets('Scenario N: Unread badge on HomeScreen bell icon shows count', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);
      final offlineStore = InMemoryOfflineStore();

      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/notifications/unread-count') {
            return http.Response(
              jsonEncode({'success': true, 'count': 4}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final notificationRepo = NotificationRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(
          apiClient: apiClient,
          notificationRepository: notificationRepo,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_bell_button')), findsOneWidget);
      expect(find.byKey(const Key('notification_unread_badge')), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('Scenario O: Mark read updates state locally and calls PATCH endpoint', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);
      final offlineStore = InMemoryOfflineStore();

      bool patchCalled = false;
      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/notifications' && req.method == 'GET') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'notif-01',
                    'notification_id': 'notif-01',
                    'user_id': 'farmer-user-1',
                    'farm_id': 'farm-01',
                    'type': 'ALERT_CREATED',
                    'severity': 'HIGH',
                    'title': 'Urgent Pest Warning',
                    'message': 'Stem borer detected in Zone 1',
                    'is_read': false,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == '/api/notifications/notif-01/read' && req.method == 'PATCH') {
            patchCalled = true;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'notif-01',
                  'notification_id': 'notif-01',
                  'is_read': true,
                  'read_at': DateTime.now().toIso8601String(),
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
      final notificationRepo = NotificationRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: NotificationCenterScreen(notificationRepository: notificationRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unread_count_badge_chip')), findsOneWidget);

      // Tap the notification card to view and mark as read
      await tester.tap(find.byKey(const Key('notification_item_notif-01')));
      await tester.pumpAndSettle();

      expect(patchCalled, isTrue);
      expect(find.byKey(const Key('notification_details_dialog')), findsOneWidget);

      // Close dialog
      await tester.tap(find.byKey(const Key('close_notification_dialog_button')));
      await tester.pumpAndSettle();

      // Badge chip should disappear as all notifications are now read
      expect(find.byKey(const Key('unread_count_badge_chip')), findsNothing);
    });

    testWidgets('Scenario P: Mark all read updates state for all items and calls POST endpoint', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);
      final offlineStore = InMemoryOfflineStore();

      bool markAllCalled = false;
      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/notifications' && req.method == 'GET') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'notif-01',
                    'notification_id': 'notif-01',
                    'user_id': 'farmer-user-1',
                    'type': 'ALERT_CREATED',
                    'severity': 'HIGH',
                    'title': 'Alert 1',
                    'message': 'Msg 1',
                    'is_read': false,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                  {
                    'id': 'notif-02',
                    'notification_id': 'notif-02',
                    'user_id': 'farmer-user-1',
                    'type': 'ACTION_RECOMMENDED',
                    'severity': 'MEDIUM',
                    'title': 'Action 1',
                    'message': 'Msg 2',
                    'is_read': false,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (req.url.path == '/api/notifications/read-all' && req.method == 'POST') {
            markAllCalled = true;
            return http.Response(
              jsonEncode({'success': true, 'count': 2}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final notificationRepo = NotificationRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: NotificationCenterScreen(notificationRepository: notificationRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mark_all_read_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mark_all_read_button')));
      await tester.pumpAndSettle();

      expect(markAllCalled, isTrue);
      expect(find.byKey(const Key('unread_count_badge_chip')), findsNothing);
    });

    testWidgets('Scenario Q: Empty state rendering shows friendly empty message', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);
      final offlineStore = InMemoryOfflineStore();

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: createMockGateway());
      final notificationRepo = NotificationRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: NotificationCenterScreen(notificationRepository: notificationRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notifications_empty_card')), findsOneWidget);
      expect(find.text('No Notifications'), findsOneWidget);
    });

    testWidgets('Scenario R: Loading state rendering displays spinner while fetching', (tester) async {
      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);
      final offlineStore = InMemoryOfflineStore();

      final completer = Completer<http.Response>();
      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/notifications') {
            return completer.future;
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final notificationRepo = NotificationRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: NotificationCenterScreen(notificationRepository: notificationRepo),
      ));
      await tester.pump();

      expect(find.byKey(const Key('notifications_loading_spinner')), findsOneWidget);

      completer.complete(
        http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'}),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notifications_loading_spinner')), findsNothing);
      expect(find.byKey(const Key('notifications_empty_card')), findsOneWidget);
    });

    testWidgets('Scenario S: API error state (no demo fallback) shows error message and retry button', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);
      final offlineStore = InMemoryOfflineStore();

      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/notifications') {
            return http.Response(
              jsonEncode({'success': false, 'error': 'Database unavailable'}),
              500,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final notificationRepo = NotificationRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: NotificationCenterScreen(notificationRepository: notificationRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notifications_error_message')), findsOneWidget);
      expect(find.byKey(const Key('notifications_retry_button')), findsOneWidget);
      expect(find.textContaining('API Error (500)'), findsOneWidget);
      // Ensure NO dummy or fallback cards rendered
      expect(find.byKey(const Key('notifications_empty_card')), findsNothing);
    });

    testWidgets('Scenario T: Offline cached notifications on NetworkUnavailableException shows banner and cached items', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);
      final offlineStore = InMemoryOfflineStore();

      // Seed offline cache
      await offlineStore.cacheData('notifications_cache', [
        {
          'id': 'cached-notif-01',
          'notification_id': 'cached-notif-01',
          'user_id': 'farmer-user-1',
          'farm_id': 'farm-01',
          'type': 'RISK_DETECTED',
          'severity': 'MEDIUM',
          'title': 'Cached Drought Warning',
          'message': 'Moisture levels dropping in Zone B',
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        }
      ]);

      // Network is down -> throws SocketException -> NetworkUnavailableException
      final mockClient = MockClient((req) async {
        throw const SocketException('No Internet connection');
      });

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final notificationRepo = NotificationRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: NotificationCenterScreen(notificationRepository: notificationRepo),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notifications_offline_banner')), findsOneWidget);
      expect(find.text('Cached Drought Warning'), findsOneWidget);
      expect(find.text('Moisture levels dropping in Zone B'), findsOneWidget);
      expect(find.byKey(const Key('notification_item_cached-notif-01')), findsOneWidget);
    });

    testWidgets('Scenario U: User isolation preserves multi-tenant safety when clearing cache', (tester) async {
      final sessionStore = InMemorySessionStore();
      final offlineStore = InMemoryOfflineStore();

      // User A caches notification
      await offlineStore.cacheData('notifications_cache', [
        {
          'id': 'user-a-notif',
          'user_id': 'user-a',
          'title': 'User A Secret Notification',
          'message': 'Data for user A only',
          'is_read': false,
        }
      ]);

      final apiClientA = ApiClient(sessionStore: sessionStore, httpClient: createMockGateway());
      final repoA = NotificationRepository(apiClient: apiClientA, offlineStore: offlineStore);

      // Verify User A can see cache offline
      final offlineMock = MockClient((req) async => throw const SocketException('offline'));
      final offlineClient = ApiClient(sessionStore: sessionStore, httpClient: offlineMock);
      final offlineRepo = NotificationRepository(apiClient: offlineClient, offlineStore: offlineStore);

      final cachedA = await offlineRepo.getNotifications();
      expect(cachedA.length, 1);
      expect(cachedA.first.title, 'User A Secret Notification');

      // Logout triggers clear
      await repoA.clearCache();

      // User B checks cache offline
      expect(
        () async => await offlineRepo.getNotifications(),
        throwsA(isA<NetworkUnavailableException>()),
      );
    });

    testWidgets('Scenario V: Notification context dialog navigation and metadata display', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sessionStore = InMemorySessionStore();
      await saveTestSession(sessionStore);
      final offlineStore = InMemoryOfflineStore();

      final mockClient = createMockGateway(
        customHandler: (req) async {
          if (req.url.path == '/api/notifications' && req.method == 'GET') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'notif-ctx-01',
                    'notification_id': 'notif-ctx-01',
                    'user_id': 'farmer-user-1',
                    'farm_id': 'farm-01',
                    'zone_id': 'ZONE-EAST-02',
                    'alert_id': 'ALT-9988',
                    'action_id': 'ACT-4433',
                    'type': 'VERIFICATION_COMPLETED',
                    'severity': 'LOW',
                    'title': 'Spray Remediation Verified',
                    'message': 'Rover has confirmed 100% remediation of Zone East.',
                    'is_read': false,
                    'created_at': DateTime.now().toIso8601String(),
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        },
      );

      final apiClient = ApiClient(sessionStore: sessionStore, httpClient: mockClient);
      final notificationRepo = NotificationRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: NotificationCenterScreen(notificationRepository: notificationRepo),
      ));
      await tester.pumpAndSettle();

      // Tap card to open context dialog
      await tester.tap(find.byKey(const Key('notification_item_notif-ctx-01')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_details_dialog')), findsOneWidget);
      expect(find.text('Spray Remediation Verified'), findsWidgets);
      expect(find.textContaining('Rover has confirmed 100% remediation of Zone East.'), findsWidgets);
      expect(find.text('Zone: ZONE-EAST-02'), findsOneWidget);
      expect(find.text('Alert ID: ALT-9988'), findsOneWidget);
      expect(find.text('Action ID: ACT-4433'), findsOneWidget);

      // Close dialog
      await tester.tap(find.byKey(const Key('close_notification_dialog_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_details_dialog')), findsNothing);
    });
  });
}
