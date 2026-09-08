import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:farmer_app/core/api_client.dart';
import 'package:farmer_app/core/storage/offline_store.dart';
import 'package:farmer_app/core/storage/session_store.dart';
import 'package:farmer_app/domain/farmer_profile.dart';
import 'package:farmer_app/data/repositories/farmer_profile_repository.dart';
import 'package:farmer_app/screens/onboarding_screen.dart';

void main() {
  group('Phase 7A: Farmer Onboarding Wizard Tests', () {
    late InMemoryOfflineStore offlineStore;
    late InMemorySessionStore sessionStore;
    late FarmerProfileRepository profileRepository;

    setUp(() {
      offlineStore = InMemoryOfflineStore();
      sessionStore = InMemorySessionStore();
      final apiClient = ApiClient(sessionStore: sessionStore);
      profileRepository = FarmerProfileRepository(
        apiClient: apiClient,
        offlineStore: offlineStore,
      );
    });

    testWidgets('Step Navigation: cycles through 5 steps in order', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(
          profileRepository: profileRepository,
          sessionStore: sessionStore,
          offlineStore: offlineStore,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Step 0: Language Selection
      expect(find.byKey(const Key('lang_option_en')), findsOneWidget);
      expect(find.byKey(const Key('lang_option_hi')), findsOneWidget);
      expect(find.byKey(const Key('lang_option_mr')), findsOneWidget);
      expect(find.byKey(const Key('lang_option_pa')), findsOneWidget);

      // Tap Next -> Step 1: Farmer Profile
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('onboarding_name_field')), findsOneWidget);

      // Fill Name and proceed
      await tester.enterText(find.byKey(const Key('onboarding_name_field')), 'Ramesh Patil');
      await tester.enterText(find.byKey(const Key('onboarding_district_field')), 'Amravati');
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Step 2: Farm Details
      expect(find.byKey(const Key('onboarding_area_field')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('onboarding_area_field')), '4.2');
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Step 3: Crop Details
      expect(find.byKey(const Key('onboarding_crops_field')), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Step 4: Review & Confirm
      expect(find.byKey(const Key('finish_onboarding_button')), findsOneWidget);
      expect(find.textContaining('Ramesh Patil'), findsWidgets);
    });

    testWidgets('Quick-Fill Canonical Demo populates Ramesh Patil 4.2 acres in one tap', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(
          profileRepository: profileRepository,
          sessionStore: sessionStore,
          offlineStore: offlineStore,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Verify Quick-Fill Button exists
      expect(find.byKey(const Key('quick_fill_demo_button')), findsOneWidget);

      // Tap Quick-Fill
      await tester.tap(find.byKey(const Key('quick_fill_demo_button')));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Advance to review step
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Review step should display canonical Ramesh Patil data
      expect(find.byKey(const Key('finish_onboarding_button')), findsOneWidget);
      expect(find.textContaining('Ramesh Patil'), findsWidgets);
      expect(find.textContaining('Amravati'), findsWidgets);
      expect(find.textContaining('4.2'), findsWidgets);
      expect(find.textContaining('Soybean'), findsWidgets);
      expect(find.textContaining('Wheat'), findsWidgets);
    });

    testWidgets('Language selection persists preference and switches UI text', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(
          profileRepository: profileRepository,
          sessionStore: sessionStore,
          offlineStore: offlineStore,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Tap Hindi
      await tester.tap(find.byKey(const Key('lang_option_hi')));
      await tester.pumpAndSettle();

      // Verify Hindi title is displayed
      expect(find.text('पसंदीदा भाषा'), findsOneWidget);

      // Tap Marathi
      await tester.tap(find.byKey(const Key('lang_option_mr')));
      await tester.pumpAndSettle();
      expect(find.text('पसंतीची भाषा'), findsOneWidget);

      // Tap Punjabi
      await tester.tap(find.byKey(const Key('lang_option_pa')));
      await tester.pumpAndSettle();
      expect(find.text('ਪਸੰਦੀਦਾ ਭਾਸ਼ਾ'), findsOneWidget);
    });

    testWidgets('Persistence & Reload: Saved profile is restored from offline store', (tester) async {
      // 1. Save canonical demo profile to offline store
      final demoState = FarmerOnboardingState.canonicalDemo();
      await profileRepository.saveOnboardingState(demoState);

      // 2. Load state
      final loaded = await profileRepository.getOnboardingState();
      expect(loaded, isNotNull);
      expect(loaded.profile.name, 'Ramesh Patil');
      expect(loaded.profile.district, 'Amravati');
      expect(loaded.profile.state, 'Maharashtra');
      expect(loaded.farm.areaAcres, 4.2);
      expect(loaded.farm.ownershipType, 'OWNED');
      expect(loaded.farm.irrigationStatus, 'PARTIAL');
      expect(loaded.crops.mainCrops, containsAll(['Soybean', 'Wheat']));
      expect(loaded.isCompleted, isTrue);

      final isCompleted = await profileRepository.isOnboardingCompleted();
      expect(isCompleted, isTrue);
    });

    testWidgets('Validation: Required fields reject empty submission', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(MaterialApp(
        home: OnboardingScreen(
          profileRepository: profileRepository,
          sessionStore: sessionStore,
          offlineStore: offlineStore,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Go to Step 1 (Farmer Profile)
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Clear name field and submit
      await tester.enterText(find.byKey(const Key('onboarding_name_field')), '');
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      // Validation error shown, still on Step 1
      expect(find.text('Please enter farmer name'), findsOneWidget);
      expect(find.byKey(const Key('onboarding_name_field')), findsOneWidget);
    });
  });
}
