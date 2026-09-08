/// PRAHAR Farmer App — Scalable Multilingual Localization Foundation
/// Aligned with Phase 7A: Supports English (en), Hindi (hi), Marathi (mr), and Punjabi (pa).
/// Provides centralized strings, fallback chains, and clean migration architecture.

class AppLocalizations {
  final String languageCode;

  const AppLocalizations(this.languageCode);

  static const List<String> supportedLanguages = ['en', 'hi', 'mr', 'pa'];

  static const Map<String, String> languageDisplayNames = {
    'en': 'English',
    'hi': 'हिन्दी',
    'mr': 'मराठी',
    'pa': 'ਪੰਜਾਬੀ',
  };

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // General & Common
      'app_name': 'PRAHAR',
      'app_tagline': 'Farmer Precision Advisory',
      'continue_btn': 'Continue',
      'back_btn': 'Back',
      'finish_btn': 'Finish Setup & Go to Home',
      'save_btn': 'Save Changes',
      'cancel_btn': 'Cancel',
      'skip_btn': 'Skip for Now',
      'quick_fill_demo_btn': 'Quick-Fill Canonical Demo (Ramesh Patil • 4.2 Acres)',
      'load_demo_btn': 'Load Demo Farm',
      'edit_profile_btn': 'Edit Farm Profile',
      'view_profile_title': 'Farmer Profile & Farm Setup',

      // Onboarding Steps
      'step_language_title': 'Preferred Language',
      'step_language_desc': 'Choose your primary language for voice and dashboard advisory.',
      'step_profile_title': 'Farmer Identity',
      'step_profile_desc': 'Tell us about yourself to personalize agronomic and scheme advisories.',
      'step_farm_title': 'Farm Details',
      'step_farm_desc': 'Specify your landholding size, tenancy, and irrigation facilities.',
      'step_crop_title': 'Crop & Sowing Details',
      'step_crop_desc': 'Select your cultivated crops and seasonal schedule.',
      'step_review_title': 'Review & Confirm',
      'step_review_desc': 'Confirm your profile details to initialize PRAHAR field intelligence.',

      // Farmer Profile Fields
      'farmer_name_label': 'Full Name',
      'farmer_name_hint': 'e.g. Ramesh Patil',
      'state_label': 'State',
      'state_hint': 'Select your state',
      'district_label': 'District',
      'district_hint': 'e.g. Amravati',
      'village_label': 'Village / Location',
      'village_hint': 'e.g. Nandgaon Khandeshwar',

      // Farm Fields
      'land_area_label': 'Land Area (in Acres)',
      'land_area_hint': 'e.g. 4.2',
      'ownership_label': 'Land Ownership Type',
      'ownership_owned': 'Owned (Self)',
      'ownership_tenant': 'Leased / Tenant',
      'ownership_sharecropper': 'Sharecropper (Bataidar)',
      'irrigation_label': 'Irrigation Availability',
      'irrigation_irrigated': 'Fully Irrigated',
      'irrigation_partial': 'Partially Irrigated',
      'irrigation_rainfed': 'Rainfed (Unirrigated)',
      'water_source_label': 'Primary Water Source',
      'water_borewell': 'Borewell / Tubewell',
      'water_canal': 'Canal',
      'water_open_well': 'Open Well',
      'water_river': 'River / Stream',
      'water_rainfed': 'Rainwater Harvesting / Rainfed',
      'soil_type_label': 'Predominant Soil Type',

      // Crop Fields
      'crops_label': 'Main Crops',
      'crops_hint': 'e.g. Soybean, Wheat, Cotton',
      'season_label': 'Agricultural Season',
      'season_kharif': 'Kharif (Monsoon)',
      'season_rabi': 'Rabi (Winter)',
      'season_zaid': 'Zaid (Summer)',
      'season_year_round': 'Year-Round (Annual)',
      'variety_label': 'Crop Variety (Optional)',
      'variety_hint': 'e.g. JS 335 / GW 322',
      'sowing_date_label': 'Sowing Date (Optional)',

      // Demo & Simulation Labels (Strict Clarity)
      'demo_field_data_badge': 'DEMO FIELD DATA',
      'simulated_rover_badge': 'SIMULATED ROVER TELEMETRY',
      'simulated_action_label': 'SIMULATED ACTION',
      'software_backend_online': 'Software Backend: Online',
      'software_backend_offline': 'Software Backend: Offline Mode (Local Cache)',
      'physical_rover_status': 'Physical Rover: Disconnected (Simulation Benchmark)',
      'demo_banner_subtitle': 'Demonstrating PRAHAR precision analytics using deterministic benchmark data.',
      'demo_ai_model_notice': 'Demo AI Detection • YOLOv8-compatible scenario',

      // Rover Telemetry Card
      'rover_card_title': 'SIMULATED ROVER TELEMETRY',
      'rover_id_label': 'Rover ID',
      'battery_label': 'Battery',
      'rover_state_label': 'State',
      'gps_label': 'Simulated GPS',
      'coverage_label': 'Field Coverage',

