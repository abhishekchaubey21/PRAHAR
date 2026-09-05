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

          // Farm Health Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isHindi ? 'डेमो खेत अल्फा' : 'Demo Farm Alpha',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isHindi
                      ? 'फसल: टमाटर • 3.5 एकड़ • 4 निगरानी वाले ज़ोन'
                      : 'Crop: Tomato • 3.5 Acres • 4 Monitored Zones',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const Divider(height: 24, color: PraharTheme.borderGreen),
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
