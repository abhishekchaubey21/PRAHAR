/// PRAHAR Phase 7B — Client-Side Field Assistant Engine
/// Provides offline-first processing, intent resolution, and safety gate dispatch

import '../../domain/assistant_model.dart';
import '../repositories/field_assistant_repository.dart';

class FieldAssistantEngine {
  final FieldAssistantRepository? _repository;

  // Local pending confirmation cache for two-stage safety
  final Map<String, AssistantPendingAction> _pendingConfirmations = {};

  FieldAssistantEngine({FieldAssistantRepository? repository}) : _repository = repository;

  Future<AssistantStructuredResponse> processQuery(
    String query, {
    required FarmerAssistantContext context,
    required String language,
    String? sessionId,
    bool? confirmAction,
    String? pendingActionId,
  }) async {
    final effectiveSessionId = sessionId ?? 'default_session';

    // 1. If remote repository is available, try remote query first
    final repo = _repository;
    if (repo != null) {
      try {
        final remote = await repo.queryAssistant(
          query: query,
          language: language,
          sessionId: effectiveSessionId,
          context: context,
          confirmAction: confirmAction,
          pendingActionId: pendingActionId,
        );
        if (remote.requiresConfirmation && remote.pendingAction != null) {
          _pendingConfirmations[effectiveSessionId] = remote.pendingAction!;
        }
        return remote;
      } catch (_) {
        // Fall back to local client processing on error / offline
      }
    }

    if (confirmAction == true) {
      final pending = _pendingConfirmations.remove(effectiveSessionId);
      final zone = pending?.zoneId ?? 'DEMO-ZONE-02';
      return AssistantStructuredResponse(
        answer: _translate(
          'SIMULATION ONLY: Irrigation action for $zone confirmed and executed. Dispatched to rover simulator.',
          'केवल सिम्युलेशन: $zone के लिए सिंचाई कार्रवाई की पुष्टि की गई और निष्पादित की गई।',
          'केवळ सिम्युलेशन: $zone साठी सिंचन कारवाईची पुष्टी केली आणि कार्यान्वित केली.',
          'ਸਿਰਫ਼ ਸਿਮੂਲੇਸ਼ਨ: ਸਿੰਚਾਈ ਕਾਰਵਾਈ ਦੀ ਪੁਸ਼ਟੀ ਕੀਤੀ ਗਈ।',
          language,
        ),
        intent: AssistantIntent.actionStatus,
        referencedZone: zone,
        severity: 'LOW',
        evidence: 'Simulated micro-irrigation dispatched following farmer confirmation.',
        recommendation: 'Monitor soil moisture response in 10 minutes.',
        requiresConfirmation: false,
        safetyLevel: AssistantSafetyLevel.safeInformational,
        simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
      );
    }

    if (confirmAction == false) {
      _pendingConfirmations.remove(effectiveSessionId);
      return AssistantStructuredResponse(
        answer: _translate(
          'Simulated action cancelled. No irrigation was executed.',
          'सिम्युलेटेड कार्रवाई रद्द कर दी गई। कोई सिंचाई नहीं की गई।',
          'सिम्युलेट केलेली कारवाई रद्द केली. कोणतीही सिंचन प्रक्रिया केली नाही.',
          'ਸਿਮੂਲੇਟ ਕੀਤੀ ਕਾਰਵਾਈ ਰੱਦ ਕੀਤੀ ਗਈ।',
          language,
        ),
        intent: AssistantIntent.actionStatus,
        referencedZone: 'DEMO-ZONE-02',
        severity: 'LOW',
        recommendation: 'You can query farm status or view other zones.',
        requiresConfirmation: false,
        safetyLevel: AssistantSafetyLevel.safeInformational,
        simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
      );
    }

    return process(
      query: query,
      language: language,
      context: context,
      sessionId: effectiveSessionId,
    );
  }

  Future<AssistantStructuredResponse> process({
    required String query,
    required String language,
    required FarmerAssistantContext context,
    String? sessionId,
  }) async {
    final effectiveSessionId = sessionId ?? 'default_session';

    // 1. Check if user is confirming or canceling a pending action
    if (_pendingConfirmations.containsKey(effectiveSessionId)) {
      final pending = _pendingConfirmations[effectiveSessionId]!;
      final text = query.trim().toLowerCase();

      if (_isAffirmative(text)) {
        _pendingConfirmations.remove(effectiveSessionId);
        return AssistantStructuredResponse(
          answer: _translate(
            'Simulated micro-irrigation dispatched for ${pending.zoneId}. 30-second cycle started in simulation mode. Physical rover is disconnected. Check Verification Status once complete.',
            '${pending.zoneId} के लिए सिम्युलेटेड सूक्ष्म-सिंचाई शुरू की गई। सिम्युलेशन मोड में 30 सेकंड का चक्र शुरू हुआ। भौतिक रोवर डिस्कनेक्ट है। पूरा होने पर सत्यापन स्थिति देखें।',
            '${pending.zoneId} साठी सिम्युलेटेड सूक्ष्म-सिंचन सुरू केले. सिम्युलेशन मोडमध्ये 30 सेकंद चक्र सुरू झाले. भौतिक रोव्हर डिस्कनेक्ट आहे.',
            '${pending.zoneId} ਲਈ ਸਿਮੂਲੇਟਿਡ ਸਿੰਚਾਈ ਸ਼ੁਰੂ ਕੀਤੀ ਗਈ। ਰੋਵਰ ਡਿਸਕਨੈਕਟ ਹੈ।',
            language,
          ),
          intent: AssistantIntent.actionStatus,
          referencedZone: pending.zoneId,
          severity: 'LOW',
          evidence: 'Action approved following explicit human confirmation. Safety limits applied (30s, 7.5L).',
          recommendation: 'Review post-action telemetry verification.',
          actionRequired: false,
          actionType: AssistantActionType.none,
          requiresConfirmation: false,
          safetyLevel: AssistantSafetyLevel.safeInformational,
          simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
        );
      }

      if (_isNegative(text)) {
        _pendingConfirmations.remove(effectiveSessionId);
        return AssistantStructuredResponse(
          answer: _translate(
            'Simulated action cancelled. No irrigation was executed.',
            'सिम्युलेटेड कार्रवाई रद्द कर दी गई। कोई सिंचाई नहीं की गई।',
            'सिम्युलेट केलेली कारवाई रद्द केली. कोणतीही सिंचन प्रक्रिया केली नाही.',
            'ਸਿਮੂਲੇਟ ਕੀਤੀ ਕਾਰਵਾਈ ਰੱਦ ਕੀਤੀ ਗਈ। ਕੋਈ ਸਿੰਚਾਈ ਨਹੀਂ ਕੀਤੀ ਗਈ।',
            language,
          ),
          intent: AssistantIntent.actionStatus,
          referencedZone: pending.zoneId,
          severity: 'LOW',
          recommendation: 'You can query farm status or view other zones.',
          actionRequired: false,
          actionType: AssistantActionType.none,
          requiresConfirmation: false,
          safetyLevel: AssistantSafetyLevel.safeInformational,
          simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
        );
      }
    }

    // 2. Try remote repository if available
    final repo = _repository;
    if (repo != null) {
      try {
        final remote = await repo.queryAssistant(
          query: query,
          language: language,
          sessionId: effectiveSessionId,
          context: context,
        );
        if (remote.requiresConfirmation && remote.pendingAction != null) {
          _pendingConfirmations[effectiveSessionId] = remote.pendingAction!;
        }
        return remote;
      } catch (_) {
        // Fall back to local client processing on error / offline
      }
    }

    // 3. Local Contextual Intelligence Fallback
    return _processLocally(query, language, context, effectiveSessionId);
  }

