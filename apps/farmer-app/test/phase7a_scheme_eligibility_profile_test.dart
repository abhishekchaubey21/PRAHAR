import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/auth_service.dart';
import 'package:farmer_app/core/storage/offline_store.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/data/providers/demo_farm_dataset.dart';
import 'package:farmer_app/data/repositories/opportunity_repository.dart';
import 'package:farmer_app/screens/opportunity_center_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ISessionStore sessionStore;
  late IOfflineStore offlineStore;

  final canonicalProfile = CanonicalDemoDataset.profile;
  final canonicalFarm = CanonicalDemoDataset.farmSetup;
  final canonicalCrops = CanonicalDemoDataset.crops;

  final mockOpportunity = {
    'id': 'PMKSY-MICRO-IRRIGATION',
    'type': 'SUBSIDY',
    'title_en': 'Pradhan Mantri Krishi Sinchayee Yojana (PMKSY)',
    'title_hi': 'प्रधानमंत्री कृषि सिंचाई योजना (सूक्ष्म सिंचाई)',
    'department_authority': 'Ministry of Agriculture & Farmers Welfare',
    'benefits_summary_en': 'Up to 55% subsidy for small/marginal farmers on drip and sprinkler irrigation systems.',
    'benefits_summary_hi': 'ड्रिप एवं स्प्रिंकलर सिंचाई प्रणालियों पर छोटे और सीमांत किसानों को 55% तक सब्सिडी।',
    'target_profile_en': 'Small/Marginal farmers with borewell/water source in semi-arid districts.',
    'target_profile_hi': 'अर्ध-शुष्क जिलों में बोरवेल/जल स्रोत वाले छोटे/सीमांत किसान।',
    'eligibility_criteria': [
      'Farmer must own agricultural land or possess long-term lease agreement.',
      'Landholding up to 5.0 acres eligible for higher 55% subsidy bracket.',
      'Assured water source (borewell, well, canal) required.'
    ],
    'required_documents': [
      'Land Ownership 7/12 Extract (सात-बारा)',
      'Aadhaar Card copy',
      'Electricity Bill / Water Source Proof',
      'Bank Passbook copy'
    ],
    'official_portal_url': 'https://pmksy.gov.in',
    'application_steps': [
      {
        'step_number': 1,
        'title_en': 'Register on State Agriculture Portal',
        'title_hi': 'राज्य कृषि पोर्टल पर पंजीकरण करें',
        'description_en': 'Submit Aadhaar and 7/12 extract on Mahadbt or PMKSY state portal.',
        'description_hi': 'महाडीबीटी या पीएमकेएसवाई राज्य पोर्टल पर आधार और 7/12 जमा करें।'
      }
    ],
    'disclaimer':
        'Disclaimer: Self-assessed indicative guidance only. Official sanctions and subsidy disbursement are subject to field physical verification by the Agriculture Department.',
  };

  final mockEligibilityResponse = {
    'opportunity_id': 'PMKSY-MICRO-IRRIGATION',
    'status': 'LIKELY_ELIGIBLE',
    'matched_criteria_en': [
      'Landholding (4.20 acres) qualifies for Small & Marginal Farmer category (< 5.0 acres).',
      'Ownership type (OWNED) verified via land profile.',
      'Borewell water source satisfies assured irrigation criterion.'
    ],
    'unmatched_criteria_en': <String>[],
    'missing_information_en': [
      'Aadhaar-linked bank mandate verification pending on government portal.'
    ],
    'disclaimer_en':
        'Guidance is indicative based on self-reported profile data. Final benefit release requires official Aadhaar biometric and field survey verification.',
    'disclaimer_hi':
        'मार्गदर्शन केवल स्व-सूचित विवरण पर आधारित है। अंतिम लाभ स्वीकृति हेतु सरकारी बायोमेट्रिक और स्थलीय सत्यापन अनिवार्य है।',
  };

  setUp(() async {
    sessionStore = InMemorySessionStore();
    await sessionStore.saveSession(
      accessToken: 'mock-jwt-token',
      refreshToken: 'mock-refresh-token',
      user: const FarmerUser(
        id: '00000000-0000-0000-0000-000000000001',
        email: 'ramesh.patil@prahar.org',
        role: 'FARMER',
        fullName: 'Ramesh Patil',
      ),
    );
    offlineStore = InMemoryOfflineStore();
  });

  void setLargeScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('Phase 7A: Scheme Center & Farmer Profile Eligibility Integration', () {
    testWidgets('Profile Data Prefill: Forwards state, acres, crop, irrigation, and ownership to eligibility evaluation', (tester) async {
      setLargeScreen(tester);
      Map<String, dynamic>? receivedPayload;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          return http.Response(
            jsonEncode({'success': true, 'data': [mockOpportunity]}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/opportunities/tracking') {
          return http.Response(
            jsonEncode({'success': true, 'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/opportunities/check-eligibility') {
          receivedPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'success': true, 'data': mockEligibilityResponse}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: mockClient);
      final repo = OpportunityRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: OpportunityCenterScreen(
          opportunityRepository: repo,
          currentFarmId: CanonicalDemoDataset.farmId,
          landAcres: canonicalFarm.areaAcres,
          cropType: canonicalCrops.mainCrops.join(' + '),
          stateName: canonicalProfile.state,
          irrigationStatus: canonicalFarm.irrigationStatus,
          ownershipType: canonicalFarm.ownershipType,
        ),
      ));
      await tester.pumpAndSettle();

      // Open detail sheet
      await tester.tap(find.byKey(const Key('opportunity_card_PMKSY-MICRO-IRRIGATION')));
      await tester.pumpAndSettle();

      // Verify detail sheet opened with official portal URL
      expect(find.text('https://pmksy.gov.in'), findsOneWidget);

      // Verify official URL integrity: must point to a legitimate .gov.in domain
      expect(mockOpportunity['official_portal_url'], startsWith('https://'));
      expect(mockOpportunity['official_portal_url'], endsWith('.gov.in'));

      // Tap Check Eligibility button
      await tester.tap(find.byKey(const Key('check_eligibility_button')));
      await tester.pumpAndSettle();

      // Verify that all canonical profile parameters were properly transmitted
      expect(receivedPayload, isNotNull);
      expect(receivedPayload!['opportunity_id'], 'PMKSY-MICRO-IRRIGATION');
      expect(receivedPayload!['farm_id'], CanonicalDemoDataset.farmId);
      expect(receivedPayload!['land_acres'], 4.2);
      expect(receivedPayload!['state'], 'Maharashtra');
      expect(receivedPayload!['crop_type'], 'Soybean + Wheat');
      expect(receivedPayload!['irrigation_status'], 'PARTIAL');
      expect(receivedPayload!['ownership_type'], 'OWNED');

      // Verify matched criteria rendered
      expect(find.text('Matched Criteria:'), findsOneWidget);
      expect(
        find.text('Landholding (4.20 acres) qualifies for Small & Marginal Farmer category (< 5.0 acres).'),
        findsOneWidget,
      );
      expect(
        find.text('Borewell water source satisfies assured irrigation criterion.'),
        findsOneWidget,
      );

      // Verify missing information rendered
      expect(find.text('Missing Information:'), findsOneWidget);
      expect(
        find.text('Aadhaar-linked bank mandate verification pending on government portal.'),
        findsOneWidget,
      );

      // Verify mandatory indicative eligibility disclaimer is visible
      expect(find.byKey(const Key('mandatory_disclaimer_banner')), findsOneWidget);
      expect(find.textContaining('Self-assessed indicative guidance only'), findsOneWidget);
    });

    testWidgets('Missing Information & Indicative Disclaimer: Renders missing information hints and Hindi disclaimer', (tester) async {
      setLargeScreen(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          return http.Response(
            jsonEncode({'success': true, 'data': [mockOpportunity]}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/opportunities/tracking') {
          return http.Response(
            jsonEncode({'success': true, 'data': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/opportunities/check-eligibility') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'opportunity_id': 'PMKSY-MICRO-IRRIGATION',
                'status': 'INSUFFICIENT_INFORMATION',
                'matched_criteria_en': <String>[],
                'unmatched_criteria_en': <String>[],
                'missing_information_en': [
                  'Land area in acres is missing from farm profile.',
                  'Irrigation availability not specified.'
                ],
                'disclaimer_en':
                    'Guidance is indicative based on self-reported profile data. Final benefit release requires official Aadhaar biometric and field survey verification.',
                'disclaimer_hi':
                    'मार्गदर्शन केवल स्व-सूचित विवरण पर आधारित है। अंतिम लाभ स्वीकृति हेतु सरकारी बायोमेट्रिक और स्थलीय सत्यापन अनिवार्य है।',
              }
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: mockClient);
      final repo = OpportunityRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(MaterialApp(
        home: OpportunityCenterScreen(
          opportunityRepository: repo,
          isHindi: true,
          currentFarmId: 'farm-incomplete',
        ),
      ));
      await tester.pumpAndSettle();

      // Open detail sheet
      await tester.tap(find.byKey(const Key('opportunity_card_PMKSY-MICRO-IRRIGATION')));
      await tester.pumpAndSettle();

      // Tap Check Eligibility button
      await tester.tap(find.byKey(const Key('check_eligibility_button')));
      await tester.pumpAndSettle();

      // Verify Hindi missing information header
      expect(find.text('अधूरी जानकारी:'), findsOneWidget);
      expect(find.text('Land area in acres is missing from farm profile.'), findsOneWidget);

      // Verify mandatory disclaimer banner
      expect(find.byKey(const Key('mandatory_disclaimer_banner')), findsOneWidget);
    });
  });
}
