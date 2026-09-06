import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/storage/offline_store.dart';
import '../domain/models.dart';
import '../data/repositories/farm_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/analytics_repository.dart';
import 'field_evidence_report_screen.dart';

class FieldHealthAnalyticsScreen extends StatefulWidget {
  final ApiClient apiClient;
  final IOfflineStore offlineStore;
  final FarmRepository? farmRepository;
  final ZoneRepository? zoneRepository;
  final AnalyticsRepository? analyticsRepository;
  final String? initialFarmId;
  final String? initialZoneId;
  final bool initialIsHindi;

  const FieldHealthAnalyticsScreen({
    super.key,
    required this.apiClient,
    required this.offlineStore,
    this.farmRepository,
    this.zoneRepository,
    this.analyticsRepository,
    this.initialFarmId,
    this.initialZoneId,
    this.initialIsHindi = false,
  });

  @override
  State<FieldHealthAnalyticsScreen> createState() => _FieldHealthAnalyticsScreenState();
}

class _FieldHealthAnalyticsScreenState extends State<FieldHealthAnalyticsScreen> {
  late final FarmRepository _farmRepo;
  late final ZoneRepository _zoneRepo;
  late final AnalyticsRepository _analyticsRepo;

  bool _isHindi = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<FarmModel> _farms = [];
  FarmModel? _selectedFarm;
  List<ZoneModel> _zones = [];
  ZoneModel? _selectedZone;

  FarmAnalyticsSummaryModel? _summary;
  AnalyticsTrendsModel? _trends;
  AnalyticsInterventionsModel? _interventions;

  String _selectedMetricTab = 'moisture'; // 'moisture', 'temperature', 'humidity', 'ph'