  AssistantStructuredResponse _processLocally(
    String rawQuery,
    String language,
    FarmerAssistantContext context,
    String sessionId,
  ) {
    final text = rawQuery.trim().toLowerCase();
    final intent = _classifyIntent(text);
    final targetZoneId = _resolveZoneId(text);

    switch (intent) {
      case AssistantIntent.fieldStatus:
        return AssistantStructuredResponse(
          answer: _translate(
            'The farm has 4 zones under monitoring with 3 active alert(s). Zone 2 (East Sector) needs attention first due to Water Stress (16.8% moisture). Zone 3 has a pest alert, and Zone 4 has nutrient deficiency. Rover telemetry is simulated (Physical Rover disconnected).',
            'खेत में 4 ज़ोन निगरानी में हैं जिनमें 3 सक्रिय अलर्ट हैं। ज़ोन 2 (पूर्वी खंड) पर जल तनाव (16.8% नमी) के कारण सबसे पहले ध्यान देने की आवश्यकता है। ज़ोन 3 में कीट और ज़ोन 4 में पोषक तत्व की कमी है।',
            'शेतात 4 झोन देखरेखीखाली असून 3 सक्रिय सूचना आहेत. पाण्याचा ताण (16.8% ओलावा) यामुळे झोन 2 ला प्राधान्य द्यावे.',
            'ਖੇਤ ਵਿੱਚ 4 ਜ਼ੋਨਾਂ ਦੀ ਨਿਗਰਾਨੀ ਕੀਤੀ ਜਾ ਰਹੀ ਹੈ ਅਤੇ 3 ਸਰਗਰਮ ਚੇਤਾਵਨੀਆਂ ਹਨ। ਜ਼ੋਨ 2 ਨੂੰ ਪਹਿਲ ਦੇਣ ਦੀ ਲੋੜ ਹੈ।',
            language,
          ),
          intent: AssistantIntent.fieldStatus,
          referencedZone: 'DEMO-ZONE-02',
          severity: 'HIGH',
          evidence: 'Zone 2 Moisture: 16.8% (Critical: <20.0%), Temp: 34.5°C. Zone 3: Spodoptera litura. Zone 4: Nitrogen chlorosis.',
          recommendation: 'Prioritize targeted micro-irrigation for Zone 2 to relieve water stress.',
          actionRequired: false,
          actionType: AssistantActionType.none,
          requiresConfirmation: false,
          safetyLevel: AssistantSafetyLevel.safeInformational,
          simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
        );

      case AssistantIntent.zoneStatus:
        return _handleZoneStatus(targetZoneId ?? 'DEMO-ZONE-02', language);

      case AssistantIntent.hazardExplanation:
        return _handleHazardExplanation(targetZoneId ?? 'DEMO-ZONE-02', language);

      case AssistantIntent.recommendationExplanation:
        return _handleRecommendationExplanation(targetZoneId ?? 'DEMO-ZONE-02', text, sessionId, language);

      case AssistantIntent.actionStatus:
        return AssistantStructuredResponse(
          answer: _translate(
            'Closed-loop Action History (Simulation Only): 1) ACT-DEMO-01: Micro-irrigation pulse in Zone 2 dispatched and verified. Physical Rover is Disconnected.',
            'कार्रवाई इतिहास (केवल सिम्युलेशन): 1) ACT-DEMO-01: ज़ोन 2 में सूक्ष्म-सिंचाई स्पंद भेजा गया और सत्यापित किया गया। भौतिक रोवर डिस्कनेक्ट है।',
            'कारवाई इतिहास (केवळ सिम्युलेशन): 1) ACT-DEMO-01: झोन 2 मध्ये सूक्ष्म-सिंचन पाठवले आणि सत्यापित केले. भौतिक रोव्हर डिस्कनेक्ट आहे.',
            'ਕਾਰਵਾਈ ਦਾ ਇਤਿਹਾਸ (ਸਿਰਫ਼ ਸਿਮੂਲੇਸ਼ਨ): 1) ਜ਼ੋਨ 2 ਵਿੱਚ ਸੂਖਮ-ਸਿੰਚਾਈ ਭੇਜੀ ਗਈ ਅਤੇ ਤਸਦੀਕ ਕੀਤੀ ਗਈ। ਰੋਵਰ ਡਿਸਕਨੈਕਟ ਹੈ।',
            language,
          ),
          intent: AssistantIntent.actionStatus,
          referencedZone: 'DEMO-ZONE-02',
          severity: 'LOW',
          evidence: 'Previous simulated action: Micro-irrigation 30s (7.5L). Moisture delta: +11.4%.',
          recommendation: 'Monitor current soil metrics before planning subsequent cycles.',
          actionRequired: false,
          actionType: AssistantActionType.none,
          requiresConfirmation: false,
          safetyLevel: AssistantSafetyLevel.safeInformational,
          simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
        );

      case AssistantIntent.verificationStatus:
        return AssistantStructuredResponse(
          answer: _translate(
            'Remediation Verification Complete: Soil moisture in Zone 2 improved from 16.8% to 28.2% (+11.4% delta) following simulated micro-irrigation. Water stress problem resolved.',
            'उपचार सत्यापन पूर्ण: सिम्युलेटेड सूक्ष्म-सिंचाई के बाद ज़ोन 2 में मिट्टी की नमी 16.8% से बढ़कर 28.2% (+11.4% अंतर) हो गई। जल तनाव की समस्या हल हो गई।',
            'उपचार पडताळणी पूर्ण: सिम्युलेटेड सूक्ष्म-सिंचनानंतर झोन 2 मध्ये मातीतील ओलावा 16.8% वरून 28.2% पर्यंत वाढला. पाण्याचा ताण सुटला.',
            'ਤਸਦੀਕ ਪੂਰੀ ਹੋਈ: ਜ਼ੋਨ 2 ਵਿੱਚ ਨਮੀ 16.8% ਤੋਂ ਵੱਧ ਕੇ 28.2% ਹੋ ਗਈ। ਸਮੱਸਿਆ ਹੱਲ ਹੋ ਗਈ।',
            language,
          ),
          intent: AssistantIntent.verificationStatus,
          referencedZone: 'DEMO-ZONE-02',
          severity: 'LOW',
          evidence: 'Pre-action: 16.8%, Post-action: 28.2%, Delta: +11.4%. Resolved: true.',
          recommendation: 'Schedule routine surveillance scan in 4 hours.',
          actionRequired: false,
          actionType: AssistantActionType.none,
          requiresConfirmation: false,
          safetyLevel: AssistantSafetyLevel.safeInformational,
          simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
        );

      case AssistantIntent.schemeQuery:
        return AssistantStructuredResponse(
          answer: _translate(
            'Eligible Government Schemes: 1) PM-KISAN: Direct income support of ₹6,000/yr for small/marginal farmers. 2) PMFBY: Comprehensive crop insurance against localized pest/moisture risks. 3) SMAM: 40-50% subsidy on precision farm equipment.',
            'पात्र सरकारी योजनाएं: 1) पीएम-किसान: छोटे और सीमांत किसानों के लिए ₹6,000/वर्ष प्रत्यक्ष आय सहायता। 2) पीएमएफबीवाई: कीट/सूखे के खिलाफ फसल बीमा। 3) स्माम: सटीक कृषि उपकरणों पर 40-50% सब्सिडी।',
            'पात्र शासकीय योजना: 1) पीएम-किसान: ₹6,000 वार्षिक उत्पन्न सहाय्य. 2) पीएमएफबीवाय: पीक विमा योजना. 3) स्माम: कृषी यांत्रिकीकरण अनुदान.',
            'ਯੋਗ ਸਰਕਾਰੀ ਸਕੀਮਾਂ: 1) ਪੀਐਮ-ਕਿਸਾਨ: ₹6,000 ਸਾਲਾਨਾ ਸਹਾਇਤਾ। 2) ਪੀਐਮਐਫਬੀਵਾਈ: ਫਸਲ ਬੀਮਾ ਯੋਜਨਾ। 3) ਸਮਾਮ: ਖੇਤੀ ਮਸ਼ੀਨਰੀ ਸਬਸਿਡੀ।',
            language,
          ),
          intent: AssistantIntent.schemeQuery,
          severity: 'NONE',
          evidence: 'Farmer Profile Matched: 4.2 Acres, Maharashtra, Kharif Soybean + Rabi Wheat, Owned land.',
          recommendation: 'Apply via the Opportunity & Scheme Center with your Aadhaar and Land 7/12 extract.',
          actionRequired: false,
          actionType: AssistantActionType.none,
          requiresConfirmation: false,
          safetyLevel: AssistantSafetyLevel.safeInformational,
          simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
          indicativeDisclaimer: 'Self-assessed indicative guidance. Final eligibility determined by official government portals.',
        );

      case AssistantIntent.profileQuery:
        return AssistantStructuredResponse(
          answer: _translate(
            'Farmer Profile: Ramesh Patil, Nandgaon Khandeshwar, Amravati, Maharashtra. Total Land: 4.2 Acres (Owned), Partially Irrigated via Borewell. Primary Crops: Soybean (Kharif) + Wheat (Rabi). Soil: Black Cotton Loam.',
            'किसान प्रोफ़ाइल: रमेश पाटिल, नंदगांव खंडेश्वर, अमरावती, महाराष्ट्र। कुल भूमि: 4.2 एकड़ (स्वामित्व), बोरवेल द्वारा आंशिक सिंचित। मुख्य फसलें: सोयाबीन (खरीफ) + गेहूं (रबी)।',
            'शेतकरी प्रोफाईल: रमेश पाटील, नांदगाव खंडेश्वर, अमरावती, महाराष्ट्र. एकूण जमीन: 4.2 एकर (स्वतःची मालकी), बोअरवेल द्वारे अंशतः सिंचित.',
            'ਕਿਸਾਨ ਪ੍ਰੋਫਾਈਲ: ਰਮੇਸ਼ ਪਾਟਿਲ, ਅਮਰਾਵਤੀ, ਮਹਾਰਾਸ਼ਟਰ। ਕੁੱਲ ਜ਼ਮੀਨ: 4.2 ਏਕੜ। ਮੁੱਖ ਫਸਲਾਂ: ਸੋਇਆਬੀਨ + ਕਣਕ।',
            language,
          ),
          intent: AssistantIntent.profileQuery,
          severity: 'NONE',
          evidence: 'Profile: Ramesh Patil • 4.2 Acres • Amravati, MH • Black Cotton Loam • Owned.',
          recommendation: 'Keep profile updated whenever crop variety or sowing date changes.',
          actionRequired: false,
          actionType: AssistantActionType.none,
          requiresConfirmation: false,
          safetyLevel: AssistantSafetyLevel.safeInformational,
          simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
        );

      case AssistantIntent.generalFarmGuidance:
        return AssistantStructuredResponse(
          answer: _translate(
            'Agronomic Best Practice: For Black Cotton Soil preparing for Kharif season, ensure deep summer ploughing (25-30 cm) to eliminate dormant pest pupae and improve monsoon moisture infiltration. Implement broad-bed furrow (BBF) systems for soybean.',
            'सटीक कृषि सलाह: खरीफ मौसम की तैयारी के लिए काली कपास मिट्टी में गहरी गर्मी की जुताई (25-30 सेमी) करें ताकि सुप्त कीट नष्ट हों और वर्षा जल का संचय बेहतर हो। सोयाबीन के लिए चौड़ी क्यारी-कूड़ (BBF) प्रणाली अपनाएं।',
            'कृषी सल्ला: काळ्या कापूस मातीमध्ये खरीप हंगामाच्या पूर्वतयारीसाठी खोल उन्हाळी नांगरणी (25-30 सेमी) करा. सोयाबीनसाठी रुंद गादीवाफा (BBF) पद्धत वापरा.',
            'ਖੇਤੀਬਾੜੀ ਸਲਾਹ: ਖਰੀਫ ਸੀਜ਼ਨ ਦੀ ਤਿਆਰੀ ਲਈ ਕਾਲੀ ਮਿੱਟੀ ਵਿੱਚ ਡੂੰਘੀ ਵਹਾਈ ਕਰੋ। ਸੋਇਆਬੀਨ ਲਈ ਚੌੜੀ ਕਿਆਰੀ ਵਿਧੀ ਅਪਣਾਓ।',
            language,
          ),
          intent: AssistantIntent.generalFarmGuidance,
          severity: 'LOW',
          evidence: 'Agronomic recommendation grounded in ICAR / KVK Vidarbha package of practices.',
          recommendation: 'Conduct soil test prior to basal fertilizer application.',
          actionRequired: false,
          actionType: AssistantActionType.none,
          requiresConfirmation: false,
          safetyLevel: AssistantSafetyLevel.safeInformational,
          simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
        );

      case AssistantIntent.unknown:
        return AssistantStructuredResponse(
          answer: _translate(
            'I am the PRAHAR Field Assistant. I can help with: 1) "Which zone needs attention first?", 2) "Why is Zone 2 under water stress?", 3) "What to do about pest in Zone 3?", 4) "Show irrigation verification", 5) "Relevant government schemes", or 6) "My farm profile".',
            'मैं प्रहार फील्ड सहायक हूँ। आप पूछ सकते हैं: 1) "खेत में सबसे बड़ी समस्या क्या है?", 2) "ज़ोन 2 में जल तनाव क्यों है?", 3) "ज़ोन 3 में कीट से कैसे निपटें?", 4) "सिंचाई के बाद क्या हुआ?", 5) "सरकारी योजनाएं", या 6) "मेरा प्रोफ़ाइल"।',
            'मी प्रहार फील्ड सहाय्यक आहे. मी पुढील प्रश्नांची उत्तरे देऊ शकतो: 1) "कोणत्या झोनवर लक्ष दिले पाहिजे?", 2) "झोन 2 मध्ये पाण्याचा ताण का आहे?", 3) "शासकीय योजना", किंवा 4) "माझे शेत प्रोफाईल".',
            'ਮੈਂ ਪ੍ਰਹਾਰ ਫੀਲਡ ਸਹਾਇਕ ਹਾਂ। ਤੁਸੀਂ ਪੁੱਛ ਸਕਦੇ ਹੋ: 1) "ਸਭ ਤੋਂ ਵੱਡੀ ਸਮੱਸਿਆ ਕੀ ਹੈ?", 2) "ਜ਼ੋਨ 2 ਵਿੱਚ ਪਾਣੀ ਦੀ ਕਮੀ ਕਿਉਂ ਹੈ?", 3) "ਸਰਕਾਰੀ ਯੋਜਨਾਵਾਂ"।',
            language,
          ),
          intent: AssistantIntent.unknown,
          severity: 'NONE',
          evidence: 'Query did not match supported agronomic intents.',
          recommendation: 'Select one of the suggested query chips above.',
          actionRequired: false,
          actionType: AssistantActionType.none,
          requiresConfirmation: false,
          safetyLevel: AssistantSafetyLevel.safeInformational,
          simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
        );
    }
  }