      // Zone Statuses
      'monitored_zones': 'Monitored Zones',
      'zone1_name': 'Zone 1 — North Plot (Soybean Healthy)',
      'zone2_name': 'Zone 2 — East Sector (Soybean Water Stress)',
      'zone3_name': 'Zone 3 — South Sector (Wheat Pest Alert)',
      'zone4_name': 'Zone 4 — West Sector (Wheat Nutrient Deficiency)',
      'zone_status_optimal': 'OPTIMAL',
      'zone_status_water_stress': 'WATER STRESS',
      'zone_status_pest_alert': 'PEST ALERT',
      'zone_status_nutrient_deficiency': 'NUTRIENT DEFICIENCY',

      // Remediation & Actions
      'approve_simulated_irrigation': 'Approve Simulated Micro-Irrigation (30s)',
      'simulated_irrigation_dispatched': 'Simulated micro-irrigation dispatched (30s). Safety Gate satisfied.',
      'simulated_remediation_verified': 'Simulated Remediation Verified (Closed-Loop Demo)',
      'resolved_badge': 'RESOLVED',

      // Opportunity Center
      'opportunity_center_title': 'Opportunity & Scheme Center',
      'indicative_eligibility_badge': 'Self-Assessed Indicative Guidance',
      'official_portal_source': 'Official Government Source',
      'matching_criteria_label': 'Matched Criteria',
      'missing_info_label': 'Missing Profile Information',

