import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:farmer_app/core/voice_service.dart';
import 'package:farmer_app/data/assistant/assistant_context_builder.dart';
import 'package:farmer_app/data/assistant/field_assistant_engine.dart';
import 'package:farmer_app/data/providers/demo_farm_dataset.dart';
import 'package:farmer_app/domain/assistant_model.dart';
import 'package:farmer_app/screens/prahar_chat_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Assistant V2: Multi-turn Context & State Engine Tests', () {
    late FieldAssistantEngine engine;
    late FarmerAssistantContext context;

    setUp(() {
      engine = FieldAssistantEngine();
      context = AssistantContextBuilder.buildContext(
        profile: CanonicalDemoFarmDataset.profile,
        farm: CanonicalDemoFarmDataset.farmSetup,
        zones: CanonicalDemoFarmDataset.zones,
        alerts: CanonicalDemoFarmDataset.alerts,
        verifications: const [],
        opportunities: const [],
        language: 'en',
      );
    });

    test('Turn 1 (Specific Zone) -> Turn 2 (Follow-up) preserves referenced zone in session context', () async {
      const sessionId = 'session_test_multiturn_1';

      // Turn 1: Specific query about Zone 2
      final res1 = await engine.processQuery(
        'Why is Zone 2 getting dry?',
        context: context,
        language: 'en',
        sessionId: sessionId,
      );

      expect(res1.intent, AssistantIntent.hazardExplanation);
      expect(res1.referencedZone, 'DEMO-ZONE-02');
      expect(engine.getSessionActiveZone(sessionId), 'DEMO-ZONE-02');

      // Turn 2: Relative follow-up without mentioning Zone 2
      final res2 = await engine.processQuery(
        'What should I do?',
        context: context,
        language: 'en',
        sessionId: sessionId,
      );

      // Must resolve to Zone 2 via session context memory
      expect(res2.intent, AssistantIntent.recommendationExplanation);
      expect(res2.referencedZone, 'DEMO-ZONE-02');

      // Turn 3: Second follow-up
      final res3 = await engine.processQuery(
        'Has this happened before?',
        context: context,
        language: 'en',
        sessionId: sessionId,
      );

      expect(res3.referencedZone, 'DEMO-ZONE-02');
    });

    test('Language preservation: Hindi, Marathi, and Punjabi queries retain native response language', () async {
      const sessionId = 'session_lang_test_1';

      // Hindi
      final hiRes = await engine.processQuery(
        'खेत का हाल कैसा है?',
        context: context,
        language: 'hi',
        sessionId: sessionId,
      );
      expect(hiRes.intent, AssistantIntent.fieldStatus);
      expect(hiRes.answer.contains('खेत') || hiRes.answer.contains('ज़ोन'), isTrue);

      // Marathi
      final mrRes = await engine.processQuery(
        'शेताची माहिती',
        context: context,
        language: 'mr',
        sessionId: sessionId,
      );
      expect(mrRes.intent, AssistantIntent.fieldStatus);
      expect(mrRes.answer.contains('शेतात') || mrRes.answer.contains('झोन'), isTrue);

      // Punjabi
      final paRes = await engine.processQuery(
        'ਖੇਤ ਦੀ ਜਾਣਕਾਰੀ',
        context: context,
        language: 'pa',
        sessionId: sessionId,
      );
      expect(paRes.intent, AssistantIntent.fieldStatus);
      expect(paRes.answer.contains('ਖੇਤ') || paRes.answer.contains('ਜ਼ੋਨ'), isTrue);
    });

    test('Safety Gate: Irrigation requires confirmation, Spraying is strictly prohibited', () async {
      const sessionId = 'session_safety_test_1';

      // Irrigation request
      final irrigateRes = await engine.processQuery(
        'Start irrigation in Zone 2',
        context: context,
        language: 'en',
        sessionId: sessionId,
      );
      expect(irrigateRes.safetyLevel, AssistantSafetyLevel.requiresConfirmation);
      expect(irrigateRes.requiresConfirmation, isTrue);

      // Spraying request
      final sprayRes = await engine.processQuery(
        'Spray chemical pesticide in Zone 1',
        context: context,
        language: 'en',
        sessionId: sessionId,
      );
      expect(sprayRes.safetyLevel, AssistantSafetyLevel.prohibitedAutonomous);
      expect(sprayRes.requiresConfirmation, isFalse);
    });
  });

  group('Assistant V2: PraharChatScreen UI Tests', () {
    testWidgets('Renders full chat screen with distinct farmer & assistant bubbles, chips, and composer', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyContext = AssistantContextBuilder.buildContext(
        profile: CanonicalDemoFarmDataset.profile,
        farm: CanonicalDemoFarmDataset.farmSetup,
        zones: CanonicalDemoFarmDataset.zones,
        alerts: CanonicalDemoFarmDataset.alerts,
        verifications: const [],
        opportunities: const [],
        language: 'en',
      );

      await tester.pumpWidget(MaterialApp(
        home: PraharChatScreen(
          initialContext: dummyContext,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Verify App Bar & Title
      expect(find.text('PRAHAR Field Assistant'), findsOneWidget);
      expect(find.text('DEMO AGENT'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const Key('assistant_mic_button')), findsOneWidget);
      expect(find.byKey(const Key('assistant_send_button')), findsOneWidget);

      // Verify Context Banner Chips
      expect(find.text('4.2 Acres'), findsOneWidget);
      expect(find.text('4 Zones'), findsOneWidget);
      expect(find.text('3 Alerts'), findsOneWidget);

      // Verify Initial Greeting Message rendered
      expect(find.textContaining('I am your PRAHAR Field Assistant'), findsOneWidget);

      // Type a text query
      await tester.enterText(find.byKey(const Key('assistant_input_field')), 'Explain my field health');
      await tester.tap(find.byKey(const Key('assistant_send_button')));
      await tester.pumpAndSettle();

      // Verify user message appears on right and assistant message on left
      expect(find.text('Explain my field health'), findsOneWidget);
      expect(find.byKey(const Key('assistant_response_card')), findsOneWidget);
      expect(find.byKey(const Key('assistant_intent_chip')), findsOneWidget);
      expect(find.text('DEMO-ZONE-02'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);

      // Verify Listen / Audio control button is present
      expect(find.text('Listen'), findsWidgets);
    });

    testWidgets('Clear chat confirmation resets conversation', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final dummyContext = AssistantContextBuilder.buildContext(
        profile: CanonicalDemoFarmDataset.profile,
        farm: CanonicalDemoFarmDataset.farmSetup,
        zones: CanonicalDemoFarmDataset.zones,
        alerts: CanonicalDemoFarmDataset.alerts,
        verifications: const [],
        opportunities: const [],
        language: 'en',
      );

      await tester.pumpWidget(MaterialApp(
        home: PraharChatScreen(
          initialContext: dummyContext,
          initialLanguage: 'en',
        ),
      ));
      await tester.pumpAndSettle();

      // Send a message
      await tester.enterText(find.byKey(const Key('assistant_input_field')), 'How is my farm today?');
      await tester.tap(find.byKey(const Key('assistant_send_button')));
      await tester.pumpAndSettle();

      expect(find.text('How is my farm today?'), findsOneWidget);

      // Tap clear conversation button in App Bar
      await tester.tap(find.byTooltip('Clear Conversation'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('Clear Conversation?'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // User question should be cleared, greeting re-added
      expect(find.text('How is my farm today?'), findsNothing);
      expect(find.textContaining('I am your PRAHAR Field Assistant'), findsOneWidget);
    });

    test('VoiceService: STT Error Mapping & Multilingual Localization', () {
      // Permission denied
      expect(
        VoiceService.getLocalizedErrorMessage('PERMISSION_DENIED', 'en'),
        contains('Microphone permission is required'),
      );
      expect(
        VoiceService.getLocalizedErrorMessage('PERMISSION_DENIED', 'hi'),
        contains('माइक्रोफ़ोन की अनुमति आवश्यक है'),
      );
      expect(
        VoiceService.getLocalizedErrorMessage('PERMISSION_DENIED', 'mr'),
        contains('मायक्रोफोन परवानगी आवश्यक आहे'),
      );
      expect(
        VoiceService.getLocalizedErrorMessage('PERMISSION_DENIED', 'pa'),
        contains('ਮਾਈਕ੍ਰੋਫੋਨ ਦੀ ਇਜਾਜ਼ਤ ਲੋੜੀਂਦੀ ਹੈ'),
      );

      // No match
      expect(
        VoiceService.getLocalizedErrorMessage('NO_MATCH', 'en'),
        contains("couldn't hear that clearly"),
      );
      expect(
        VoiceService.getLocalizedErrorMessage('NO_MATCH', 'hi'),
        contains('आवाज़ स्पष्ट सुनाई नहीं दी'),
      );

      // Timeout
      expect(
        VoiceService.getLocalizedErrorMessage('TIMEOUT', 'en'),
        contains('Listening timed out'),
      );
      expect(
        VoiceService.getLocalizedErrorMessage('TIMEOUT', 'hi'),
        contains('समय समाप्त हो गया'),
      );

      // Language not supported
      expect(
        VoiceService.getLocalizedErrorMessage('LANGUAGE_NOT_SUPPORTED', 'hi'),
        contains('हिंदी वॉइस इनपुट उपलब्ध नहीं है'),
      );
      expect(
        VoiceService.getLocalizedErrorMessage('LANGUAGE_NOT_SUPPORTED', 'mr'),
        contains('मराठी व्हॉईस इनपुट उपलब्ध नाही'),
      );
      expect(
        VoiceService.getLocalizedErrorMessage('LANGUAGE_NOT_SUPPORTED', 'pa'),
        contains('ਪੰਜਾਬੀ ਵੌਇਸ ਇਨਪੁਟ ਉਪਲਬਧ ਨਹੀਂ ਹੈ'),
      );
    });
  });
}
