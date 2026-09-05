import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../core/theme.dart';
import '../core/offline_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Language toggle: true = Hindi ('hi'), false = English ('en')
  bool _isHindi = false;

  final OfflineStorageService _offlineStorage = OfflineStorageService();

  final RoverStatusModel _rover = const RoverStatusModel(
    roverId: 'ROVER-DEMO-01',
    state: 'IDLE',
    batteryPct: 95.0,
    currentZone: 'Zone 1 (North Plot)',
    isOffline: false,
  );

  final List<AlertModel> _alerts = [
    AlertModel(
      id: 'alert-01',
      zoneId: 'DEMO-ZONE-02',
      zoneName: 'Zone 2 (East Sector)',
      type: HazardType.waterStress,
      severity: AlertSeverity.high,
      message: 'High Water Stress: Soil moisture at 17.5% (below 20% critical threshold).',
      messageHi: 'गंभीर जल तनाव: मिट्टी की नमी 17.5% है (20% गंभीर सीमा से कम)।',
      recommendedAction: 'Micro-irrigation recommended for 30s. Awaiting your approval.',
      recommendedActionHi: '30 सेकंड सूक्ष्म-सिंचाई की सिफारिश। आपकी स्वीकृति आवश्यक है।',
      status: AlertStatus.newAlert,
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      isApproved: false,
    ),
    AlertModel(
      id: 'alert-02',
      zoneId: 'DEMO-ZONE-03',
      zoneName: 'Zone 3 (South Sector)',
      type: HazardType.disease,
      severity: AlertSeverity.medium,
      message: 'Suspected Early Blight on basal leaves under high humidity (78%).',
      messageHi: 'उच्च आर्द्रता (78%) में निचली पत्तियों पर संदिग्ध Early Blight।',
      recommendedAction: 'Isolate affected plot. Expert agronomist review requested.',
      recommendedActionHi: 'प्रभावित क्षेत्र अलग करें। विशेषज्ञ समीक्षा का अनुरोध किया गया।',
      status: AlertStatus.newAlert,
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
      isApproved: false,
    ),
  ];

  RemediationVerificationModel? _latestVerification;
  final Map<String, bool> _expandedWhy = {};

  void _approveAndIrrigate(AlertModel alert) {
    if (!_offlineStorage.isOnline) {
      _offlineStorage.queueAction('APPROVE_IRRIGATION', {
        'alert_id': alert.id,
        'zone_id': alert.zoneId,
        'duration_seconds': 30,
        'approved_by': 'farmer_offline',
      });
      setState(() {
        alert.isApproved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isHindi
                ? 'ऑफ़लाइन सहेजा गया! इंटरनेट बहाल होने पर सिंक होगा।'
                : 'Action buffered offline! Will synchronize when online.',
          ),
          backgroundColor: PraharTheme.alertAmber,
        ),
      );
      return;
    }

    setState(() {
      alert.isApproved = true;
      alert.status = AlertStatus.actionTaken;

      // Simulate closed-loop remediation verification
      _latestVerification = RemediationVerificationModel(
        zoneId: alert.zoneId,
        preMoisture: 17.5,
        postMoisture: 28.2,
        moistureDelta: 10.7,
        resolved: true,
        summaryEn: 'Zone 2 remediation verified: Moisture improved from 17.5% to 28.2% (+10.7%). Solved!',
        summaryHi: 'ज़ोन 2 उपचार का सत्यापन: नमी 17.5% से बढ़कर 28.2% हो गई (+10.7%)। समस्या हल!',
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isHindi
              ? 'सिंचाई स्वीकृत! रोवर ने 30s सूक्ष्म-सिंचाई शुरू की। (सुरक्षा द्वार संतुष्ट)'
              : 'Irrigation Approved! Rover dispatched 30s micro-irrigation. (Safety Gate Satisfied)',
        ),
        backgroundColor: PraharTheme.primaryGreen,
      ),
    );
  }

  void _syncNow() async {
    final synced = await _offlineStorage.synchronize();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isHindi
              ? 'सिंक पूरा हुआ: $synced कार्य सर्वर पर भेजे गए।'
              : 'Sync complete: $synced offline actions pushed to server.',
        ),
        backgroundColor: PraharTheme.primaryGreen,
      ),
    );
  }

  // Phase 4: Voice Assistant Dialog (Simulated STT with Strict Safety Confirmation)
  void _openVoiceDialog() {
    bool voiceConfirmed = false;
    String responseText = _isHindi
        ? 'आदेश बोलें या चुनें (उदाहरण: "खेत की क्या स्थिति है?" या "सिंचाई चालू करो")'
        : 'Speak or select intent (e.g., "What is farm status?" or "Start irrigation")';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131F19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.mic, color: PraharTheme.primaryGreen),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _isHindi ? 'प्रहार आवाज़ सहायक' : 'PRAHAR Voice Assistant',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: PraharTheme.alertAmber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: PraharTheme.alertAmber),
                    ),
                    child: const Text(
                      'SIMULATION / DEMO INTENT',
                      style: TextStyle(fontSize: 10, color: PraharTheme.alertAmber, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isHindi
                    ? 'माइक्रोफ़ोन/एसटीटी सिमुलेशन: आवाज़ सीधे मोटर नहीं चला सकती। सुरक्षा द्वार अनिवार्य है।'
                    : 'Honest STT Notice: Speech recognition simulation active. Voice commands CANNOT directly drive motors.',
                style: TextStyle(color: Colors.grey[400], fontSize: 11, fontStyle: FontStyle.italic),
              ),
              const Divider(height: 20, color: PraharTheme.borderGreen),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1410),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PraharTheme.borderGreen),
                ),
                child: Text(
                  responseText,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              // Preset Voice Intents
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.info_outline, size: 16, color: PraharTheme.primaryGreen),
                    label: Text(_isHindi ? 'खेत की क्या स्थिति है?' : 'What is farm status?'),
                    onPressed: () {
                      setModalState(() {
                        responseText = _isHindi
                            ? 'आवाज़ प्रतिक्रिया: डेमो खेत अल्फा में समग्र स्वास्थ्य सूचकांक 74/100 (निष्पक्ष) है। ज़ोन 2 में मिट्टी की नमी 17.5% है और सूक्ष्म-सिंचाई की सिफारिश की गई है।'
                            : 'Voice Response: Demo Farm Alpha Composite Health Index is 74/100 (Fair). Zone 2 moisture is low at 17.5%, irrigation recommended.';
                      });
                    },
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.water_drop, size: 16, color: PraharTheme.alertSky),
                    label: Text(_isHindi ? 'सिंचाई चालू करो (ज़ोन 2)' : 'Start irrigation (Zone 2)'),
                    onPressed: () {
                      setModalState(() {
                        voiceConfirmed = false;
                        responseText = _isHindi
                            ? 'सिफारिश: ज़ोन 2 में 30 सेकंड सूक्ष्म-सिंचाई।\n\n⚠️ सुरक्षा चेतावनी: आवाज़ अनुरोध सीधे मोटर नहीं चला सकता। कृपया नीचे स्पष्ट पुष्टि दें।'
                            : 'Recommendation: 30s micro-irrigation for Zone 2.\n\n⚠️ Safety Gate: Voice cannot trigger actuators directly. Farmer confirmation and safety check required.';
                      });
                    },
                  ),
                ],
              ),
              if (responseText.contains('सुरक्षा') || responseText.contains('Safety Gate')) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PraharTheme.alertAmber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: PraharTheme.alertAmber),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: voiceConfirmed,
                            activeColor: PraharTheme.primaryGreen,
                            onChanged: (val) {
                              setModalState(() {
                                voiceConfirmed = val ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              _isHindi
                                  ? 'मैं (किसान) ज़ोन 2 में 30 सेकंड सिंचाई को स्पष्ट रूप से अधिकृत करता हूँ।'
                                  : 'I confirm and authorize 30s irrigation for Zone 2 (Passes Phase 2/3 Safety Gate).',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: voiceConfirmed ? PraharTheme.primaryGreen : Colors.grey,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 36),
                        ),
                        onPressed: voiceConfirmed
                            ? () {
                                Navigator.pop(ctx);
                                final waterAlert = _alerts.firstWhere(
                                  (a) => a.type == HazardType.waterStress,
                                  orElse: () => _alerts[0],
                                );
                                _approveAndIrrigate(waterAlert);
                              }
                            : null,
                        child: Text(
                          _isHindi ? 'पुष्टि और सुरक्षित निष्पादन' : 'Confirm & Execute Safely',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Phase 4: Field Evidence Report Viewer
  void _openEvidenceReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131F19),
        title: Row(
          children: [
            const Icon(Icons.description, color: PraharTheme.primaryGreen),
            const SizedBox(width: 8),
            Text(
              _isHindi ? 'प्रहार फील्ड साक्ष्य रिपोर्ट' : 'PRAHAR Field Evidence Report',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mandatory Non-Government Disclaimer Banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PraharTheme.alertAmber.withOpacity(0.15),
                  border: Border.all(color: PraharTheme.alertAmber),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isHindi
                      ? '⚠️ कानूनी अस्वीकरण: यह प्रहार (PRAHAR) द्वारा उत्पन्न एक सूचनात्मक साक्ष्य रिपोर्ट है। यह कोई आधिकारिक सरकारी प्रमाण पत्र या प्रमाणित कृषि प्रमाणन नहीं है।'
                      : '⚠️ LEGAL DISCLAIMER: This is an informational evidence report generated by PRAHAR for farm monitoring and advisory purposes. It is NOT an official government certificate or accredited agricultural certification.',
                  style: const TextStyle(color: PraharTheme.alertAmber, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isHindi ? 'रिपोर्ट आईडी: PFER-2026-DEMO-001' : 'Report ID: PFER-2026-DEMO-001',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                _isHindi ? 'खेत: डेमो खेत अल्फा (टमाटर • 3.5 एकड़)' : 'Farm: Demo Farm Alpha (Tomato • 3.5 Acres)',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              const Divider(height: 20, color: PraharTheme.borderGreen),
              Text(
                _isHindi ? 'सत्यापित उपचार सारांश:' : 'Verified Remediation Summary:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _isHindi
                    ? '• ज़ोन 2: सूक्ष्म-सिंचाई के बाद नमी 17.5% से सुधरकर 28.2% हुई (+10.7%)।\n• ज़ोन 3: पत्ती धब्बा रोग को अलग किया गया, विशेषज्ञ समीक्षा पूरी हुई।'
                    : '• Zone 2: Micro-irrigation improved soil moisture from 17.5% to 28.2% (+10.7%).\n• Zone 3: Leaf blight localized, agronomist consultation completed.',
                style: TextStyle(color: Colors.grey[300], fontSize: 12),
              ),
              const SizedBox(height: 10),
              Text(
                _isHindi
                    ? 'डेमो समग्र स्वास्थ्य सूचकांक: 74/100 (उचित)'
                    : 'PRAHAR Composite Indicator — Demo Metric: 74/100 (Fair)',
                style: const TextStyle(color: PraharTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isHindi ? 'बंद करें' : 'Close'),
          ),
        ],
      ),
    );
  }

  // Phase 4: Farmer Opportunity Center (Verified Indian Government Portals)
  void _openOpportunityCenterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131F19),
        title: Row(
          children: [
            const Icon(Icons.account_balance, color: PraharTheme.alertSky),
            const SizedBox(width: 8),
            Text(
              _isHindi ? 'किसान अवसर केंद्र' : 'Farmer Opportunity Center',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Clear distinction notice
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: PraharTheme.alertSky.withOpacity(0.15),
                  border: Border.all(color: PraharTheme.alertSky),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isHindi
                      ? 'सरकारी योजनाएं आधिकारिक स्रोतों से सत्यापित हैं। प्रहार केवल मार्गदर्शन प्रदान करता है और आपकी ओर से आवेदन जमा नहीं करता है।'
                      : 'Government schemes verified from official ministry portals. PRAHAR provides advisory guidance only and does NOT submit government applications.',
                  style: const TextStyle(color: PraharTheme.alertSky, fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              _buildSchemeTile(
                'PM-KUSUM',
                'https://pmkusum.mnre.gov.in',
                _isHindi ? 'सौर सिंचाई पंप के लिए 60% सब्सिडी' : '60% subsidy for solar-powered irrigation pumps',
              ),
              _buildSchemeTile(
                'PMKSY - Per Drop More Crop',
                'https://pmksy.gov.in',
                _isHindi ? 'ड्रिप/स्प्रिंकलर सूक्ष्म-सिंचाई के लिए 45-55% वित्तीय सहायता' : '45-55% assistance for micro-irrigation systems',
              ),
              _buildSchemeTile(
                'SMAM (कृषि यंत्रीकरण)',
                'https://agrimachinery.nic.in',
                _isHindi ? 'कृषि रोबोटिक्स और मशीनरी खरीद पर 40-50% सब्सिडी' : '40-50% subsidy for robotic farm implements',
              ),
              _buildSchemeTile(
                'PMFBY (फसल बीमा योजना)',
                'https://pmfby.gov.in',
                _isHindi ? 'मौसम और कीट के कारण नुकसान पर वित्तीय सुरक्षा' : 'Comprehensive risk insurance for crop loss',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_isHindi ? 'बंद करें' : 'Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSchemeTile(String name, String url, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1410),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PraharTheme.borderGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
          const SizedBox(height: 2),
          Text(desc, style: TextStyle(color: Colors.grey[300], fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            'Official Portal: $url',
            style: const TextStyle(color: PraharTheme.alertSky, fontSize: 10, decoration: TextDecoration.underline),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('PRAHAR'),
            const SizedBox(width: 8),
            Chip(
              label: Text(_isHindi ? 'किसान v0.3' : 'Farmer v0.3', style: const TextStyle(fontSize: 10, color: Colors.white)),
              backgroundColor: PraharTheme.borderGreen,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          // Language Switcher Toggle (Requirement 9)
          TextButton.icon(
            icon: const Icon(Icons.language, color: PraharTheme.primaryGreen, size: 18),
            label: Text(
              _isHindi ? 'English' : 'हिन्दी',
              style: const TextStyle(color: PraharTheme.primaryGreen, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              setState(() {
                _isHindi = !_isHindi;
                _offlineStorage.languagePreference = _isHindi ? 'hi' : 'en';
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Phase 3 Offline Sync Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _offlineStorage.isOnline ? const Color(0xFF10281F) : const Color(0xFF2A1C14),
              border: Border.all(
                color: _offlineStorage.isOnline ? PraharTheme.primaryGreen : PraharTheme.alertAmber,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _offlineStorage.isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: _offlineStorage.isOnline ? PraharTheme.primaryGreen : PraharTheme.alertAmber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _offlineStorage.isOnline
                              ? (_isHindi ? 'क्लाउड सिंक सक्रिय (ऑनलाइन)' : 'Cloud Sync Active (Online)')
                              : (_isHindi ? 'ऑफ़लाइन मोड (स्थानीय कैश)' : 'Offline Mode (Local Cache)'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _offlineStorage.isOnline ? PraharTheme.primaryGreen : PraharTheme.alertAmber,
                          ),
                        ),
                        Text(
                          _isHindi
                              ? 'लंबित कतार: ${_offlineStorage.pendingCount} कार्य'
                              : 'Buffered: ${_offlineStorage.pendingCount} pending events',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Offline toggle for field testing
                    IconButton(
                      icon: Icon(
                        _offlineStorage.isOnline ? Icons.wifi : Icons.wifi_off,
                        size: 20,
                        color: Colors.grey[300],
                      ),
                      tooltip: 'Toggle Network Connectivity',
                      onPressed: () {
                        setState(() {
                          _offlineStorage.isOnline = !_offlineStorage.isOnline;
                        });
                      },
                    ),
                    if (_offlineStorage.pendingCount > 0 && _offlineStorage.isOnline)
                      TextButton(
                        onPressed: _syncNow,
                        style: TextButton.styleFrom(
                          backgroundColor: PraharTheme.primaryGreen,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        child: Text(
                          _isHindi ? 'सिंक करें' : 'Sync Now',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Farm Health Status Card with Phase 4 Composite Indicator & Simulation Weather
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isHindi ? 'डेमो खेत अल्फा' : 'Demo Farm Alpha',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: PraharTheme.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: PraharTheme.primaryGreen),
                        ),
                        child: Text(
                          _isHindi ? 'समग्र सूचकांक: 74/100' : 'Demo Composite: 74/100',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PraharTheme.primaryGreen),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isHindi
                        ? 'फसल: टमाटर • 3.5 एकड़ • 4 निगरानी वाले ज़ोन'
                        : 'Crop: Tomato • 3.5 Acres • 4 Monitored Zones',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isHindi
                        ? 'PRAHAR समग्र सूचकांक — डेमो मीट्रिक (नमी 35%, रोग 25%, कीट 20%, ताप 20%)'
                        : 'PRAHAR Composite Indicator — Demo Metric (Moisture 35%, Disease 25%, Pest 20%, Heat 20%)',
                    style: TextStyle(color: Colors.grey[400], fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                  const Divider(height: 18, color: PraharTheme.borderGreen),
                  // Phase 4: Weather Risk Indicator with Mandatory Simulation/Demo Label
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: PraharTheme.alertAmber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: PraharTheme.alertAmber.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.wb_sunny, color: PraharTheme.alertAmber, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              _isHindi ? 'सिमुलेशन मौसम (डेमो)' : 'SIMULATION WEATHER (DEMO)',
                              style: const TextStyle(color: PraharTheme.alertAmber, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Text(
                          _isHindi ? '31°C | ताप तनाव: मध्यम' : '31°C Sunny | Heat Risk: MODERATE',
                          style: TextStyle(color: Colors.grey[300], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric(_isHindi ? 'सक्रिय अलर्ट' : 'Active Alerts', '${_alerts.length}', PraharTheme.alertAmber),
                      _buildMetric(_isHindi ? 'औसत नमी' : 'Soil Moisture', '28% avg', PraharTheme.primaryGreen),
                      _buildMetric(_isHindi ? 'रोवर बैटरी' : 'Rover Battery', '${_rover.batteryPct.toInt()}%', PraharTheme.primaryGreen),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Phase 4: Quick Action Hub (Voice Assistant, Evidence Report, Opportunities)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.mic, size: 16, color: PraharTheme.primaryGreen),
                  label: Text(
                    _isHindi ? 'आवाज़ सहायक' : 'Voice (Demo)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: PraharTheme.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: _openVoiceDialog,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.description, size: 16, color: PraharTheme.alertAmber),
                  label: Text(
                    _isHindi ? 'साक्ष्य रिपोर्ट' : 'Evidence Report',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: PraharTheme.alertAmber),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: _openEvidenceReportDialog,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.account_balance, size: 16, color: PraharTheme.alertSky),
                  label: Text(
                    _isHindi ? 'योजनाएं' : 'Opportunities',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: PraharTheme.alertSky),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: _openOpportunityCenterDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Closed-Loop Verification Result Card (if verified)
          if (_latestVerification != null) ...[
            Card(
              color: const Color(0xFF132A22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: PraharTheme.primaryGreen, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: PraharTheme.primaryGreen, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _isHindi ? 'उपचार सत्यापन सफल' : 'Remediation Verified (Closed-Loop)',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: PraharTheme.primaryGreen),
                            ),
                          ],
                        ),
                        Chip(
                          label: Text(_isHindi ? 'सत्यापित' : 'RESOLVED', style: const TextStyle(fontSize: 10, color: Colors.black)),
                          backgroundColor: PraharTheme.primaryGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isHindi ? _latestVerification!.summaryHi : _latestVerification!.summaryEn,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${_isHindi ? "पहले" : "Pre"}: ${_latestVerification!.preMoisture}%  →  ${_isHindi ? "बाद में" : "Post"}: ${_latestVerification!.postMoisture}%',
                          style: TextStyle(color: Colors.grey[300], fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '(+${_latestVerification!.moistureDelta}%)',
                          style: const TextStyle(color: PraharTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Active Field Alerts Header
          Text(
            _isHindi ? 'सक्रिय खेत अलर्ट और सिफारिशें' : 'Active Field Alerts & Recommendations',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // Alerts List
          ..._alerts.map((alert) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: alert.severity == AlertSeverity.high
                                  ? PraharTheme.alertRose.withOpacity(0.2)
                                  : PraharTheme.alertAmber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: alert.severity == AlertSeverity.high
                                    ? PraharTheme.alertRose
                                    : PraharTheme.alertAmber,
                              ),
                            ),
                            child: Text(
                              alert.severity.name.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: alert.severity == AlertSeverity.high
                                    ? PraharTheme.alertRose
                                    : PraharTheme.alertAmber,
                              ),
                            ),
                          ),
                          Text(
                            alert.zoneName,
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isHindi ? alert.messageHi : alert.message,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101B17),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb, size: 16, color: PraharTheme.alertAmber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isHindi ? alert.recommendedActionHi : alert.recommendedAction,
                                style: TextStyle(color: Colors.grey[300], fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Phase 4: Expandable 'WHY' Reasoning Drawer
                      InkWell(
                        onTap: () {
                          setState(() {
                            _expandedWhy[alert.id] = !(_expandedWhy[alert.id] ?? false);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1814),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: PraharTheme.borderGreen),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.psychology, size: 14, color: PraharTheme.primaryGreen),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isHindi ? 'कारण और साक्ष्य देखें (WHY Reasoning)' : 'Inspect "WHY" Reasoning & Evidence',
                                    style: const TextStyle(fontSize: 11, color: PraharTheme.primaryGreen, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Icon(
                                (_expandedWhy[alert.id] ?? false) ? Icons.expand_less : Icons.expand_more,
                                size: 16,
                                color: PraharTheme.primaryGreen,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_expandedWhy[alert.id] ?? false) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF09120E),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: PraharTheme.borderGreen),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isHindi
                                    ? 'प्राथमिक पहचान: Guy 3 Edge YOLOv8 (विश्वास: 88%)'
                                    : 'Primary Ground Truth: Guy 3 Edge YOLOv8 (Confidence: 88%)',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PraharTheme.primaryGreen),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _isHindi
                                    ? 'द्वितीयक मल्टीमॉडल साक्ष्य: सहमति (AGREEMENT - 85% विश्वास)'
                                    : 'Secondary Multimodal Evidence: AGREEMENT (Confidence: 85%)',
                                style: const TextStyle(fontSize: 10, color: PraharTheme.alertSky),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alert.type == HazardType.waterStress
                                    ? (_isHindi ? 'प्रेक्षित नमी: 17.5% | सुरक्षा सीमा: < 20.0%' : 'Observed Moisture: 17.5% | Safety Threshold: < 20.0%')
                                    : (_isHindi ? 'प्रेक्षित आर्द्रता: 78.0% | कवक अनुकूल सीमा: > 75.0%' : 'Observed RH: 78.0% | Fungal Favorable: > 75.0%'),
                                style: TextStyle(fontSize: 11, color: Colors.grey[300]),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Safety Gate Approval Action
                      if (alert.type == HazardType.waterStress) ...[
                        if (!alert.isApproved)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.water_drop, size: 16),
                              label: Text(
                                _isHindi ? 'सिंचाई स्वीकृत करें (30 सेकंड)' : 'Approve Micro-Irrigation (30s)',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PraharTheme.primaryGreen,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () => _approveAndIrrigate(alert),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: PraharTheme.borderGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check, size: 16, color: PraharTheme.primaryGreen),
                                const SizedBox(width: 6),
                                Text(
                                  _isHindi ? 'स्वीकृत - रोवर द्वारा उपचार पूरा' : 'Approved - Remediated by Rover',
                                  style: const TextStyle(fontSize: 12, color: PraharTheme.primaryGreen),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
      ],
    );
  }
}
