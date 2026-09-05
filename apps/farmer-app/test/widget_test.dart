import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_app/main.dart';
import 'package:farmer_app/core/offline_storage.dart';

void main() {
  testWidgets('PRAHAR Farmer App - renders, toggles Hindi, and approves remediation', (WidgetTester tester) async {
    await tester.pumpWidget(const PraharFarmerApp());

    // Verify initial English render
    expect(find.text('PRAHAR'), findsOneWidget);
    expect(find.text('Demo Farm Alpha'), findsOneWidget);
    expect(find.text('Approve Micro-Irrigation (30s)'), findsOneWidget);

    // Test Language Toggle to Hindi (Requirement 9)
    await tester.tap(find.text('हिन्दी'));
    await tester.pumpAndSettle();

    expect(find.text('डेमो खेत अल्फा'), findsOneWidget);
    expect(find.text('सिंचाई स्वीकृत करें (30 सेकंड)'), findsOneWidget);

    // Test Safety Gate Approval & Remediation (Requirement 1 & 9)
    await tester.tap(find.text('सिंचाई स्वीकृत करें (30 सेकंड)'));
    await tester.pumpAndSettle();

    // Verify verification card appears
    expect(find.text('उपचार सत्यापन सफल'), findsOneWidget);
    expect(find.text('स्वीकृत - रोवर द्वारा उपचार पूरा'), findsOneWidget);
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