  AssistantStructuredResponse _handleZoneStatus(String zoneId, String language) {
    if (zoneId == 'DEMO-ZONE-01') {
      return AssistantStructuredResponse(
        answer: _translate(
          'Zone 1 (North Plot) is Healthy. Soil moisture is optimal at 32.4%, canopy temperature is 26.2°C, and no pests or nutrient stress detected.',
          'ज़ोन 1 (उत्तरी खंड) स्वस्थ है। मिट्टी की नमी 32.4% पर इष्टतम है, तापमान 26.2°C है, और कोई कीट या तनाव नहीं है।',
          'झोन 1 (उत्तर प्लॉट) निरोगी आहे. मातीतील ओलावा 32.4% उत्तम आहे आणि कोणतीही समस्या नाही.',
          'ਜ਼ੋਨ 1 (ਉੱਤਰ ਪਲਾਟ) ਤੰਦਰੁਸਤ ਹੈ। ਨਮੀ 32.4% ਹੈ ਅਤੇ ਕੋਈ ਕੀੜਾ ਨਹੀਂ ਹੈ।',
          language,
        ),
        intent: AssistantIntent.zoneStatus,
        referencedZone: 'DEMO-ZONE-01',
        severity: 'LOW',
        evidence: 'Moisture: 32.4%, Temp: 26.2°C, pH: 6.8. All metrics within normal range.',
        recommendation: 'Continue regular monitoring. Next scheduled scan in 6 hours.',
        actionRequired: false,
        actionType: AssistantActionType.none,
        requiresConfirmation: false,
        safetyLevel: AssistantSafetyLevel.safeInformational,
        simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
      );
    }

    if (zoneId == 'DEMO-ZONE-03') {
      return AssistantStructuredResponse(
        answer: _translate(
          'Zone 3 (South Sector) has an active Pest Alert. YOLOv8 detected Spodoptera litura (Tobacco Caterpillar) with 89% confidence. High humidity (74%) favors larvae growth.',
          'ज़ोन 3 (दक्षिण सेक्टर) में कीट चेतावनी सक्रिय है। YOLOv8 ने 89% विश्वास के साथ स्पोडोप्टेरा लिटुरा (तंबाकू इल्ली) की पहचान की है। 74% आर्द्रता कीट के अनुकूल है।',
          'झोन 3 (दक्षिण सेक्टर) मध्ये कीड इशारा सक्रिय आहे. 89% आत्मविश्वासाने स्पोडोप्टेरा लिटुरा कीड आढळली आहे.',
          'ਜ਼ੋਨ 3 (ਦੱਖਣ ਸੈਕਟਰ) ਵਿੱਚ ਕੀੜੇ ਦੀ ਚੇਤਾਵਨੀ ਹੈ। ਸਪੋਡੋਪਟੇਰਾ ਲਿਟੁਰਾ 89% ਭਰੋਸੇ ਨਾਲ ਪਾਇਆ ਗਿਆ।',
          language,
        ),
        intent: AssistantIntent.zoneStatus,
        referencedZone: 'DEMO-ZONE-03',
        severity: 'HIGH',
        evidence: 'Pest: Spodoptera litura (89% Confidence), RH: 74%, Soil: Silt Loam.',
        recommendation: 'Recommend localized organic Neem oil spray (1500 ppm). Do not spray autonomously.',
        actionRequired: false,
        actionType: AssistantActionType.none,
        requiresConfirmation: false,
        safetyLevel: AssistantSafetyLevel.safeInformational,
        simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
      );
    }

    if (zoneId == 'DEMO-ZONE-04') {
      return AssistantStructuredResponse(
        answer: _translate(
          'Zone 4 (West Sector) has Nutrient Deficiency. Nitrogen chlorosis observed, soil pH is 7.8, and moisture is 24.2%.',
          'ज़ोन 4 (पश्चिम सेक्टर) में पोषक तत्वों की कमी है। नाइट्रोजन क्लोरोसिस देखा गया, pH 7.8 है और नमी 24.2% है।',
          'झोन 4 (पश्चिम सेक्टर) मध्ये पोषक तत्वांची कमतरता आहे. नायट्रोजन क्लोरोसिस आढळले, pH 7.8 आहे.',
          'ਜ਼ੋਨ 4 (ਪੱਛਮੀ ਸੈਕਟਰ) ਵਿੱਚ ਪੋਸ਼ਕ ਤੱਤਾਂ ਦੀ ਘਾਟ ਹੈ। ਨਾਈਟ੍ਰੋਜਨ ਦੀ ਕਮੀ ਅਤੇ pH 7.8 ਹੈ।',
          language,
        ),
        intent: AssistantIntent.zoneStatus,
        referencedZone: 'DEMO-ZONE-04',
        severity: 'MEDIUM',
        evidence: 'Nitrogen chlorosis, pH: 7.8, Moisture: 24.2%.',
        recommendation: 'Apply split-dose urea foliar spray (2%) to normalize nutrient balance.',
        actionRequired: false,
        actionType: AssistantActionType.none,
        requiresConfirmation: false,
        safetyLevel: AssistantSafetyLevel.safeInformational,
        simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
      );
    }

    return AssistantStructuredResponse(
      answer: _translate(
        'Zone 2 (East Sector) status: High Water Stress. Soil moisture is 16.8%, below the 20% critical threshold. Canopy temperature is 34.5°C.',
        'ज़ोन 2 (पूर्वी सेक्टर) की स्थिति: गंभीर जल तनाव। मिट्टी की नमी 16.8% है, जो 20% की सीमा से कम है। तापमान 34.5°C है।',
        'झोन 2 (पूर्व सेक्टर) स्थिती: पाण्याचा गंभीर ताण. मातीतील ओलावा 16.8% आहे, जो 20% पेक्षा कमी आहे.',
        'ਜ਼ੋਨ 2 (ਪੂਰਬੀ ਸੈਕਟਰ) ਵਿੱਚ ਪਾਣੀ ਦੀ ਭਾਰੀ ਕਮੀ ਹੈ। ਨਮੀ 16.8% ਹੈ, ਤਾਪਮਾਨ 34.5°C ਹੈ।',
        language,
      ),
      intent: AssistantIntent.zoneStatus,
      referencedZone: 'DEMO-ZONE-02',
      severity: 'HIGH',
      evidence: 'Moisture: 16.8% (Threshold: <20.0%), Canopy Temp: 34.5°C, Sandy Loam.',
      recommendation: 'Targeted micro-irrigation cycle recommended to prevent permanent wilting.',
      actionRequired: true,
      actionType: AssistantActionType.irrigate,
      requiresConfirmation: true,
      safetyLevel: AssistantSafetyLevel.requiresConfirmation,
      simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
      pendingAction: const AssistantPendingAction(
        actionType: 'IRRIGATE',
        zoneId: 'DEMO-ZONE-02',
        durationSeconds: 30,
        volumeLiters: 7.5,
      ),
    );
  }

