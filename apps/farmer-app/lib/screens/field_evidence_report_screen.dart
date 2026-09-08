import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/storage/offline_store.dart';
import '../domain/models.dart';
import '../data/repositories/farm_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/report_repository.dart';

class FieldEvidenceReportScreen extends StatefulWidget {
  final ApiClient apiClient;
  final IOfflineStore offlineStore;
  final FarmRepository? farmRepository;
  final ZoneRepository? zoneRepository;
  final ReportRepository? reportRepository;
  final String? initialFarmId;
  final String? initialZoneId;
  final bool initialIsHindi;

  const FieldEvidenceReportScreen({
    super.key,
    required this.apiClient,
    required this.offlineStore,
    this.farmRepository,
    this.zoneRepository,
    this.reportRepository,
    this.initialFarmId,
    this.initialZoneId,
    this.initialIsHindi = false,
  });

  @override
  State<FieldEvidenceReportScreen> createState() => _FieldEvidenceReportScreenState();
}

class _FieldEvidenceReportScreenState extends State<FieldEvidenceReportScreen> {
  late final FarmRepository _farmRepo;
  late final ZoneRepository _zoneRepo;
  late final ReportRepository _reportRepo;

  bool _isHindi = false;
  bool _isLoading = false;
  bool _isDownloadingPdf = false;
  String? _errorMessage;
  bool _isOfflineError = false;
  String? _downloadSuccessMessage;

  List<FarmModel> _farms = [];
  FarmModel? _selectedFarm;
  List<ZoneModel> _zones = [];
  ZoneModel? _selectedZone;

  // Selected period: '24h', '7d', '30d'
  String _selectedPeriod = '7d';

  FieldEvidenceReportModel? _report;

  static const String mandatoryDisclaimer =
      'This report is an informational field-evidence summary generated from PRAHAR system observations and AI/edge outputs. It is not an official government certificate, legal warranty, or guaranteed diagnosis.';

  static const String mandatoryDisclaimerHi =
      'यह रिपोर्ट प्रहार (PRAHAR) प्रणाली के अवलोकनों और एआई/एज आउटपुट से उत्पन्न एक सूचनात्मक साक्ष्य सारांश है। यह कोई आधिकारिक सरकारी प्रमाणपत्र, कानूनी वारंटी या गारंटीकृत निदान नहीं है।';

  @override
  void initState() {
    super.initState();
    _isHindi = widget.initialIsHindi;
    _farmRepo = widget.farmRepository ??
        FarmRepository(apiClient: widget.apiClient, offlineStore: widget.offlineStore);
    _zoneRepo = widget.zoneRepository ??
        ZoneRepository(apiClient: widget.apiClient, offlineStore: widget.offlineStore);
    _reportRepo = widget.reportRepository ??
        ReportRepository(apiClient: widget.apiClient);

    _loadFarmsAndZones();
  }

  Future<void> _loadFarmsAndZones() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOfflineError = false;
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
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  (String?, String?) _calculateDateRange() {
    final now = DateTime.now();
    DateTime from;
    switch (_selectedPeriod) {
      case '24h':
        from = now.subtract(const Duration(hours: 24));
        break;
      case '30d':
        from = now.subtract(const Duration(days: 30));
        break;
      case '7d':
      default:
        from = now.subtract(const Duration(days: 7));
        break;
    }
    return (from.toIso8601String(), now.toIso8601String());
  }