      // Phase 7B: PRAHAR Field Assistant
      'assistant_title': 'PRAHAR Field Assistant',
      'assistant_tagline': 'Context-Aware Agricultural Intelligence',
      'assistant_btn': 'PRAHAR Assistant',
      'assistant_query_hint': 'Ask about zones, water stress, pests, schemes...',
      'assistant_chip_attention': 'What needs attention first?',
      'assistant_chip_stress': 'Why is Zone 2 stressed?',
      'assistant_chip_pest': 'Pest guidance for South Sector?',
      'assistant_chip_schemes': 'Relevant government schemes?',
      'assistant_chip_verification': 'What happened after irrigation?',
      'assistant_chip_profile': 'My farm profile & acres',
      'assistant_confirm_action': 'Confirm Simulated Action',
      'assistant_safety_badge': 'SAFETY GATE: Confirmation required',
      'assistant_simulation_banner': 'DEMO MODE • Physical Rover Disconnected',
    },

    'hi': {
      // General & Common
      'app_name': 'प्रहार',
      'app_tagline': 'किसान सटीक कृषि परामर्श',
      'continue_btn': 'आगे बढ़ें',
      'back_btn': 'पीछे',
      'finish_btn': 'सेटअप पूरा करें एवं होम पर जाएं',
      'save_btn': 'परिवर्तन सहेजें',
      'cancel_btn': 'रद्द करें',
      'skip_btn': 'अभी छोड़ें',
      'quick_fill_demo_btn': 'डेमो डेटा स्वतः भरें (रमेश पाटिल • 4.2 एकड़)',
      'load_demo_btn': 'डेमो खेत लोड करें',
      'edit_profile_btn': 'खेत प्रोफ़ाइल संपादित करें',
      'view_profile_title': 'किसान प्रोफ़ाइल एवं खेत विवरण',

      // Onboarding Steps
      'step_language_title': 'पसंदीदा भाषा',
      'step_language_desc': 'आवाज़ और डैशबोर्ड परामर्श के लिए अपनी प्राथमिक भाषा चुनें।',
      'step_profile_title': 'किसान पहचान',
      'step_profile_desc': 'सटीक सलाह और सरकारी योजना हेतु अपने बारे में बताएं।',
      'step_farm_title': 'खेत का विवरण',
      'step_farm_desc': 'अपनी भूमि का क्षेत्रफल, स्वामित्व और सिंचाई की जानकारी दें।',
      'step_crop_title': 'फसल एवं बुवाई विवरण',
      'step_crop_desc': 'अपनी मुख्य फसलें और मौसमी कार्यक्रम चुनें।',
      'step_review_title': 'पुष्टि एवं समीक्षा',
      'step_review_desc': 'प्रहार खेत बुद्धिमत्ता सक्रिय करने हेतु अपने विवरण की पुष्टि करें।',

      // Farmer Profile Fields
      'farmer_name_label': 'पूरा नाम',
      'farmer_name_hint': 'उदा. रमेश पाटिल',
      'state_label': 'राज्य',
      'state_hint': 'अपना राज्य चुनें',
      'district_label': 'ज़िला',
      'district_hint': 'उदा. अमरावती',
      'village_label': 'गाँव / स्थान',
      'village_hint': 'उदा. नांदगांव खंडेश्वर',

      // Farm Fields
      'land_area_label': 'कुल भूमि (एकड़ में)',
      'land_area_hint': 'उदा. 4.2',
      'ownership_label': 'भूमि स्वामित्व प्रकार',
      'ownership_owned': 'खुद की (मालिक)',
      'ownership_tenant': 'किरायेदार (पट्टा)',
      'ownership_sharecropper': 'बटाईदार',
      'irrigation_label': 'सिंचाई सुविधा',
      'irrigation_irrigated': 'पूर्ण सिंचित',
      'irrigation_partial': 'आंशिक सिंचित',
      'irrigation_rainfed': 'असिंचित (बारानी)',
      'water_source_label': 'सिंचाई जल का मुख्य स्रोत',
      'water_borewell': 'बोरवेल / नलकूप',
      'water_canal': 'नहर',
      'water_open_well': 'खुला कुआं',
      'water_river': 'नदी / नाला',
      'water_rainfed': 'वर्षा जल / केवल वर्षा',
      'soil_type_label': 'मिट्टी का प्रकार',

      // Crop Fields
      'crops_label': 'मुख्य फसलें',
      'crops_hint': 'उदा. सोयाबीन, गेहूं, कपास',
      'season_label': 'कृषि मौसम',
      'season_kharif': 'खरीफ (मानसून)',
      'season_rabi': 'रबी (शीतकालीन)',
      'season_zaid': 'जायद (गर्मी)',
      'season_year_round': 'वार्षिक',
      'variety_label': 'फसल किस्म (वैकल्पिक)',
      'variety_hint': 'उदा. जेएस 335 / जीडब्ल्यू 322',
      'sowing_date_label': 'बुवाई की तारीख (वैकल्पिक)',

      // Demo & Simulation Labels
      'demo_field_data_badge': 'डेमो खेत डेटा',
      'simulated_rover_badge': 'सिमुलेटेड रोवर टेलीमेट्री',
      'simulated_action_label': 'सिमुलेटेड कार्रवाई',
      'software_backend_online': 'सॉफ्टवेयर बैकएंड: ऑनलाइन',
      'software_backend_offline': 'सॉफ्टवेयर बैकएंड: ऑफ़लाइन मोड (लोकल कैश)',
      'physical_rover_status': 'भौतिक रोवर: डिस्कनेक्टेड (सिमुलेशन बेंचमार्क)',
      'demo_banner_subtitle': 'प्रहार सटीकता विश्लेषण केवल बेंचमार्क डेटा पर प्रदर्शित किया जा रहा है।',
      'demo_ai_model_notice': 'डेमो एआई पहचान • YOLOv8-संगत परिदृश्य',

      // Rover Telemetry Card
      'rover_card_title': 'सिमुलेटेड रोवर टेलीमेट्री',
      'rover_id_label': 'रोवर आईडी',
      'battery_label': 'बैटरी',
      'rover_state_label': 'स्थिति',
      'gps_label': 'सिमुलेटेड जीपीएस',
      'coverage_label': 'खेत कवरेज',

      // Zone Statuses
      'monitored_zones': 'निगरानी वाले ज़ोन',
      'zone1_name': 'ज़ोन 1 — उत्तरी भूखंड (सोयाबीन स्वस्थ)',
      'zone2_name': 'ज़ोन 2 — पूर्वी सेक्टर (सोयाबीन जल तनाव)',
      'zone3_name': 'ज़ोन 3 — दक्षिणी सेक्टर (गेहूं कीट चेतावनी)',
      'zone4_name': 'ज़ोन 4 — पश्चिमी सेक्टर (गेहूं पोषक तत्व कमी)',
      'zone_status_optimal': 'उत्तम',
      'zone_status_water_stress': 'जल तनाव',
      'zone_status_pest_alert': 'कीट चेतावनी',
      'zone_status_nutrient_deficiency': 'पोषक तत्व कमी',

      // Remediation & Actions
      'approve_simulated_irrigation': 'सिमुलेटेड सूक्ष्म-सिंचाई स्वीकृत करें (30 सेकंड)',
      'simulated_irrigation_dispatched': 'सिमुलेटेड सिंचाई शुरू हुई (30 सेकंड)। सुरक्षा द्वार संतुष्ट।',
      'simulated_remediation_verified': 'सिमुलेटेड उपचार सत्यापित (क्लोज्ड-लूप डेमो)',
      'resolved_badge': 'हल हुआ',

      // Opportunity Center
      'opportunity_center_title': 'अवसर एवं सरकारी योजना केंद्र',
      'indicative_eligibility_badge': 'स्व-मूल्यांकित सांकेतिक मार्गदर्शन',
      'official_portal_source': 'आधिकारिक सरकारी स्रोत',
      'matching_criteria_label': 'पात्रता मानक',
      'missing_info_label': 'अधूरी प्रोफ़ाइल जानकारी',

      // Phase 7B: PRAHAR Field Assistant
      'assistant_title': 'प्रहार फील्ड सहायक',
      'assistant_tagline': 'संदर्भ-सचेत कृषि बुद्धिमत्ता',
      'assistant_btn': 'प्रहार सहायक',
      'assistant_query_hint': 'ज़ोन, जल तनाव, कीट, योजनाओं के बारे में पूछें...',
      'assistant_chip_attention': 'सबसे पहले किस पर ध्यान दें?',
      'assistant_chip_stress': 'ज़ोन 2 में जल तनाव क्यों है?',
      'assistant_chip_pest': 'दक्षिण सेक्टर में कीट सलाह?',
      'assistant_chip_schemes': 'प्रासंगिक सरकारी योजनाएं?',
      'assistant_chip_verification': 'सिंचाई के बाद क्या हुआ?',
      'assistant_chip_profile': 'मेरा खेत प्रोफ़ाइल और एकड़',
      'assistant_confirm_action': 'सिम्युलेटेड कार्रवाई की पुष्टि करें',
      'assistant_safety_badge': 'सुरक्षा द्वार: मानव पुष्टि अनिवार्य',
      'assistant_simulation_banner': 'डेमो मोड • भौतिक रोवर डिस्कनेक्ट है',
    },

    'mr': {
      // General & Common (Marathi)
      'app_name': 'प्रहार',
      'app_tagline': 'शेतकरी अचूक शेती सल्लागार',
      'continue_btn': 'पुढे जा',
      'back_btn': 'मागे',
      'finish_btn': 'सेटअप पूर्ण करा आणि होम वर जा',
      'save_btn': 'बदल जतन करा',
      'cancel_btn': 'रद्द करा',
      'skip_btn': 'आता वगळा',
      'quick_fill_demo_btn': 'डेमो शेत डेटा भरा (रमेश पाटील • 4.2 एकर)',
      'load_demo_btn': 'डेमो शेत लोड करा',
      'edit_profile_btn': 'शेत प्रोफाइल संपादित करा',
      'view_profile_title': 'शेतकरी माहिती व शेत तपशील',

      // Onboarding Steps
      'step_language_title': 'पसंतीची भाषा',
      'step_language_desc': 'आवाज आणि डॅशबोर्ड सल्ल्यासाठी तुमची भाषा निवडा.',
      'step_profile_title': 'शेतकरी ओळख',
      'step_profile_desc': 'वैयक्तिकृत शेती सल्ल्यासाठी तुमची माहिती द्या.',
      'step_farm_title': 'शेताचा तपशील',
      'step_farm_desc': 'जमिनीचे क्षेत्रफळ, मालकी आणि सिंचन व्यवस्था सांगा.',
      'step_crop_title': 'पीक व पेरणी तपशील',
      'step_crop_desc': 'पिके आणि हंगाम निवडा.',
      'step_review_title': 'तपासा आणि पुष्टी करा',
      'step_review_desc': 'प्रहार शेत बुद्धिमत्ता सुरू करण्यासाठी माहिती तपासा.',

      // Farmer Profile Fields
      'farmer_name_label': 'पूर्ण नाव',
      'farmer_name_hint': 'उदा. रमेश पाटील',
      'state_label': 'राज्य',
      'state_hint': 'राज्य निवडा',
      'district_label': 'जिल्हा',
      'district_hint': 'उदा. अमरावती',
      'village_label': 'गाव / ठिकाण',
      'village_hint': 'उदा. नांदगाव खंडेश्वर',

      // Farm Fields
      'land_area_label': 'जमीन क्षेत्र (एकर)',
      'land_area_hint': 'उदा. 4.2',
      'ownership_label': 'जमीन मालकी प्रकार',
      'ownership_owned': 'स्वतःची मालकी',
      'ownership_tenant': 'भाडेपट्टीवर / कुळ',
      'ownership_sharecropper': 'बटाईदार',
      'irrigation_label': 'सिंचन सुविधा',
      'irrigation_irrigated': 'पूर्ण सिंचन',
      'irrigation_partial': 'अंशतः सिंचन',
      'irrigation_rainfed': 'कोरडवाहू (पावसावर)',
      'water_source_label': 'पाण्याचा मुख्य स्त्रोत',
      'water_borewell': 'बोअरवेल / विहीर',
      'water_canal': 'कालवा',
      'water_open_well': 'उघडी विहीर',
      'water_river': 'नदी / नाला',
      'water_rainfed': 'पावसाचे पाणी',
      'soil_type_label': 'मातीचा प्रकार',

      // Crop Fields
      'crops_label': 'मुख्य पिके',
      'crops_hint': 'उदा. सोयाबीन, गहू, कापूस',
      'season_label': 'हंगाम',
      'season_kharif': 'खरीप (पावसाळा)',
      'season_rabi': 'रब्बी (हिवाळा)',
      'season_zaid': 'उन्हाळी',
      'season_year_round': 'वार्षिक',
      'variety_label': 'वाण (ऐच्छिक)',
      'variety_hint': 'उदा. जेएस 335 / जीडब्ल्यू 322',
      'sowing_date_label': 'पेरणीची तारीख (ऐच्छिक)',

      // Demo & Simulation Labels
      'demo_field_data_badge': 'डेमो शेत डेटा',
      'simulated_rover_badge': 'सिम्युलेटेड रोव्हर टेलिमेट्री',
      'simulated_action_label': 'सिम्युलेटेड कृती',
      'software_backend_online': 'सॉफ्टवेअर बॅकएंड: ऑनलाइन',
      'software_backend_offline': 'सॉफ्टवेअर बॅकएंड: ऑफलाइन मोड',
      'physical_rover_status': 'प्रत्यक्ष रोव्हर: जोडलेला नाही (सिम्युलेशन मोड)',
      'demo_banner_subtitle': 'प्रहार अचूकता विश्लेषण केवळ चाचणी डेटावर दाखवले आहे.',
      'demo_ai_model_notice': 'डेमो एआय तपासणी • YOLOv8-सुसंगत परिस्थिती',

      // Rover Telemetry Card
      'rover_card_title': 'सिम्युलेटेड रोव्हर टेलिमेट्री',
      'rover_id_label': 'रोव्हर आयडी',
      'battery_label': 'बॅटरी',
      'rover_state_label': 'स्थिती',
      'gps_label': 'सिम्युलेटेड जीपीएस',
      'coverage_label': 'शेत व्याप्ती',

      // Zone Statuses
      'monitored_zones': 'निरीक्षणाखालील झोन',
      'zone1_name': 'झोन 1 — उत्तर प्लॉट (सोयाबीन निरोगी)',
      'zone2_name': 'झोन 2 — पूर्व विभाग (सोयाबीन पाणी ताण)',
      'zone3_name': 'झोन 3 — दक्षिण विभाग (गहू कीड इशारा)',
      'zone4_name': 'झोन 4 — पश्चिम विभाग (गहू पोषण कमतरता)',
      'zone_status_optimal': 'उत्तम',
      'zone_status_water_stress': 'पाण्याचा ताण',
      'zone_status_pest_alert': 'कीड इशारा',
      'zone_status_nutrient_deficiency': 'पोषण कमतरता',

      // Remediation & Actions
      'approve_simulated_irrigation': 'सिम्युलेटेड ठिबक सिंचन मंजूर करा (30 सेकंद)',
      'simulated_irrigation_dispatched': 'सिम्युलेटेड सिंचन सुरू झाले (30 सेकंद).',
      'simulated_remediation_verified': 'सिम्युलेटेड उपाययोजना पडताळणी पूर्ण (क्लोज्ड-लूप डेमो)',
      'resolved_badge': 'निराकरण झाले',

      // Opportunity Center
      'opportunity_center_title': 'संधी व शासकीय योजना केंद्र',
      'indicative_eligibility_badge': 'स्व-मूल्यांकन सूचक मार्गदर्शन',
      'official_portal_source': 'अधिकृत शासकीय स्त्रोत',
      'matching_criteria_label': 'पात्रता निकष',
      'missing_info_label': 'अपूर्ण माहिती',

      // Phase 7B: PRAHAR Field Assistant
      'assistant_title': 'प्रहार फील्ड सहाय्यक',
      'assistant_tagline': 'संदर्भ-आधारित कृषी बुद्धिमत्ता',
      'assistant_btn': 'प्रहार सहाय्यक',
      'assistant_query_hint': 'झोन, पाण्याचा ताण, कीड, योजनांविषयी विचारा...',
      'assistant_chip_attention': 'प्रथम कशावर लक्ष दिले पाहिजे?',
      'assistant_chip_stress': 'झोन 2 मध्ये पाण्याचा ताण का आहे?',
      'assistant_chip_pest': 'दक्षिण सेक्टरसाठी कीड मार्गदर्शन?',
      'assistant_chip_schemes': 'शासकीय योजनांची माहिती?',
      'assistant_chip_verification': 'सिंचनानंतर काय झाले?',
      'assistant_chip_profile': 'माझे शेत प्रोफाईल आणि एकर',
      'assistant_confirm_action': 'सिम्युलेट कारवाईची पुष्टी करा',
      'assistant_safety_badge': 'सुरक्षा द्वार: मानवी पुष्टी आवश्यक',
      'assistant_simulation_banner': 'डेमो मोड • भौतिक रोव्हर डिस्कनेक्ट आहे',
    },

    'pa': {
      // General & Common (Punjabi)
      'app_name': 'ਪ੍ਰਹਾਰ',
      'app_tagline': 'ਕਿਸਾਨ ਸ਼ੁੱਧ ਖੇਤੀ ਸਲਾਹਕਾਰ',
      'continue_btn': 'ਅੱਗੇ ਵਧੋ',
      'back_btn': 'ਪਿੱਛੇ',
      'finish_btn': 'ਸੈੱਟਅੱਪ ਪੂਰਾ ਕਰੋ ਅਤੇ ਹੋਮ ਤੇ ਜਾਓ',
      'save_btn': 'ਤਬਦੀਲੀਆਂ ਸੁਰੱਖਿਅਤ ਕਰੋ',
      'cancel_btn': 'ਰੱਦ ਕਰੋ',
      'skip_btn': 'ਹੁਣ ਛੱਡੋ',
      'quick_fill_demo_btn': 'ਡੈਮੋ ਫਾਰਮ ਭਰੋ (ਰਮੇਸ਼ ਪਾਟਿਲ • 4.2 ਏਕੜ)',
      'load_demo_btn': 'ਡੈਮੋ ਖੇਤ ਲੋਡ ਕਰੋ',
      'edit_profile_btn': 'ਖੇਤ ਪ੍ਰੋਫਾਈਲ ਸੋਧੋ',
      'view_profile_title': 'ਕਿਸਾਨ ਪ੍ਰੋਫਾਈਲ ਅਤੇ ਖੇਤ ਵੇਰਵੇ',

      // Onboarding Steps
      'step_language_title': 'ਪਸੰਦੀਦਾ ਭਾਸ਼ਾ',
      'step_language_desc': 'ਆਵਾਜ਼ ਅਤੇ ਡੈਸ਼ਬੋਰਡ ਸਲਾਹ ਲਈ ਆਪਣੀ ਭਾਸ਼ਾ ਚੁਣੋ।',
      'step_profile_title': 'ਕਿਸਾਨ ਪਛਾਣ',
      'step_profile_desc': 'ਖੇਤੀ ਸਲਾਹ ਲਈ ਆਪਣੇ ਬਾਰੇ ਦੱਸੋ।',
      'step_farm_title': 'ਖੇਤ ਦੇ ਵੇਰਵੇ',
      'step_farm_desc': 'ਜ਼ਮੀਨ ਦਾ ਆਕਾਰ, ਮਾਲਕੀ ਅਤੇ ਸਿੰਚਾਈ ਸਹੂਲਤ ਦੱਸੋ।',
      'step_crop_title': 'ਫ਼ਸਲ ਅਤੇ ਬਿਜਾਈ ਵੇਰਵੇ',
      'step_crop_desc': 'ਆਪਣੀਆਂ ਮੁੱਖ ਫ਼ਸਲਾਂ ਅਤੇ ਸੀਜ਼ਨ ਚੁਣੋ।',
      'step_review_title': 'ਸਮੀਖਿਆ ਅਤੇ ਪੁਸ਼ਟੀ',
      'step_review_desc': 'ਪ੍ਰਹਾਰ ਖੇਤ ਸਿਸਟਮ ਸ਼ੁਰੂ ਕਰਨ ਲਈ ਵੇਰਵੇ ਚੈੱਕ ਕਰੋ।',

      // Farmer Profile Fields
      'farmer_name_label': 'ਪੂਰਾ ਨਾਮ',
      'farmer_name_hint': 'ਜਿਵੇਂ: ਰਮੇਸ਼ ਪਾਟਿਲ',
      'state_label': 'ਰਾਜ',
      'state_hint': 'ਆਪਣਾ ਰਾਜ ਚੁਣੋ',
      'district_label': 'ਜ਼ਿਲ੍ਹਾ',
      'district_hint': 'ਜਿਵੇਂ: ਅਮਰਾਵਤੀ / ਲੁਧਿਆਣਾ',
      'village_label': 'ਪਿੰਡ / ਥਾਂ',
      'village_hint': 'ਜਿਵੇਂ: ਨਾਂਦਗਾਓਂ',

      // Farm Fields
      'land_area_label': 'ਜ਼ਮੀਨ ਦਾ ਰਕਬਾ (ਏਕੜ ਵਿੱਚ)',
      'land_area_hint': 'ਜਿਵੇਂ: 4.2',
      'ownership_label': 'ਜ਼ਮੀਨ ਦੀ ਮਾਲਕੀ ਕਿਸਮ',
      'ownership_owned': 'ਨਿੱਜੀ (ਮਾਲਕ)',
      'ownership_tenant': 'ਕਿਰਾਏਦਾਰ (ਠੇਕਾ)',
      'ownership_sharecropper': 'ਹਿੱਸੇਦਾਰ',
      'irrigation_label': 'ਸਿੰਚਾਈ ਸਹੂਲਤ',
      'irrigation_irrigated': 'ਪੂਰੀ ਤਰ੍ਹਾਂ ਸਿੰਚਾਈ ਅਧੀਨ',
      'irrigation_partial': 'ਅੰਸ਼ਕ ਸਿੰਚਾਈ',
      'irrigation_rainfed': 'ਬਰਸਾਤੀ (ਗੈਰ-ਸਿੰਚਾਈ)',
      'water_source_label': 'ਮੁੱਖ ਪਾਣੀ ਦਾ ਸਰੋਤ',
      'water_borewell': 'ਟਿਊਬਵੈੱਲ / ਬੋਰਵੈੱਲ',
      'water_canal': 'ਨਹਿਰ',
      'water_open_well': 'ਖੁੱਲ੍ਹਾ ਖੂਹ',
      'water_river': 'ਦਰਿਆ / ਸੂਆ',
      'water_rainfed': 'ਮੀਂਹ ਦਾ ਪਾਣੀ',
      'soil_type_label': 'ਮਿੱਟੀ ਦੀ ਕਿਸਮ',

      // Crop Fields
      'crops_label': 'ਮੁੱਖ ਫ਼ਸਲਾਂ',
      'crops_hint': 'ਜਿਵੇਂ: ਸੋਇਆਬੀਨ, ਕਣਕ, ਝੋਨਾ',
      'season_label': 'ਖੇਤੀ ਸੀਜ਼ਨ',
      'season_kharif': 'ਖਰੀਫ਼ (ਸਾਉਣੀ)',
      'season_rabi': 'ਹਾੜ੍ਹੀ (ਸਿਆਲੂ)',
      'season_zaid': 'ਜ਼ਾਇਦ (ਗਰਮੀਆਂ)',
      'season_year_round': 'ਸਾਲਾਨਾ',
      'variety_label': 'ਕਿਸਮ (ਵਿਕਲਪਿਕ)',
      'variety_hint': 'ਜਿਵੇਂ: JS 335 / GW 322',
      'sowing_date_label': 'ਬਿਜਾਈ ਦੀ ਮਿਤੀ (ਵਿਕਲਪਿਕ)',

      // Demo & Simulation Labels
      'demo_field_data_badge': 'ਡੈਮੋ ਖੇਤ ਡਾਟਾ',
      'simulated_rover_badge': 'ਸਿਮੂਲੇਟਡ ਰੋਵਰ ਟੈਲੀਮੈਟਰੀ',
      'simulated_action_label': 'ਸਿਮੂਲੇਟਡ ਕਾਰਵਾਈ',
      'software_backend_online': 'ਸਾਫਟਵੇਅਰ ਬੈਕਐਂਡ: ਆਨਲਾਈਨ',
      'software_backend_offline': 'ਸਾਫਟਵੇਅਰ ਬੈਕਐਂਡ: ਆਫ਼ਲਾਈਨ ਮੋਡ',
      'physical_rover_status': 'ਅਸਲ ਰੋਵਰ: ਕਨੈਕਟ ਨਹੀਂ (ਸਿਮੂਲੇਸ਼ਨ ਮੋਡ)',
      'demo_banner_subtitle': 'ਪ੍ਰਹਾਰ ਸ਼ੁੱਧ ਵਿਸ਼ਲੇਸ਼ਣ ਡੈਮੋ ਡਾਟਾ ਉੱਤੇ ਦਿਖਾਇਆ ਜਾ ਰਿਹਾ ਹੈ।',
      'demo_ai_model_notice': 'ਡੈਮੋ ਏਆਈ ਪਛਾਣ • YOLOv8-ਅਨੁਕੂਲ ਦ੍ਰਿਸ਼',

      // Rover Telemetry Card
      'rover_card_title': 'ਸਿਮੂਲੇਟਡ ਰੋਵਰ ਟੈਲੀਮੈਟਰੀ',
      'rover_id_label': 'ਰੋਵਰ ਆਈਡੀ',
      'battery_label': 'ਬੈਟਰੀ',
      'rover_state_label': 'ਸਥਿਤੀ',
      'gps_label': 'ਸਿਮੂਲੇਟਡ ਜੀਪੀਐਸ',
      'coverage_label': 'ਖੇਤ ਕਵਰੇਜ',

      // Zone Statuses
      'monitored_zones': 'ਨਿਗਰਾਨੀ ਵਾਲੇ ਜ਼ੋਨ',
      'zone1_name': 'ਜ਼ੋਨ 1 — ਉੱਤਰੀ ਪਲਾਟ (ਸੋਇਆਬੀਨ ਸਿਹਤਮੰਦ)',
      'zone2_name': 'ਜ਼ੋਨ 2 — ਪੂਰਬੀ ਸੈਕਟਰ (ਸੋਇਆਬੀਨ ਪਾਣੀ ਦੀ ਘਾਟ)',
      'zone3_name': 'ਜ਼ੋਨ 3 — ਦੱਖਣੀ ਸੈਕਟਰ (ਕਣਕ ਕੀੜੇ ਚੇਤਾਵਨੀ)',
      'zone4_name': 'ਜ਼ੋਨ 4 — ਪੱਛਮੀ ਸੈਕਟਰ (ਕਣਕ ਪੋਸ਼ਕ ਤੱਤ ਕਮੀ)',
      'zone_status_optimal': 'ਵਧੀਆ',
      'zone_status_water_stress': 'ਪਾਣੀ ਦਾ ਤਣਾਅ',
      'zone_status_pest_alert': 'ਕੀੜੇ ਦੀ ਚੇਤਾਵਨੀ',
      'zone_status_nutrient_deficiency': 'ਪੋਸ਼ਕ ਤੱਤ ਕਮੀ',

      // Remediation & Actions
      'approve_simulated_irrigation': 'ਸਿਮੂਲੇਟਡ ਮਾਈਕਰੋ-ਸਿੰਚਾਈ ਮਨਜ਼ੂਰ ਕਰੋ (30 ਸਕਿੰਟ)',
      'simulated_irrigation_dispatched': 'ਸਿਮੂਲੇਟਡ ਸਿੰਚਾਈ ਸ਼ੁਰੂ ਹੋਈ (30 ਸਕਿੰਟ)।',
      'simulated_remediation_verified': 'ਸਿਮੂਲੇਟਡ ਉਪਚਾਰ ਤਸਦੀਕ ਪੂਰਾ (ਕਲੋਜ਼ਡ-ਲੂਪ ਡੈਮੋ)',
      'resolved_badge': 'ਹੱਲ ਹੋ ਗਿਆ',

      // Opportunity Center
      'opportunity_center_title': 'ਮੌਕੇ ਅਤੇ ਸਰਕਾਰੀ ਸਕੀਮ ਕੇਂਦਰ',
      'indicative_eligibility_badge': 'ਸਵੈ-ਮੁਲਾਂਕਣ ਸਲਾਹਕਾਰੀ ਮਾਰਗਦਰਸ਼ਨ',
      'official_portal_source': 'ਅਧਿਕਾਰਤ ਸਰਕਾਰੀ ਸਰੋਤ',
      'matching_criteria_label': 'ਯੋਗਤਾ ਮਾਪਦੰਡ',
      'missing_info_label': 'ਅਧੂਰੀ ਪ੍ਰੋਫਾਈਲ ਜਾਣਕਾਰੀ',

      // Phase 7B: PRAHAR Field Assistant
      'assistant_title': 'ਪ੍ਰਹਾਰ ਫੀਲਡ ਸਹਾਇਕ',
      'assistant_tagline': 'ਸੰਦਰਭ-ਸੂਚਿਤ ਖੇਤੀਬਾੜੀ ਬੁੱਧੀਮਤਾ',
      'assistant_btn': 'ਪ੍ਰਹਾਰ ਸਹਾਇਕ',
      'assistant_query_hint': 'ਜ਼ੋਨ, ਪਾਣੀ ਦੀ ਕਮੀ, ਕੀੜੇ, ਸਕੀਮਾਂ ਬਾਰੇ ਪੁੱਛੋ...',
      'assistant_chip_attention': 'ਪਹਿਲਾਂ ਕਿਸ ਵੱਲ ਧਿਆਨ ਦੇਣਾ ਹੈ?',
      'assistant_chip_stress': 'ਜ਼ੋਨ 2 ਵਿੱਚ ਪਾਣੀ ਦੀ ਕਮੀ ਕਿਉਂ ਹੈ?',
      'assistant_chip_pest': 'ਦੱਖਣ ਸੈਕਟਰ ਲਈ ਕੀੜੇ ਦੀ ਸਲਾਹ?',
      'assistant_chip_schemes': 'ਮੇਰੇ ਲਈ ਸਰਕਾਰੀ ਸਕੀਮਾਂ?',
      'assistant_chip_verification': 'ਸਿੰਚਾਈ ਤੋਂ ਬਾਅਦ ਕੀ ਹੋਇਆ?',
      'assistant_chip_profile': 'ਮੇਰੀ ਜ਼ਮੀਨ ਅਤੇ ਪ੍ਰੋਫਾਈਲ',
      'assistant_confirm_action': 'ਸਿਮੂਲੇਟ ਕਾਰਵਾਈ ਦੀ ਪੁਸ਼ਟੀ ਕਰੋ',
      'assistant_safety_badge': 'ਸੁਰੱਖਿਆ ਗੇਟ: ਪੁਸ਼ਟੀਕਰਣ ਲਾਜ਼ਮੀ ਹੈ',
      'assistant_simulation_banner': 'ਡੈਮੋ ਮੋਡ • ਰੋਵਰ ਡਿਸਕਨੈਕਟ ਹੈ',
    },
  };

  String text(String key) {
    final langMap = _localizedValues[languageCode];
    if (langMap != null && langMap.containsKey(key)) {
      return langMap[key]!;
    }
    // Fallback to Hindi if regional, else English
    if (languageCode == 'mr' || languageCode == 'pa') {
      final hiMap = _localizedValues['hi'];
      if (hiMap != null && hiMap.containsKey(key)) {
        return hiMap[key]!;
      }
    }
    return _localizedValues['en']?[key] ?? key;
  }

  static String getText(String key, String langCode) {
    return AppLocalizations(langCode).text(key);
  }
}