  AssistantStructuredResponse _handleHazardExplanation(String zoneId, String language) {
    if (zoneId == 'DEMO-ZONE-03') {
      return AssistantStructuredResponse(
        answer: _translate(
          'Reason for Alert in Zone 3: YOLOv8 model identified egg clusters and leaf damage from Fall Armyworm (Spodoptera litura). High relative humidity (74%) and warm temperatures created ideal conditions for pest infestation.',
          'ज़ोन 3 में अलर्ट का कारण: YOLOv8 मॉडल ने पत्तियों पर फॉल आर्मीवर्म (स्पोडोप्टेरा लिटुरा) के अंडे और क्षति की पहचान की। 74% आर्द्रता ने कीट के अनुकूल परिस्थितियां बनाईं।',
          'झोन 3 मधील अलर्टचे कारण: फॉल आर्मीवर्म किडीचे अस्तित्व शोधून काढले. उच्च आर्द्रता (74%) किडीच्या वाढीस पोषक ठरली आहे.',
          'ਜ਼ੋਨ 3 ਵਿੱਚ ਅਲਰਟ ਦਾ ਕਾਰਨ: ਫਾਲ ਆਰਮੀਵਰਮ ਕੀੜੇ ਦੀ ਪਛਾਣ ਕੀਤੀ। 74% ਨਮੀ ਨੇ ਕੀੜੇ ਦੇ ਫੈਲਾਅ ਵਿੱਚ ਮਦਦ ਕੀਤੀ।',
          language,
        ),
        intent: AssistantIntent.hazardExplanation,
        referencedZone: 'DEMO-ZONE-03',
        severity: 'HIGH',
        evidence: 'Pest Detection: Fall Armyworm (Confidence 89%), High Humidity (74%).',
        recommendation: 'Apply recommended bio-pesticide or pheromone traps. Never spray chemicals autonomously.',
        actionRequired: false,
        actionType: AssistantActionType.none,
        requiresConfirmation: false,
        safetyLevel: AssistantSafetyLevel.safeInformational,
        simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
      );
    }

    if (zoneId == 'DEMO-ZONE-04') {
      return AssistantStructuredResponse(
        answer: _translate(
          'Reason for Alert in Zone 4: Soil analysis indicates nitrogen deficiency resulting in chlorosis (leaf yellowing), with alkaline soil pH at 7.8.',
          'ज़ोन 4 में अलर्ट का कारण: मिट्टी के विश्लेषण से नाइट्रोजन की कमी का पता चला है, जिससे पत्तियों में पीलापन आ गया है और मिट्टी का pH 7.8 है।',
          'झोन 4 मधील अलर्टचे कारण: माती परीक्षणात नायट्रोजनची कमतरता आढळली आहे.',
          'ਜ਼ੋਨ 4 ਵਿੱਚ ਅਲਰਟ ਦਾ ਕਾਰਨ: ਮਿੱਟੀ ਵਿੱਚ ਨਾਈਟ੍ਰੋਜਨ ਦੀ ਘਾਟ ਹੈ।',
          language,
        ),
        intent: AssistantIntent.hazardExplanation,
        referencedZone: 'DEMO-ZONE-04',
        severity: 'MEDIUM',
        evidence: 'Chlorosis observed, pH 7.8, N deficiency.',
        recommendation: 'Apply split-dose urea foliar spray (2%) and organic compost.',
        actionRequired: false,
        actionType: AssistantActionType.none,
        requiresConfirmation: false,
        safetyLevel: AssistantSafetyLevel.safeInformational,
        simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
      );
    }

    return AssistantStructuredResponse(
      answer: _translate(
        'Reason for Water Stress in Zone 2: Soil moisture has dropped to 16.8% (safety threshold is 20.0%) combined with high ambient heat (34.5°C) in sandy loam soil, accelerating transpiration and root zone dehydration.',
        'ज़ोन 2 में जल तनाव का कारण: तेज गर्मी (34.5°C) के साथ मिट्टी की नमी घटकर 16.8% रह गई है (सुरक्षा सीमा 20.0% है), जिससे जड़ों का तनाव बढ़ गया है।',
        'झोन 2 मधील पाण्याचा ताण येण्याचे कारण: उष्णतेमुळे (34.5°C) ओलावा 16.8% पर्यंत घसरला आहे (मर्यादा 20.0% आहे).',
        'ਜ਼ੋਨ 2 ਵਿੱਚ ਪਾਣੀ ਦੀ ਕਮੀ ਦਾ ਕਾਰਨ: ਤੇਜ਼ ਗਰਮੀ ਕਾਰਨ ਮਿੱਟੀ ਦੀ ਨਮੀ ਘੱਟ ਕੇ 16.8% ਰਹਿ ਗਈ ਹੈ।',
        language,
      ),
      intent: AssistantIntent.hazardExplanation,
      referencedZone: 'DEMO-ZONE-02',
      severity: 'HIGH',
      evidence: 'Observed Moisture: 16.8% vs Threshold: 20.0%. Temp: 34.5°C, Soil: Sandy Loam.',
      recommendation: 'Targeted micro-irrigation for 30 seconds delivers ~7.5L to revive root zone without water wastage.',
      actionRequired: true,
      actionType: AssistantActionType.irrigate,
      requiresConfirmation: true,
      safetyLevel: AssistantSafetyLevel.requiresConfirmation,
      simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
      pendingAction: const AssistantPendingAction(
        actionType: 'IRRIGATE',
        zoneId: 'DEMO-ZONE-02',
        durationSeconds: 30,
        volumeLiters: 7.5,
      ),
    );
  }