  Future<void> _generateReport() async {
    if (_selectedFarm == null) {
      setState(() {
        _errorMessage = _isHindi ? 'कृपया एक खेत चुनें' : 'Please select a farm';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOfflineError = false;
      _downloadSuccessMessage = null;
    });

    final (from, to) = _calculateDateRange();

    try {
      final report = await _reportRepo.generateReport(
        farmId: _selectedFarm!.id,
        zoneId: _selectedZone?.id,
        from: from,
        to: to,
        format: 'json',
      );

      if (!mounted) return;
      setState(() {
        _report = report;
      });
    } on NetworkUnavailableException {
      if (!mounted) return;
      setState(() {
        _isOfflineError = true;
        _errorMessage = _isHindi
            ? 'रिपोर्ट जनरेशन के लिए लाइव नेटवर्क कनेक्टिविटी अनिवार्य है। ऑफ़लाइन रिपोर्ट जनरेट नहीं की जा सकती।'
            : 'Report generation requires live backend connectivity. Cannot generate report while offline.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadPdf() async {
    if (_report == null && _selectedFarm == null) return;

    setState(() {
      _isDownloadingPdf = true;
      _errorMessage = null;
      _downloadSuccessMessage = null;
    });

    try {
      List<int>? bytes;
      if (_report?.pdfBase64 != null && _report!.pdfBase64!.isNotEmpty) {
        bytes = base64Decode(_report!.pdfBase64!);
      } else {
        final (from, to) = _calculateDateRange();
        bytes = await _reportRepo.downloadPdf(
          farmId: _selectedFarm!.id,
          zoneId: _selectedZone?.id,
          from: from,
          to: to,
        );
      }

      if (bytes.isEmpty) {
        throw Exception('Downloaded PDF is empty');
      }

      // Verify PDF header (PDF-1.4: %PDF-)
      final header = String.fromCharCodes(bytes.take(5));
      if (!header.startsWith('%PDF')) {
        throw Exception('Invalid PDF document received from server');
      }

      // On supported desktop/mobile, optionally write to temporary file
      final fileName = 'PRAHAR_Report_${_report?.reportId ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      try {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
      } catch (_) {
        // Filesystem writing might not be permitted in mock or restricted environments
      }

      if (!mounted) return;
      setState(() {
        _downloadSuccessMessage = _isHindi
            ? 'पीडीएफ सफलतापूर्वक तैयार की गई ($fileName, ${bytes!.length} बाइट्स)'
            : 'PDF successfully generated ($fileName, ${bytes!.length} bytes)';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('report_download_success'),
          backgroundColor: PraharTheme.primaryGreen,
          content: Text(
            _downloadSuccessMessage!,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } on NetworkUnavailableException {
      if (!mounted) return;
      setState(() {
        _isOfflineError = true;
        _errorMessage = _isHindi
            ? 'पीडीएफ डाउनलोड के लिए लाइव सर्वर कनेक्शन आवश्यक है।'
            : 'PDF download requires live server connection.';
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingPdf = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('field_evidence_report_screen'),
      backgroundColor: PraharTheme.darkBg,
      appBar: AppBar(
        title: Text(
          _isHindi ? 'फ़ील्ड साक्ष्य रिपोर्ट' : 'Field Evidence Report',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            key: const Key('report_language_toggle'),
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: PraharTheme.primaryGreen),
                borderRadius: BorderRadius.circular(6),
                color: PraharTheme.primaryGreen.withValues(alpha: 0.15),
              ),
              child: Text(
                _isHindi ? 'EN' : 'हिन्दी',
                style: const TextStyle(
                  color: PraharTheme.primaryGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            onPressed: () {
              setState(() {
                _isHindi = !_isHindi;
              });
            },
            tooltip: _isHindi ? 'Switch to English' : 'हिन्दी में बदलें',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mandatory Exact Disclaimer Banner at Top
              _buildDisclaimerBanner(),
              const SizedBox(height: 16),

              // Filter Controls: Farm, Zone, Period
              _buildControlsCard(),
              const SizedBox(height: 16),

              // Generate Action Button
              _buildGenerateButton(),
              const SizedBox(height: 16),

              // Error Banners
              if (_isOfflineError) _buildOfflineBanner(),
              if (_errorMessage != null && !_isOfflineError) _buildErrorBanner(),

              // Loading State
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(
                      key: Key('report_loading_indicator'),
                      color: PraharTheme.primaryGreen,
                    ),
                  ),
                ),

              // Report Preview Content
              if (!_isLoading && _report != null) ...[
                _buildReportPreviewCard(),
                const SizedBox(height: 16),
                _buildDownloadSection(),
              ],

              // Empty Initial State
              if (!_isLoading && _report == null && _errorMessage == null)
                _buildInitialEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      key: const Key('report_disclaimer_banner'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PraharTheme.alertAmber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: PraharTheme.alertAmber,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isHindi ? 'महत्वपूर्ण सूचना / अस्वीकरण' : 'NOTICE / DISCLAIMER',
                  style: const TextStyle(
                    color: PraharTheme.alertAmber,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isHindi ? mandatoryDisclaimerHi : mandatoryDisclaimer,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      key: const Key('report_controls_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isHindi ? 'रिपोर्ट कॉन्फ़िगरेशन' : 'Report Configuration',
              style: const TextStyle(
                color: PraharTheme.textHeading,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),

            // Farm Selector
            Text(
              _isHindi ? 'खेत (Farm):' : 'Farm:',
              style: const TextStyle(fontSize: 12, color: PraharTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PraharTheme.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  key: const Key('report_farm_selector'),
                  isExpanded: true,
                  value: _selectedFarm?.id,
                  dropdownColor: PraharTheme.cardBg,
                  style: const TextStyle(color: PraharTheme.textHeading, fontWeight: FontWeight.bold, fontSize: 14),
                  items: _farms.map((farm) {
                    return DropdownMenuItem<String>(
                      value: farm.id,
                      child: Text(farm.name, style: const TextStyle(color: PraharTheme.textHeading)),
                    );
                  }).toList(),
                  onChanged: (farmId) async {
                    if (farmId == null) return;
                    final farm = _farms.firstWhere((f) => f.id == farmId);
                    setState(() {
                      _selectedFarm = farm;
                      _selectedZone = null;
                      _zones = [];
                    });
                    final zones = await _zoneRepo.getZones(farmId: farm.id);
                    if (!mounted) return;
                    setState(() {
                      _zones = zones;
                      if (_zones.isNotEmpty) {
                        _selectedZone = _zones.first;
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Zone Selector
            Text(
              _isHindi ? 'ज़ोन (Zone - वैकल्पिक):' : 'Zone (Optional):',
              style: const TextStyle(fontSize: 12, color: PraharTheme.textMuted),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PraharTheme.borderLight),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  key: const Key('report_zone_selector'),
                  isExpanded: true,
                  value: _selectedZone?.id,
                  dropdownColor: PraharTheme.cardBg,
                  style: const TextStyle(color: PraharTheme.textHeading, fontWeight: FontWeight.bold, fontSize: 14),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        _isHindi ? 'संपूर्ण खेत (All Zones)' : 'Entire Farm (All Zones)',
                        style: const TextStyle(color: PraharTheme.textMuted),
                      ),
                    ),
                    ..._zones.map((zone) {
                      return DropdownMenuItem<String?>(
                        value: zone.id,
                        child: Text(zone.name, style: const TextStyle(color: PraharTheme.textHeading)),
                      );
                    }),
                  ],
                  onChanged: (zoneId) {
                    setState(() {
                      _selectedZone = zoneId != null ? _zones.firstWhere((z) => z.id == zoneId) : null;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Period Selector
            Text(
              _isHindi ? 'अवधि चुनें:' : 'Select Period:',
              style: const TextStyle(
                color: PraharTheme.textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPeriodChip('24h', _isHindi ? 'पिछला 24 घं' : 'Last 24h', const Key('period_selector_24h')),
                const SizedBox(width: 8),
                _buildPeriodChip('7d', _isHindi ? 'पिछले 7 दिन' : 'Last 7 Days', const Key('period_selector_7d')),
                const SizedBox(width: 8),
                _buildPeriodChip('30d', _isHindi ? 'पिछले 30 दिन' : 'Last 30 Days', const Key('period_selector_30d')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodChip(String value, String label, Key chipKey) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: InkWell(
        key: chipKey,
        onTap: () {
          setState(() {
            _selectedPeriod = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? PraharTheme.primaryGreen : PraharTheme.primaryGreenLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? PraharTheme.primaryGreen : PraharTheme.borderGreen,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : PraharTheme.darkGreen,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton.icon(
      key: const Key('generate_report_button'),
      onPressed: _isLoading ? null : _generateReport,
      style: ElevatedButton.styleFrom(
        backgroundColor: PraharTheme.primaryGreen,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.analytics_outlined, color: Colors.white),
      label: Text(
        _isHindi ? 'साक्ष्य रिपोर्ट तैयार करें' : 'Generate Evidence Report',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      key: const Key('report_offline_banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PraharTheme.alertRoseLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PraharTheme.alertRose),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: PraharTheme.alertRose),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage ?? 'Report generation requires live connectivity.',
              style: const TextStyle(color: PraharTheme.alertRose, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      key: const Key('report_error_banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PraharTheme.alertRoseLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PraharTheme.alertRose),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: PraharTheme.alertRose),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: PraharTheme.alertRose, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.document_scanner_outlined, size: 48, color: PraharTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            _isHindi
                ? 'लाइव फ़ील्ड साक्ष्य रिपोर्ट तैयार करने के लिए ऊपर दिए गए बटन पर टैप करें।'
                : 'Configure farm & period, then tap Generate Evidence Report.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: PraharTheme.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildReportPreviewCard() {
    final report = _report!;
    final isOptimal = report.healthStatus == 'OPTIMAL';
    final isCritical = report.healthStatus == 'CRITICAL';
    final statusColor = isOptimal
        ? PraharTheme.primaryGreen
        : isCritical
            ? PraharTheme.alertRose
            : PraharTheme.alertAmber;

    return Card(
      key: const Key('report_preview_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title and Report ID
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.reportTitle,
                        key: const Key('report_title_text'),
                        style: const TextStyle(
                          color: PraharTheme.textHeading,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${report.reportId}',
                        key: const Key('report_id_text'),
                        style: const TextStyle(
                          color: PraharTheme.textMuted,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    report.healthStatus,
                    key: const Key('report_health_status'),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: PraharTheme.borderLight, height: 24),

            // Metadata Grid: Farm, Zone, Timestamp
            Row(
              children: [
                Expanded(
                  child: _buildMetaItem(
                    _isHindi ? 'खेत (Farm)' : 'Farm',
                    report.farmName,
                  ),
                ),
                Expanded(
                  child: _buildMetaItem(
                    _isHindi ? 'ज़ोन (Zone)' : 'Zone',
                    report.zoneName ?? report.zoneId,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildMetaItem(
                    _isHindi ? 'जनरेट किया गया' : 'Generated At',
                    report.generatedAt.split('T').first,
                    key: const Key('report_timestamp_text'),
                  ),
                ),
                Expanded(
                  child: _buildMetaItem(
                    _isHindi ? 'फसल (Crop)' : 'Crop',
                    report.cropType ?? 'N/A',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Health Summary
            Text(
              report.healthLabel,
              style: const TextStyle(
                color: PraharTheme.primaryGreen,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isHindi && report.summaryHi.isNotEmpty ? report.summaryHi : report.summaryEn,
              key: const Key('report_health_summary'),
              style: const TextStyle(color: PraharTheme.textBody, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Sensor Readings Grid
            Text(
              _isHindi ? 'नवीनतम सेंसर माप' : 'Latest Sensor Evidence',
              style: const TextStyle(
                color: PraharTheme.textHeading,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSensorTile('Moisture', '${report.moisture.toStringAsFixed(1)}%'),
                const SizedBox(width: 8),
                _buildSensorTile('Temp', '${report.temperature.toStringAsFixed(1)}°C'),
                const SizedBox(width: 8),
                _buildSensorTile('Humidity', '${report.humidity.toStringAsFixed(1)}%'),
                const SizedBox(width: 8),
                _buildSensorTile('pH', report.ph.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 16),

            // Hazards Section
            Text(
              _isHindi ? 'पहचाने गए खतरे (${report.hazardHistory.length})' : 'Detected Hazards (${report.hazardHistory.length})',
              style: const TextStyle(
                color: PraharTheme.textHeading,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              key: const Key('report_hazards_list'),
              child: report.hazardHistory.isEmpty
                  ? Text(
                      _isHindi ? 'चयनित अवधि में कोई गंभीर खतरा दर्ज नहीं हुआ।' : 'No active hazards detected in period.',
                      style: const TextStyle(color: PraharTheme.textMuted, fontSize: 12),
                    )
                  : Column(
                      children: report.hazardHistory.take(3).map((h) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: PraharTheme.cardBgGreen,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: PraharTheme.borderGreen),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                h.hazardName,
                                style: const TextStyle(color: PraharTheme.textHeading, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              Text(
                                '${h.severity} (${(h.confidence * 100).toInt()}%)',
                                style: TextStyle(
                                  color: h.severity == 'HIGH' ? PraharTheme.alertRose : PraharTheme.alertAmber,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 16),

            // Closed-Loop Remediation & Verification Outcome
            Text(
              _isHindi ? 'हस्तक्षेप व सत्यापन परिणाम' : 'Intervention & Verification Outcome',
              style: const TextStyle(
                color: PraharTheme.textHeading,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              key: const Key('report_interventions_list'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PraharTheme.cardBgGreen,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: PraharTheme.borderGreen),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Action: ${report.actionExecuted}',
                    style: const TextStyle(color: PraharTheme.textHeading, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.verificationOutcome,
                    key: const Key('report_verification_outcome'),
                    style: const TextStyle(color: PraharTheme.primaryGreen, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Recommendations
            if (report.recommendations.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _isHindi ? 'प्रहार सिफारिशें' : 'PRAHAR Recommendations',
                style: const TextStyle(
                  color: PraharTheme.textHeading,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                key: const Key('report_recommendations_list'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: report.recommendations.map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: PraharTheme.primaryGreen)),
                          Expanded(
                            child: Text(
                              r,
                              style: const TextStyle(color: PraharTheme.textBody, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, {Key? key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: PraharTheme.textMuted, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: PraharTheme.textHeading, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSensorTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: PraharTheme.cardBgGreen,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: PraharTheme.borderGreen),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: PraharTheme.textMuted, fontSize: 10),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(color: PraharTheme.textHeading, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadSection() {
    return ElevatedButton.icon(
      key: const Key('download_pdf_button'),
      onPressed: _isDownloadingPdf ? null : _downloadPdf,
      style: ElevatedButton.styleFrom(
        backgroundColor: PraharTheme.cardBgGreen,
        foregroundColor: PraharTheme.darkGreen,
        side: const BorderSide(color: PraharTheme.primaryGreen, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: _isDownloadingPdf
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: PraharTheme.primaryGreen),
            )
          : const Icon(Icons.picture_as_pdf, color: PraharTheme.primaryGreen),
      label: Text(
        _isDownloadingPdf
            ? (_isHindi ? 'डाउनलोड हो रहा है...' : 'Downloading PDF...')
            : (_isHindi ? 'आधिकारिक पीडीएफ डाउनलोड करें' : 'Download / Export PDF'),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    );
  }
}