  @override
  void initState() {
    super.initState();
    _isHindi = widget.initialIsHindi;
    _farmRepo = widget.farmRepository ??
        FarmRepository(apiClient: widget.apiClient, offlineStore: widget.offlineStore);
    _zoneRepo = widget.zoneRepository ??
        ZoneRepository(apiClient: widget.apiClient, offlineStore: widget.offlineStore);
    _analyticsRepo = widget.analyticsRepository ??
        AnalyticsRepository(apiClient: widget.apiClient, offlineStore: widget.offlineStore);

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final farms = await _farmRepo.getFarms();
      if (!mounted) return;

      setState(() {
        _farms = farms;
        if (_farms.isNotEmpty) {
          _selectedFarm = _farms.firstWhere(
            (f) => f.id == widget.initialFarmId,
            orElse: () => _farms.first,
          );
        } else {
          _selectedFarm = null;
        }
      });

      if (_selectedFarm != null) {
        final zones = await _zoneRepo.getZones(farmId: _selectedFarm!.id);
        if (!mounted) return;

        setState(() {
          _zones = zones;
          if (_zones.isNotEmpty) {
            _selectedZone = _zones.firstWhere(
              (z) => z.id == widget.initialZoneId,
              orElse: () => _zones.first,
            );
          } else {
            _selectedZone = null;
          }
        });

        await _fetchAnalytics();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Server error (${e.statusCode}): ${e.message}';
        });
      }
    } on NetworkUnavailableException {
      if (mounted) {
        setState(() {
          _errorMessage = _isHindi
              ? 'नेटवर्क अनुपलब्ध: ऑफ़लाइन डेटा लोड करने का प्रयास किया जा रहा है।'
              : 'Network Unavailable: Attempting offline cached data.';
        });
      }
      await _fetchAnalytics();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAnalytics() async {
    if (_selectedFarm == null) return;

    try {
      final summary = await _analyticsRepo.getSummary(
        farmId: _selectedFarm!.id,
        zoneId: _selectedZone?.id,
      );

      AnalyticsTrendsModel? trends;
      if (_selectedZone != null) {
        trends = await _analyticsRepo.getTrends(zoneId: _selectedZone!.id);
      }

      final interventions = await _analyticsRepo.getInterventions(
        farmId: _selectedFarm!.id,
        zoneId: _selectedZone?.id,
      );

      if (mounted) {
        setState(() {
          _summary = summary;
          _trends = trends;
          _interventions = interventions;
          _errorMessage = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Server error (${e.statusCode}): ${e.message}';
        });
      }
    } on NetworkUnavailableException {
      if (mounted) {
        setState(() {
          _errorMessage = null; // Cache fallback used
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Analytics error: $e';
        });
      }
    }
  }

  void _onFarmChanged(String? newFarmId) async {
    if (newFarmId == null || newFarmId == _selectedFarm?.id) return;
    final farm = _farms.firstWhere((f) => f.id == newFarmId);
    setState(() {
      _selectedFarm = farm;
      _selectedZone = null;
      _isLoading = true;
    });

    try {
      final zones = await _zoneRepo.getZones(farmId: farm.id);
      if (mounted) {
        setState(() {
          _zones = zones;
          _selectedZone = zones.isNotEmpty ? zones.first : null;
        });
        await _fetchAnalytics();
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onZoneChanged(String? newZoneId) async {
    if (newZoneId == null || newZoneId == _selectedZone?.id) return;
    final zone = _zones.firstWhere((z) => z.id == newZoneId);
    setState(() {
      _selectedZone = zone;
      _isLoading = true;
    });

    await _fetchAnalytics();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = _analyticsRepo.isLastFetchOffline;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: PraharTheme.primaryGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isHindi ? 'खेत स्वास्थ्य एवं रुझान' : 'Field Health & Trends',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Language toggle
          TextButton.icon(
            key: const Key('analytics_language_toggle'),
            icon: const Icon(Icons.language, color: PraharTheme.primaryGreen, size: 16),
            label: Text(
              _isHindi ? 'English' : 'हिन्दी',
              style: const TextStyle(color: PraharTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 12),
            ),
            onPressed: () {
              setState(() {
                _isHindi = !_isHindi;
              });
            },
          ),
          IconButton(
            key: const Key('export_report_button'),
            icon: const Icon(Icons.picture_as_pdf_outlined, color: PraharTheme.primaryGreen, size: 20),
            tooltip: _isHindi ? 'साक्ष्य रिपोर्ट जनरेट करें' : 'Export Evidence Report',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FieldEvidenceReportScreen(
                    apiClient: widget.apiClient,
                    offlineStore: widget.offlineStore,
                    farmRepository: _farmRepo,
                    zoneRepository: _zoneRepo,
                    initialFarmId: _selectedFarm?.id,
                    initialZoneId: _selectedZone?.id,
                    initialIsHindi: _isHindi,
                  ),
                ),
              );
            },
          ),
          IconButton(
            key: const Key('analytics_refresh_button'),
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: _isHindi ? 'रिफ्रेश करें' : 'Refresh',
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Offline Banner
          if (isOffline)
            Container(
              key: const Key('analytics_offline_banner'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PraharTheme.alertAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PraharTheme.alertAmber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off, color: PraharTheme.alertAmber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isHindi
                          ? 'ऑफ़लाइन मोड: स्थानीय कैश किया गया विश्लेषण दिखाया जा रहा है।'
                          : 'Offline Mode: Displaying cached local analytics.',
                      style: const TextStyle(color: PraharTheme.alertAmber, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          // Error Banner
          if (_errorMessage != null)
            Container(
              key: const Key('analytics_error_banner'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PraharTheme.alertRose.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PraharTheme.alertRose),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: PraharTheme.alertRose, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: PraharTheme.alertRose, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    key: const Key('analytics_retry_button'),
                    icon: const Icon(Icons.refresh, color: PraharTheme.alertRose, size: 18),
                    onPressed: _loadInitialData,
                  ),
                ],
              ),
            ),

          // Loading Indicator
          if (_isLoading)
            const Padding(
              key: Key('analytics_loading_indicator'),
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: PraharTheme.primaryGreen),
                ),
              ),
            ),

          // Farm & Zone Selectors Card
          Card(
            key: const Key('selectors_card'),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isHindi ? 'खेत और ज़ोन चयन' : 'Farm & Zone Selection',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Farm Selector
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isHindi ? 'खेत:' : 'Farm:', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C1410),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: PraharTheme.borderGreen),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  key: const Key('analytics_farm_selector'),
                                  isExpanded: true,
                                  value: _selectedFarm?.id,
                                  dropdownColor: const Color(0xFF131F19),
                                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                                  items: _farms.map((f) {
                                    return DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis));
                                  }).toList(),
                                  onChanged: _onFarmChanged,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Zone Selector
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_isHindi ? 'ज़ोन:' : 'Zone:', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0C1410),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: PraharTheme.borderGreen),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  key: const Key('analytics_zone_selector'),
                                  isExpanded: true,
                                  value: _selectedZone?.id,
                                  dropdownColor: const Color(0xFF131F19),
                                  style: const TextStyle(fontSize: 13, color: PraharTheme.primaryGreen, fontWeight: FontWeight.bold),
                                  items: _zones.map((z) {
                                    return DropdownMenuItem(value: z.id, child: Text(z.name, overflow: TextOverflow.ellipsis));
                                  }).toList(),
                                  onChanged: _onZoneChanged,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // 1. Current Health Summary Card
          _buildCurrentHealthCard(),
          const SizedBox(height: 14),

          // 2. Historical Sensor Trends Card
          _buildSensorTrendsCard(),
          const SizedBox(height: 14),

          // 3. Hazard & Risk Trends Card
          _buildHazardTrendsCard(),
          const SizedBox(height: 14),

          // 4. Closed-Loop Interventions & Verification History Card
          _buildInterventionsHistoryCard(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Section 1: Current Field / Zone Health Summary
  // --------------------------------------------------------------------------
  Widget _buildCurrentHealthCard() {
    final currentZoneSummary = _summary?.zones.firstWhere(
      (z) => z.zoneId == _selectedZone?.id,
      orElse: () => _summary!.zones.isNotEmpty ? _summary!.zones.first : _createPlaceholderZoneSummary(),
    );

    final status = currentZoneSummary?.healthStatus ?? _summary?.overallStatus ?? 'OPTIMAL';
    final isCritical = status == 'CRITICAL';
    final isAttention = status == 'ATTENTION_REQUIRED';

    final statusColor = isCritical
        ? PraharTheme.alertRose
        : (isAttention ? PraharTheme.alertAmber : PraharTheme.primaryGreen);

    final statusText = isCritical
        ? (_isHindi ? 'गंभीर तनाव (CRITICAL)' : 'CRITICAL')
        : (isAttention
            ? (_isHindi ? 'ध्यान आवश्यक (ATTENTION REQUIRED)' : 'ATTENTION REQUIRED')
            : (_isHindi ? 'सामान्य / इष्टतम (OPTIMAL)' : 'OPTIMAL'));

    final summaryText = _isHindi
        ? (currentZoneSummary?.summaryHi ?? _summary?.summaryHi ?? 'सभी प्रणालियां सामान्य हैं।')
        : (currentZoneSummary?.summaryEn ?? _summary?.summaryEn ?? 'All monitored zones operating normally.');

    final metrics = currentZoneSummary?.latestMetrics;

    return Card(
      key: const Key('field_health_summary_card'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isHindi ? 'प्रहार खेत-स्वास्थ्य सारांश' : 'PRAHAR Field-Health & Risk Summary',
                        style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedZone?.name ?? _selectedFarm?.name ?? 'Farm Health',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  key: const Key('field_health_status_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summaryText,
              key: const Key('field_health_summary_text'),
              style: TextStyle(color: Colors.grey[300], fontSize: 12),
            ),
            const Divider(height: 20, color: PraharTheme.borderGreen),
            // Latest Sensor Metrics Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricItem(
                  key: 'metric_moisture',
                  label: _isHindi ? 'नमी' : 'Moisture',
                  value: metrics?.moisturePct != null ? '${metrics!.moisturePct!.toStringAsFixed(1)}%' : '—',
                  icon: Icons.water_drop,
                  color: PraharTheme.alertSky,
                ),
                _buildMetricItem(
                  key: 'metric_temperature',
                  label: _isHindi ? 'तापमान' : 'Temp',
                  value: metrics?.temperatureC != null ? '${metrics!.temperatureC!.toStringAsFixed(1)}°C' : '—',
                  icon: Icons.thermostat,
                  color: PraharTheme.alertAmber,
                ),
                _buildMetricItem(
                  key: 'metric_humidity',
                  label: _isHindi ? 'आर्द्रता' : 'Humidity',
                  value: metrics?.humidityPct != null ? '${metrics!.humidityPct!.toStringAsFixed(1)}%' : '—',
                  icon: Icons.cloud,
                  color: PraharTheme.primaryGreen,
                ),
                _buildMetricItem(
                  key: 'metric_ph',
                  label: _isHindi ? 'मृदा pH' : 'Soil pH',
                  value: metrics?.ph != null ? metrics!.ph!.toStringAsFixed(1) : '—',
                  icon: Icons.science,
                  color: Colors.purpleAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required String key,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      key: Key(key),
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 10)),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Section 2: Historical Sensor Trends Chart
  // --------------------------------------------------------------------------
  Widget _buildSensorTrendsCard() {
    final trends = _trends?.sensorTrends ?? [];
    final hasData = _trends?.hasSufficientData == true && trends.isNotEmpty;

    return Card(
      key: const Key('historical_trends_card'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isHindi ? 'सेंसर रुझान (इतिहास)' : 'Historical Sensor Trends',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                // Metric switcher chips
                Row(
                  children: [
                    _buildMetricChip('moisture', _isHindi ? 'नमी' : 'Moist'),
                    const SizedBox(width: 4),
                    _buildMetricChip('temperature', _isHindi ? 'ताप' : 'Temp'),
                    const SizedBox(width: 4),
                    _buildMetricChip('humidity', _isHindi ? 'आर्द्र' : 'Hum'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasData)
              Container(
                key: const Key('empty_trends_state'),
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1410),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PraharTheme.borderGreen),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.show_chart, color: Colors.grey, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _isHindi
                          ? 'इस ज़ोन के लिए पर्याप्त ऐतिहासिक डेटा उपलब्ध नहीं है।'
                          : 'No historical sensor telemetry recorded yet for this zone.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Container(
                key: const Key('sensor_trend_chart'),
                height: 160,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1410),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PraharTheme.borderGreen),
                ),
                child: CustomPaint(
                  painter: _SparklineChartPainter(
                    points: trends,
                    metric: _selectedMetricTab,
                    lineColor: _selectedMetricTab == 'moisture'
                        ? PraharTheme.alertSky
                        : (_selectedMetricTab == 'temperature' ? PraharTheme.alertAmber : PraharTheme.primaryGreen),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String metricKey, String label) {
    final isSelected = _selectedMetricTab == metricKey;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMetricTab = metricKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? PraharTheme.primaryGreen : const Color(0xFF10281F),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? PraharTheme.primaryGreen : PraharTheme.borderGreen),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Section 3: Hazard & Detection Risk Breakdown
  // --------------------------------------------------------------------------
  Widget _buildHazardTrendsCard() {
    final hazards = _trends?.hazardBreakdown ?? [];

    return Card(
      key: const Key('hazard_trends_section'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isHindi ? 'जोखिम एवं पहचान रुझान' : 'Hazard & Detection Risk Trends',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (hazards.isEmpty)
              Container(
                key: const Key('empty_hazards_view'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1410),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PraharTheme.borderGreen),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: PraharTheme.primaryGreen, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isHindi
                            ? 'इस अवधि में कोई सक्रिय रोग या कीट जोखिम दर्ज नहीं हुआ।'
                            : 'No disease or pest risk detections recorded in this period.',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: hazards.map((h) {
                  final isCrit = h.highestSeverity == 'CRITICAL';
                  final isHigh = h.highestSeverity == 'HIGH';
                  final color = isCrit
                      ? PraharTheme.alertRose
                      : (isHigh ? PraharTheme.alertAmber : PraharTheme.alertSky);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C1410),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: PraharTheme.borderGreen),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: color, size: 16),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(h.hazardName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(
                                  '${h.occurrenceCount} ${_isHindi ? "पहचान" : "detections"} • ${(h.latestConfidence * 100).toInt()}% conf',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color),
                          ),
                          child: Text(
                            h.highestSeverity,
                            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Section 4: Closed-Loop Interventions & Verification History
  // --------------------------------------------------------------------------
  Widget _buildInterventionsHistoryCard() {
    final items = _interventions?.interventions ?? [];

    return Card(
      key: const Key('interventions_history_section'),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isHindi ? 'हस्तक्षेप एवं सत्यापन इतिहास' : 'Intervention & Verification History',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Container(
                key: const Key('empty_interventions_view'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1410),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PraharTheme.borderGreen),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, color: Colors.grey, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isHindi ? 'कोई उपचार या सत्यापन इतिहास नहीं है।' : 'No remediation actions or verifications on record.',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: items.map((item) {
                  final hasVerif = item.verification != null;
                  final isResolved = item.verification?.resolved == true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C1410),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isResolved ? PraharTheme.primaryGreen : PraharTheme.borderGreen,
                        width: isResolved ? 1.2 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.water_drop_outlined, color: PraharTheme.alertSky, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  '${item.actionType} (${item.durationSeconds}s, ~${item.volumeLiters}L)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: PraharTheme.primaryGreen.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.status,
                                style: const TextStyle(color: PraharTheme.primaryGreen, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_isHindi ? "स्वीकृतकर्ता" : "Approved by"}: ${item.approvedBy}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 11),
                        ),
                        if (hasVerif) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10281F),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isResolved ? Icons.check_circle : Icons.warning_amber_rounded,
                                      color: isResolved ? PraharTheme.primaryGreen : PraharTheme.alertAmber,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isResolved
                                          ? (_isHindi ? 'सत्यापन सफल' : 'Verification Succeeded')
                                          : (_isHindi ? 'सत्यापन अधूरा' : 'Verification Target Not Met'),
                                      style: TextStyle(
                                        color: isResolved ? PraharTheme.primaryGreen : PraharTheme.alertAmber,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${item.verification!.preMoisture}% → ${item.verification!.postMoisture}% (+${item.verification!.moistureDelta}%)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isHindi ? item.verification!.summaryHi : item.verification!.summaryEn,
                                  style: TextStyle(color: Colors.grey[300], fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  ZoneHealthSummaryModel _createPlaceholderZoneSummary() {
    return ZoneHealthSummaryModel(
      zoneId: _selectedZone?.id ?? 'ZONE-01',
      zoneName: _selectedZone?.name ?? 'Zone 1',
      farmId: _selectedFarm?.id ?? 'FARM-01',
      soilType: 'Loam',
      healthStatus: 'OPTIMAL',
      healthLabel: 'PRAHAR Field-Health & Risk Summary',
      summaryEn: 'No telemetry recorded for this zone yet.',
      summaryHi: 'इस ज़ोन के लिए अभी तक कोई टेलीमेट्री दर्ज नहीं है।',
      latestMetrics: LatestSensorMetricsModel(),
      activeAlertsCount: 0,
      recentHazardCount: 0,
      evaluatedAt: DateTime.now().toIso8601String(),
    );
  }
}

/// Custom Sparkline painter for zero-dependency historical sensor charts
class _SparklineChartPainter extends CustomPainter {
  final List<SensorTrendPointModel> points;
  final String metric;
  final Color lineColor;

  _SparklineChartPainter({
    required this.points,
    required this.metric,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    List<double> values = [];
    for (final p in points) {
      double? v;
      if (metric == 'moisture') v = p.moisturePct;
      else if (metric == 'temperature') v = p.temperatureC;
      else if (metric == 'humidity') v = p.humidityPct;
      else if (metric == 'ph') v = p.ph;

      if (v != null) values.add(v);
    }

    if (values.isEmpty) return;

    double minVal = values.reduce((a, b) => a < b ? a : b);
    double maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal == minVal) {
      maxVal += 1.0;
      minVal -= 1.0;
    }

    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw horizontal guidelines
    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), gridPaint);

    final path = Path();
    final double stepX = values.length > 1 ? size.width / (values.length - 1) : size.width;

    for (int i = 0; i < values.length; i++) {
      final normY = (values[i] - minVal) / (maxVal - minVal);
      final y = size.height - (normY * (size.height - 20) + 10);
      final x = i * stepX;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }

    canvas.drawPath(path, paint);

    // Min & Max label text
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Max: ${maxVal.toStringAsFixed(1)} | Min: ${minVal.toStringAsFixed(1)}',
        style: const TextStyle(color: Colors.grey, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(4, 4));
  }

  @override
  bool shouldRepaint(covariant _SparklineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.metric != metric;
  }
}