  AssistantStructuredResponse _handleRecommendationExplanation(
    String zoneId,
    String text,
    String sessionId,
    String language,
  ) {
    if (text.contains('spray') || text.contains('कीटनाशक') || text.contains('फवारणी') || text.contains('ਛਿੜਕਾਅ')) {
      return AssistantStructuredResponse(
        answer: _translate(
          'SAFETY POLICY ENFORCEMENT: Autonomous chemical spraying is strictly PROHIBITED by PRAHAR safety rules. All pesticide applications require manual review and physical certification by local agricultural authorities (KVK).',
          'सुरक्षा नीति: प्रहार सुरक्षा नियमों के तहत स्वायत्त रासायनिक छिड़काव सख्त वर्जित है। सभी कीटनाशक प्रयोगों के लिए कृषि विज्ञान केंद्र (KVK) से भौतिक सत्यापन अनिवार्य है।',
          'सुरक्षा धोरण: प्रहार नियमांनुसार स्वायत्त रासायनिक फवारणीस सक्त मनाई आहे. स्थानिक तज्ज्ञांच्या सल्ल्यानेच मॅन्युअल फवारणी करावी.',
          'ਸੁਰੱਖਿਆ ਨੀਤੀ: ਖੁਦਮੁਖਤਿਆਰੀ ਕੀਟਨਾਸ਼ਕ ਛਿੜਕਾਅ ਦੀ ਸਖ਼ਤ ਮਨਾਹੀ ਹੈ। ਸਿਰਫ਼ ਮੈਨੂਅਲ ਪ੍ਰਮਾਣੀਕਰਣ ਦੀ ਆਗਿਆ ਹੈ।',
          language,
        ),
        intent: AssistantIntent.recommendationExplanation,
        referencedZone: 'DEMO-ZONE-03',
        severity: 'HIGH',
        evidence: 'Autonomous chemical actuator command blocked by PRAHAR Safety Gate.',
        recommendation: 'Use non-chemical traps or consult local Krishi Vigyan Kendra extension officer.',
        actionRequired: false,
        actionType: AssistantActionType.none,
        requiresConfirmation: false,
        safetyLevel: AssistantSafetyLevel.prohibitedAutonomous,
        simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
      );
    }

    final isActionRequest = text.contains('start') ||
        text.contains('irrigate') ||
        text.contains('do') ||
        text.contains('सिंचाई करो') ||
        text.contains('पानी दो') ||
        text.contains('सिंचन करा') ||
        text.contains('ਸਿੰਚਾਈ ਕਰੋ');

    if (isActionRequest) {
      _pendingConfirmations[sessionId] = AssistantPendingAction(
        actionType: 'IRRIGATE',
        zoneId: zoneId,
        durationSeconds: 30,
        volumeLiters: 7.5,
      );

      return AssistantStructuredResponse(
        answer: _translate(
          'You requested a 30-second simulated micro-irrigation (~7.5L) for $zoneId. Because PRAHAR enforces a strict multi-stage safety gate, please confirm by checking the box and clicking \'Confirm Action\' (or reply \'Yes\').',
          'आपने $zoneId के लिए 30 सेकंड की सिम्युलेटेड सूक्ष्म-सिंचाई (~7.5L) का अनुरोध किया है। प्रहार सुरक्षा द्वार के अनुसार, कृपया चेकबॉक्स चुनकर \'पुष्टि करें\' बटन दबाएं (या \'हाँ\' कहें)।',
          'तुम्ही $zoneId साठी 30 सेकंदांच्या सिम्युलेटेड सूक्ष्म-सिंचनाची विनंती केली आहे. कृपया पुष्टी करण्यासाठी \'होय\' म्हणा किंवा चेकबॉक्स निवडा.',
          'ਤੁਸੀਂ $zoneId ਲਈ 30 ਸਕਿੰਟ ਦੀ ਸਿਮੂਲੇਟਿਡ ਸਿੰਚਾਈ ਦੀ ਬੇਨਤੀ ਕੀਤੀ ਹੈ। ਕਿਰਪਾ ਕਰਕੇ ਪੁਸ਼ਟੀ ਕਰੋ।',
          language,
        ),
        intent: AssistantIntent.recommendationExplanation,
        referencedZone: zoneId,
        severity: 'HIGH',
        evidence: 'Action requested through Assistant: Micro-irrigation 30s (~7.5L).',
        recommendation: 'Secondary human confirmation required before dispatching simulation.',
        actionRequired: true,
        actionType: AssistantActionType.irrigate,
        requiresConfirmation: true,
        safetyLevel: AssistantSafetyLevel.requiresConfirmation,
        simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
        pendingAction: AssistantPendingAction(
          actionType: 'IRRIGATE',
          zoneId: zoneId,
          durationSeconds: 30,
          volumeLiters: 7.5,
        ),
      );
    }

    return AssistantStructuredResponse(
      answer: _translate(
        'Recommended action for $zoneId: Apply split-dose urea foliar spray (2%) and gypsum amendment to correct nutrient deficiency and normalize pH.',
        '$zoneId के लिए अनुशंसित कार्रवाई: पोषक तत्वों की कमी को दूर करने के लिए 2% यूरिया पर्णीय छिड़काव करें।',
        '$zoneId साठी शिफारस केलेली कृती: 2% युरिया फवारणी करावी.',
        '$zoneId ਲਈ ਸਿਫਾਰਸ਼ ਕੀਤੀ ਕਾਰਵਾਈ: 2% ਯੂਰੀਆ ਸਪਰੇਅ ਕਰੋ।',
        language,
      ),
      intent: AssistantIntent.recommendationExplanation,
      referencedZone: zoneId,
      severity: 'MEDIUM',
      evidence: 'Nutrient Deficiency in Zone 4 (Wheat).',
      recommendation: 'Apply split-dose urea foliar spray (2%) in the morning hours.',
      actionRequired: false,
      actionType: AssistantActionType.none,
      requiresConfirmation: false,
      safetyLevel: AssistantSafetyLevel.safeInformational,
      simulationStatus: 'SIMULATION ONLY • Physical Rover Disconnected',
    );
  }

