import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../core/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Demo State (Phase 1 Skeleton)
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
      message: 'Moisture dropped to 17.5%. Micro-irrigation recommended.',
      recommendedAction: 'Trigger simulated irrigation (30s)',
      status: AlertStatus.newAlert,
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    AlertModel(
      id: 'alert-02',
      zoneId: 'DEMO-ZONE-03',
      zoneName: 'Zone 3 (South Sector)',
      type: HazardType.disease,
      severity: AlertSeverity.medium,
      message: 'Suspected Early Blight detected on basal leaves.',
      recommendedAction: 'Expert verification in progress.',
      status: AlertStatus.newAlert,
      timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('PRAHAR'),
            SizedBox(width: 8),
            Chip(
              label: Text('Farmer v0.1', style: TextStyle(fontSize: 10, color: Colors.white)),
              backgroundColor: PraharTheme.borderGreen,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Farm Health Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Demo Farm Alpha',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Crop: Tomato • 3.5 Acres • 4 Monitored Zones',
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                  const Divider(height: 24, color: PraharTheme.borderGreen),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric('Active Alerts', '${_alerts.length}', PraharTheme.alertAmber),
                      _buildMetric('Soil Moisture', '28% avg', PraharTheme.primaryGreen),
                      _buildMetric('Rover Battery', '${_rover.batteryPct.toInt()}%', PraharTheme.primaryGreen),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Rover Control Banner
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: PraharTheme.borderGreen,
                    child: Icon(Icons.precision_manufacturing, color: PraharTheme.primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rover: ${_rover.roverId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Status: ${_rover.state} • At ${_rover.currentZone}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PraharTheme.primaryGreen,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Scan requested: dispatching to simulator via API...')),
                      );
                    },
                    child: const Text('Scan Now'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Alert Feed Header
          const Text(
            'Active Field Alerts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      Text(alert.message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text(
                        'Recommended: ${alert.recommendedAction}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
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
