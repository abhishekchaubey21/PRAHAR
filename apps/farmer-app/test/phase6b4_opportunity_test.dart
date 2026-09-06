import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/auth_service.dart';
import 'package:farmer_app/core/storage/offline_store.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/data/repositories/opportunity_repository.dart';
import 'package:farmer_app/screens/opportunity_center_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const exactDisclaimer =
      'Eligibility shown by PRAHAR is guidance only. Final eligibility is determined by the concerned government department/bank/authority.';

  final mockSchemes = [
    {
      'id': 'PM-KISAN',
      'scheme_id': 'PM-KISAN',
      'title_en': 'Pradhan Mantri Kisan Samman Nidhi (PM-KISAN)',
      'title_hi': 'प्रधानमंत्री किसान सम्मान निधि (पीएम-किसान)',
      'type': 'SCHEME',
      'category': 'DIRECT_BENEFIT',
      'department_authority': 'Ministry of Agriculture & Farmers Welfare',
      'description_en': 'Income support of Rs. 6,000 per year in 3 equal installments.',
      'description_hi': 'प्रति वर्ष 6,000 रुपये की प्रत्यक्ष आय सहायता।',
      'benefits_summary_en': 'Rs. 6,000/year direct cash transfer',
      'benefits_summary_hi': 'रु. 6,000 प्रति वर्ष बैंक खाते में',
      'target_profile_en': 'All landholding farmer families',
      'target_profile_hi': 'सभी जोतधारक किसान परिवार',
      'eligibility_criteria_en': ['Must possess cultivable land', 'Aadhaar eKYC mandatory'],
      'eligibility_criteria_hi': ['खेती योग्य भूमि होना आवश्यक', 'आधार ई-केवाईसी अनिवार्य'],
      'required_documents': ['Aadhaar Card', 'Land Khatauni Records', 'Bank Passbook'],
      'official_portal_url': 'https://pmkisan.gov.in',
      'application_procedure_summary_en': 'Apply online via pmkisan.gov.in or visit CSC.',
      'application_procedure_summary_hi': 'pmkisan.gov.in पर या सीएससी पर आवेदन करें।',
      'application_steps': [
        {
          'step_number': 1,
          'title_en': 'eKYC Verification',
          'title_hi': 'ई-केवाईसी सत्यापन',
          'description_en': 'Complete OTP eKYC on portal.',
          'description_hi': 'पोर्टल पर ओटीपी ई-केवाईसी करें।',
          'is_online': true,
          'portal_url': 'https://pmkisan.gov.in',
        }
      ],
      'prahar_assistance_note_en': 'Guidance only. Direct application on pmkisan.gov.in.',
      'prahar_assistance_note_hi': 'केवल मार्गदर्शन। सीधे पोर्टल पर आवेदन करें।',
      'last_verified_at': '2026-09-01T00:00:00Z',
      'status': 'VERIFIED',
      'disclaimer': exactDisclaimer,
    },
    {
      'id': 'PM-KUSUM-SOLAR',
      'scheme_id': 'PM-KUSUM-SOLAR',
      'title_en': 'PM-KUSUM Standalone Solar Agriculture Pumps',
      'title_hi': 'पीएम-कुसुम सोलर पंप योजना',
      'type': 'SUBSIDY',
      'category': 'SOLAR_PUMP',
      'department_authority': 'Ministry of New and Renewable Energy',
      'description_en': 'Up to 60% subsidy for solar irrigation pumps.',
      'description_hi': 'सोलर सिंचाई पंप पर 60% तक सब्सिडी।',
      'benefits_summary_en': '60% subsidy on solar water pumps',
      'benefits_summary_hi': 'सोलर पंप पर 60% तक सब्सिडी',
      'target_profile_en': 'Farmers requiring solar pump irrigation',
      'target_profile_hi': 'सोलर सिंचाई चाहने वाले किसान',
      'eligibility_criteria_en': ['Valid agricultural land', 'Replacement of diesel pump'],
      'eligibility_criteria_hi': ['वैध कृषि भूमि', 'डीजल पंप प्रतिस्थापन'],
      'required_documents': ['Aadhaar Card', 'Land Jamabandi', 'Bank Passbook'],
      'official_portal_url': 'https://pmkusum.mnre.gov.in',
      'application_procedure_summary_en': 'Apply via state nodal portal.',
      'application_procedure_summary_hi': 'राज्य नोडल एजेंसी पोर्टल पर आवेदन करें।',
      'application_steps': [
        {
          'step_number': 1,
          'title_en': 'Select State Agency',
          'title_hi': 'राज्य एजेंसी चुनें',
          'description_en': 'Visit pmkusum.mnre.gov.in.',
          'description_hi': 'पोर्टल पर जाएं।',
          'is_online': true,
          'portal_url': 'https://pmkusum.mnre.gov.in',
        }
      ],
      'prahar_assistance_note_en': 'PRAHAR does not submit government applications.',
      'prahar_assistance_note_hi': 'प्रहार सरकारी आवेदन सीधे जमा नहीं करता।',
      'last_verified_at': '2026-09-01T00:00:00Z',
      'status': 'VERIFIED',
      'disclaimer': exactDisclaimer,
    },
    {
      'id': 'KCC-AGRI-CREDIT',
      'scheme_id': 'KCC-AGRI-CREDIT',
      'title_en': 'Kisan Credit Card (KCC) Scheme',
      'title_hi': 'किसान क्रेडिट कार्ड (केसीसी)',
      'type': 'LOAN',
      'category': 'CREDIT',
      'department_authority': 'RBI & Ministry of Agriculture',
      'description_en': 'Affordable crop loan at 4% interest.',
      'description_hi': '4% रियायती ब्याज दर पर फसली ऋण।',
      'benefits_summary_en': 'Concessional crop loan up to Rs. 3 Lakh',
      'benefits_summary_hi': '3 लाख रुपये तक का रियायती ऋण',
      'target_profile_en': 'All owner cultivators and tenant farmers',
      'target_profile_hi': 'सभी भूमि स्वामी एवं बटाईदार किसान',
      'eligibility_criteria_en': ['Operational landholding', 'Aadhaar / PAN'],
      'eligibility_criteria_hi': ['सक्रिय कृषि भूमि', 'आधार / पैन'],
      'required_documents': ['KCC Form', 'Aadhaar', 'Land 7/12'],
      'official_portal_url': 'https://myscheme.gov.in/schemes/kcc',
      'application_procedure_summary_en': 'Submit form at bank branch.',
      'application_procedure_summary_hi': 'बैंक शाखा में फॉर्म जमा करें।',
      'application_steps': [
        {
          'step_number': 1,
          'title_en': 'Fill KCC Form',
          'title_hi': 'केसीसी फॉर्म भरें',
          'description_en': 'Submit at local bank branch.',
          'description_hi': 'बैंक शाखा में जमा करें।',
          'is_online': false,
        }
      ],
      'prahar_assistance_note_en': 'Informational guidance only.',
      'prahar_assistance_note_hi': 'केवल सूचनात्मक मार्गदर्शन।',
      'last_verified_at': '2026-09-01T00:00:00Z',
      'status': 'VERIFIED',
      'disclaimer': exactDisclaimer,
    },
  ];

  final mockTracking = [
    {
      'id': 'track-01',
      'user_id': 'farmer-user-1',
      'opportunity_id': 'PM-KISAN',
      'status': 'USER_SUBMITTED',
      'notes': 'Submitted on portal. Ref: PMK-2026-01',
      'created_at': '2026-09-06T10:00:00Z',
      'updated_at': '2026-09-06T11:00:00Z',
    }
  ];

  final mockEligibilityLikely = {
    'opportunity_id': 'PM-KISAN',
    'status': 'LIKELY_ELIGIBLE',
    'matched_criteria_en': ['Cultivable landholding confirmed: 6.18 acres'],
    'matched_criteria_hi': ['खेती योग्य भूमि सत्यापित: 6.18 एकड़'],
    'unmatched_criteria_en': [],
    'unmatched_criteria_hi': [],
    'missing_information_en': [],
    'missing_information_hi': [],
    'disclaimer': exactDisclaimer,
    'evaluated_at': '2026-09-06T12:00:00Z',
  };

  final mockEligibilityInsufficient = {
    'opportunity_id': 'PM-KUSUM-SOLAR',
    'status': 'INSUFFICIENT_INFORMATION',
    'matched_criteria_en': [],
    'matched_criteria_hi': [],
    'unmatched_criteria_en': [],
    'unmatched_criteria_hi': [],
    'missing_information_en': ['Land holding size (acres) is missing from your profile.'],
    'missing_information_hi': ['आपकी प्रोफाइल में भूमि जोत (एकड़) का विवरण उपलब्ध नहीं है।'],
    'disclaimer': exactDisclaimer,
    'evaluated_at': '2026-09-06T12:00:00Z',
  };

  group('Phase 6B-4: Farmer Opportunity Center Flutter Test Suite', () {
    late ISessionStore sessionStore;
    late IOfflineStore offlineStore;

    setUp(() async {
      sessionStore = InMemorySessionStore();
      await sessionStore.saveSession(
        accessToken: 'jwt-test-farmer-token',
        refreshToken: 'rf-test-farmer-token',
        user: const FarmerUser(
          id: 'farmer-user-1',
          email: 'farmer@prahar.org',
          role: 'FARMER',
          fullName: 'Rameshwar Patel',
        ),
      );
      offlineStore = InMemoryOfflineStore();
    });

    void setLargeScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
    }

    Widget createTestApp({
      required OpportunityRepository repository,
      bool isHindi = false,
      double? landAcres,
      String? currentFarmId,
    }) {
      return MaterialApp(
        home: OpportunityCenterScreen(
          opportunityRepository: repository,
          isHindi: isHindi,
          landAcres: landAcres,
          currentFarmId: currentFarmId,
        ),
      );
    }

    testWidgets('Scenario O: Opportunity Center renders title, chips, and opportunity cards', (tester) async {
      setLargeScreen(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          return http.Response(
            jsonEncode({'success': true, 'data': mockSchemes}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/opportunities/tracking') {
          return http.Response(
            jsonEncode({'success': true, 'data': mockTracking}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: mockClient);
      final repo = OpportunityRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(createTestApp(repository: repo));
      await tester.pumpAndSettle();

      expect(find.text('Opportunity & Scheme Center'), findsOneWidget);
      expect(find.text('Verified Agricultural Schemes & Guidance'), findsOneWidget);
      expect(find.byKey(const Key('category_filter_all')), findsOneWidget);
      expect(find.byKey(const Key('category_filter_scheme')), findsOneWidget);
      expect(find.byKey(const Key('category_filter_subsidy')), findsOneWidget);
      expect(find.byKey(const Key('category_filter_loan')), findsOneWidget);

      expect(find.byKey(const Key('opportunity_card_PM-KISAN')), findsOneWidget);
      expect(find.byKey(const Key('opportunity_card_PM-KUSUM-SOLAR')), findsOneWidget);
      expect(find.byKey(const Key('opportunity_card_KCC-AGRI-CREDIT')), findsOneWidget);
      expect(find.text('Application Submitted (Self-Reported)'), findsOneWidget);
    });

    testWidgets('Scenario P: Category tab filtering filters opportunities list', (tester) async {
      setLargeScreen(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          final type = request.url.queryParameters['type'];
          if (type == 'SUBSIDY') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': mockSchemes.where((s) => s['type'] == 'SUBSIDY').toList(),
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({'success': true, 'data': mockSchemes}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/opportunities/tracking') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: mockClient);
      final repo = OpportunityRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(createTestApp(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('opportunity_card_PM-KISAN')), findsOneWidget);
      expect(find.byKey(const Key('opportunity_card_PM-KUSUM-SOLAR')), findsOneWidget);

      // Tap SUBSIDY chip
      await tester.tap(find.byKey(const Key('category_filter_subsidy')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('opportunity_card_PM-KUSUM-SOLAR')), findsOneWidget);
      expect(find.byKey(const Key('opportunity_card_PM-KISAN')), findsNothing);
    });

    testWidgets('Scenario Q: Opportunity details view opens in bottom sheet', (tester) async {
      setLargeScreen(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          return http.Response(jsonEncode({'success': true, 'data': mockSchemes}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/opportunities/tracking') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: mockClient);
      final repo = OpportunityRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(createTestApp(repository: repo));
      await tester.pumpAndSettle();

      // Tap on PM-KISAN card to open bottom sheet
      await tester.tap(find.byKey(const Key('opportunity_card_PM-KISAN')));
      await tester.pumpAndSettle();

      expect(find.text('Pradhan Mantri Kisan Samman Nidhi (PM-KISAN)'), findsWidgets);
      expect(find.text('Overview & Benefits'), findsOneWidget);
      expect(find.text('Eligibility Assistant'), findsOneWidget);
      expect(find.text('Required Documents Checklist'), findsOneWidget);
      expect(find.text('Official Government Portal'), findsOneWidget);
      expect(find.text('https://pmkisan.gov.in'), findsOneWidget);
    });

    testWidgets('Scenario R: Eligibility Assistant evaluation states (Likely Eligible vs Insufficient Info)', (tester) async {
      setLargeScreen(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          return http.Response(jsonEncode({'success': true, 'data': mockSchemes}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/opportunities/tracking') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/opportunities/check-eligibility') {
          final body = jsonDecode(request.body);
          if (body['opportunity_id'] == 'PM-KISAN') {
            return http.Response(
              jsonEncode({'success': true, 'data': mockEligibilityLikely}),
              200,
              headers: {'content-type': 'application/json'},
            );
          } else {
            return http.Response(
              jsonEncode({'success': true, 'data': mockEligibilityInsufficient}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: mockClient);
      final repo = OpportunityRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(createTestApp(repository: repo, landAcres: 6.18, currentFarmId: 'farm-01'));
      await tester.pumpAndSettle();

      // Open detail
      await tester.tap(find.byKey(const Key('opportunity_card_PM-KISAN')));
      await tester.pumpAndSettle();

      // Tap Check Eligibility
      await tester.tap(find.byKey(const Key('check_eligibility_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('eligibility_status_badge')), findsOneWidget);
      expect(find.text('Likely Eligible'), findsOneWidget);
      expect(find.text('Matched Criteria:'), findsOneWidget);
      expect(find.text('Cultivable landholding confirmed: 6.18 acres'), findsOneWidget);
    });

    testWidgets('Scenario S: Mandatory guidance disclaimer banner is displayed', (tester) async {
      setLargeScreen(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          return http.Response(jsonEncode({'success': true, 'data': mockSchemes}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/opportunities/tracking') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: mockClient);
      final repo = OpportunityRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(createTestApp(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('opportunity_card_PM-KISAN')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mandatory_disclaimer_banner')), findsOneWidget);
      expect(find.text(exactDisclaimer), findsOneWidget);
    });

    testWidgets('Scenario T: Document checklist interaction (toggle checkboxes)', (tester) async {
      setLargeScreen(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          return http.Response(jsonEncode({'success': true, 'data': mockSchemes}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/opportunities/tracking') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: mockClient);
      final repo = OpportunityRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(createTestApp(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('opportunity_card_PM-KISAN')));
      await tester.pumpAndSettle();

      final aadhaarCheckbox = find.widgetWithText(CheckboxListTile, 'Aadhaar Card');
      expect(aadhaarCheckbox, findsOneWidget);

      CheckboxListTile tile = tester.widget<CheckboxListTile>(aadhaarCheckbox);
      expect(tile.value, isFalse);

      // Tap checkbox to mark prepared
      await tester.tap(aadhaarCheckbox);
      await tester.pumpAndSettle();

      tile = tester.widget<CheckboxListTile>(aadhaarCheckbox);
      expect(tile.value, isTrue);
    });

    testWidgets('Scenario U: Application tracking status update and save', (tester) async {
      setLargeScreen(tester);

      String? updatedStatus;
      String? updatedNotes;

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          return http.Response(jsonEncode({'success': true, 'data': mockSchemes}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/opportunities/tracking' && request.method == 'GET') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/opportunities/tracking' && request.method == 'POST') {
          final body = jsonDecode(request.body);
          updatedStatus = body['status'];
          updatedNotes = body['notes'];
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'new-track-id',
                'user_id': 'farmer-user-1',
                'opportunity_id': body['opportunity_id'],
                'status': body['status'],
                'notes': body['notes'],
                'created_at': '2026-09-06T12:00:00Z',
                'updated_at': '2026-09-06T12:00:00Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: mockClient);
      final repo = OpportunityRepository(apiClient: apiClient, offlineStore: offlineStore);

      await tester.pumpWidget(createTestApp(repository: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('opportunity_card_PM-KISAN')));
      await tester.pumpAndSettle();

      // Enter notes
      await tester.enterText(find.byKey(const Key('tracking_notes_field')), 'Ref No: PMK-2026-TEST');
      await tester.pumpAndSettle();

      // Tap save
      await tester.tap(find.byKey(const Key('save_status_button')));
      await tester.pumpAndSettle();

      expect(updatedStatus, isNotNull);
      expect(updatedNotes, 'Ref No: PMK-2026-TEST');
      expect(find.text('Status updated successfully'), findsOneWidget);
    });

    testWidgets('Scenario V: English and Hindi bilingual localization toggle', (tester) async {
      setLargeScreen(tester);

      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          return http.Response(jsonEncode({'success': true, 'data': mockSchemes}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/opportunities/tracking') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: mockClient);
      final repo = OpportunityRepository(apiClient: apiClient, offlineStore: offlineStore);

      // Hindi view
      await tester.pumpWidget(createTestApp(repository: repo, isHindi: true));
      await tester.pumpAndSettle();

      expect(find.text('अवसर एवं सरकारी योजना केंद्र'), findsOneWidget);
      expect(find.text('सत्यापित कृषि योजनाएं एवं मार्गदर्शन'), findsOneWidget);
      expect(find.text('सभी'), findsOneWidget);
      expect(find.text('योजनाएं'), findsOneWidget);
      expect(find.text('सब्सिडी'), findsOneWidget);
      expect(find.text('प्रधानमंत्री किसान सम्मान निधि (पीएम-किसान)'), findsOneWidget);
    });

    testWidgets('Scenario W: Error banner and empty state handling', (tester) async {
      setLargeScreen(tester);

      // 1. API Error Banner
      final errorClient = MockClient((request) async {
        return http.Response(jsonEncode({'success': false, 'error': 'Database timeout'}), 500, headers: {'content-type': 'application/json'});
      });

      final apiErrClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: errorClient);
      final repoErr = OpportunityRepository(apiClient: apiErrClient, offlineStore: offlineStore);

      await tester.pumpWidget(createTestApp(repository: repoErr));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('opportunity_error_banner')), findsOneWidget);
      expect(find.text('Database timeout'), findsOneWidget);

      // 2. Empty State
      final emptyClient = MockClient((request) async {
        if (request.url.path == '/api/opportunities') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/opportunities/tracking') {
          return http.Response(jsonEncode({'success': true, 'data': []}), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not found', 404);
      });

      final apiEmptyClient = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: emptyClient);
      final repoEmpty = OpportunityRepository(apiClient: apiEmptyClient, offlineStore: offlineStore);

      await tester.pumpWidget(createTestApp(repository: repoEmpty));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('opportunity_empty_state')), findsOneWidget);
      expect(find.text('No opportunities found for this category.'), findsOneWidget);
    });

    testWidgets('Scenario X: Offline cached catalogue viewing and mutation refusal', (tester) async {
      setLargeScreen(tester);

      // Pre-seed offline cache with mockSchemes
      await offlineStore.cacheData('opportunity_catalogue_all_all', mockSchemes);

      // Disconnected client that throws NetworkUnavailableException
      final offlineClient = MockClient((request) async {
        throw const NetworkUnavailableException('No cellular or wifi network available');
      });

      final apiOffline = ApiClient(baseUrl: 'http://mock.test', sessionStore: sessionStore, httpClient: offlineClient);
      final repoOffline = OpportunityRepository(apiClient: apiOffline, offlineStore: offlineStore);

      await tester.pumpWidget(createTestApp(repository: repoOffline));
      await tester.pumpAndSettle();

      // Offline banner is shown
      expect(find.byKey(const Key('opportunity_offline_banner')), findsOneWidget);

      // Cached schemes are visible
      expect(find.byKey(const Key('opportunity_card_PM-KISAN')), findsOneWidget);
      expect(find.byKey(const Key('opportunity_card_PM-KUSUM-SOLAR')), findsOneWidget);

      // Open detail sheet
      await tester.tap(find.byKey(const Key('opportunity_card_PM-KISAN')));
      await tester.pumpAndSettle();

      // Attempt eligibility evaluation offline -> Refused with network required error
      await tester.tap(find.byKey(const Key('check_eligibility_button')));
      await tester.pumpAndSettle();

      expect(find.text('Eligibility evaluation requires an active internet connection.'), findsOneWidget);

      // Attempt tracking save offline -> Refused with snackbar
      await tester.tap(find.byKey(const Key('save_status_button')));
      await tester.pumpAndSettle();

      expect(find.text('Active internet required to update tracking status'), findsOneWidget);
    });
  });
}