  AssistantIntent _classifyIntent(String text) {
    if (text.contains('scheme') ||
        text.contains('योजना') ||
        text.contains('सब्सिडी') ||
        text.contains('subsidy') ||
        text.contains('pm kisan') ||
        text.contains('pm-kisan') ||
        text.contains('pmfby') ||
        text.contains('fasal bima') ||
        text.contains('ਸਕੀਮ')) {
      return AssistantIntent.schemeQuery;
    }
    if (text.contains('profile') ||
        text.contains('प्रोफ़ाइल') ||
        text.contains('प्रोफाइल') ||
        text.contains('who am i') ||
        text.contains('how many acres') ||
        text.contains('acres') ||
        text.contains('एकड़') ||
        text.contains('माझी जमीन') ||
        text.contains('माझे शेत') ||
        text.contains('ਕਿੰਨੀ ਜ਼ਮੀਨ')) {
      return AssistantIntent.profileQuery;
    }
    if (text.contains('after') ||
        text.contains('happened') ||
        text.contains('verification') ||
        text.contains('resolved') ||
        text.contains('solved') ||
        text.contains('बाद') ||
        text.contains('सत्यापन') ||
        text.contains('सत्यापित') ||
        text.contains('हल') ||
        text.contains('निकाला') ||
        text.contains('ਬਾਅਦ ਕੀ ਹੋਇਆ')) {
      return AssistantIntent.verificationStatus;
    }
    if (text.contains('action') ||
        text.contains('actions') ||
        text.contains('history') ||
        text.contains('running') ||
        text.contains('कार्यवाही') ||
        text.contains('कार्रवाई') ||
        text.contains('कृती') ||
        text.contains('चल रही है')) {
      return AssistantIntent.actionStatus;
    }
    if (text.contains('spray') ||
        text.contains('कीटनाशक') ||
        text.contains('फवारणी') ||
        text.contains('ਛਿੜਕਾਅ') ||
        text.contains('what should i do') ||
        text.contains('recommend') ||
        text.contains('deficiency') ||
        text.contains('सलाह') ||
        text.contains('उपाय') ||
        text.contains('क्या करना चाहिए') ||
        text.contains('काय करावे') ||
        text.contains('ਕੀ ਕਰਨਾ ਚਾਹੀਦਾ') ||
        text.contains('क्या अभी सिंचाई') ||
        text.contains('irrigate') ||
        text.contains('start')) {
      return AssistantIntent.recommendationExplanation;
    }
    if (text.contains('why') ||
        text.contains('hazard') ||
        text.contains('pest') ||
        text.contains('कीट') ||
        text.contains('कीड') ||
        text.contains('spodoptera') ||
        text.contains('कारण') ||
        text.contains('क्यों') ||
        text.contains('का आहे') ||
        text.contains('ਕਿਉਂ')) {
      return AssistantIntent.hazardExplanation;
    }
    if (text.contains('zone 1') ||
        text.contains('zone 2') ||
        text.contains('zone 3') ||
        text.contains('zone 4') ||
        text.contains('north plot') ||
        text.contains('east sector') ||
        text.contains('south sector') ||
        text.contains('west sector') ||
        text.contains('ज़ोन 1') ||
        text.contains('ज़ोन 2') ||
        text.contains('ज़ोन 3') ||
        text.contains('ज़ोन 4') ||
        text.contains('झोन')) {
      return AssistantIntent.zoneStatus;
    }
    if (text.contains('guidance') ||
        text.contains('farming') ||
        text.contains('prepare') ||
        text.contains('soil') ||
        text.contains('kharif') ||
        text.contains('rabi') ||
        text.contains('season') ||
        text.contains('खेती') ||
        text.contains('बुवाई') ||
        text.contains('मशागत')) {
      return AssistantIntent.generalFarmGuidance;
    }
    if (text.contains('problem') ||
        text.contains('attention') ||
        text.contains('status') ||
        text.contains('farm') ||
        text.contains('field') ||
        text.contains('समस्या') ||
        text.contains('खेत') ||
        text.contains('हाल') ||
        text.contains('स्थिति') ||
        text.contains('ਕਿਹੜਾ ਜ਼ੋਨ')) {
      return AssistantIntent.fieldStatus;
    }
    return AssistantIntent.unknown;
  }

  String? _resolveZoneId(String text) {
    if (text.contains('zone 1') || text.contains('north') || text.contains('ज़ोन 1') || text.contains('उत्तर')) {
      return 'DEMO-ZONE-01';
    }
    if (text.contains('zone 2') ||
        text.contains('east') ||
        text.contains('water stress') ||
        text.contains('जल तनाव') ||
        text.contains('पूर्व') ||
        text.contains('ज़ोन 2')) {
      return 'DEMO-ZONE-02';
    }
    if (text.contains('zone 3') ||
        text.contains('south') ||
        text.contains('pest') ||
        text.contains('कीट') ||
        text.contains('spodoptera') ||
        text.contains('दक्षिण') ||
        text.contains('ज़ोन 3')) {
      return 'DEMO-ZONE-03';
    }
    if (text.contains('zone 4') ||
        text.contains('west') ||
        text.contains('nutrient') ||
        text.contains('nitrogen') ||
        text.contains('पोषण') ||
        text.contains('पश्चिम') ||
        text.contains('ज़ोन 4')) {
      return 'DEMO-ZONE-04';
    }
    return null;
  }

  bool _isAffirmative(String text) {
    return text.contains('yes') ||
        text.contains('confirm') ||
        text.contains('हाँ') ||
        text.contains('करो') ||
        text.contains('स्वीकार') ||
        text.contains('होय') ||
        text.contains('करा') ||
        text.contains('ਹਾਂ');
  }

  bool _isNegative(String text) {
    return text.contains('no') ||
        text.contains('cancel') ||
        text.contains('नहीं') ||
        text.contains('रद्द') ||
        text.contains('मत करो') ||
        text.contains('नाही') ||
        text.contains('ਨਹੀਂ');
  }

  String _translate(String en, String hi, String mr, String pa, String lang) {
    switch (lang) {
      case 'hi':
        return hi;
      case 'mr':
        return mr;
      case 'pa':
        return pa;
      case 'en':
      default:
        return en;
    }
  }
}
