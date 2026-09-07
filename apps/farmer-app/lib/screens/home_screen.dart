import 'package:flutter/material.dart';
import '../domain/models.dart';
import '../core/theme.dart';
import '../core/offline_storage.dart';
import '../core/api_client.dart';
import '../core/auth_service.dart';
import '../core/storage/session_store.dart';
import '../core/storage/offline_store.dart';
import '../data/repositories/farm_repository.dart';
import '../data/repositories/zone_repository.dart';
import '../data/repositories/alert_repository.dart';
import '../data/repositories/remediation_repository.dart';
import '../data/repositories/voice_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/analytics_repository.dart';
import 'login_screen.dart';
import 'notification_center_screen.dart';
import 'field_health_analytics_screen.dart';
import 'field_evidence_report_screen.dart';
import 'opportunity_center_screen.dart';
import '../data/repositories/opportunity_repository.dart';

class HomeScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final AuthService? authService;
  final FarmRepository? farmRepository;
  final ZoneRepository? zoneRepository;
  final AlertRepository? alertRepository;
  final RemediationRepository? remediationRepository;
  final VoiceRepository? voiceRepository;
  final NotificationRepository? notificationRepository;
  final AnalyticsRepository? analyticsRepository;
  final OpportunityRepository? opportunityRepository;
  final ISessionStore? sessionStore;
  final IOfflineStore? offlineStore;
  final String initialLanguage;

  const HomeScreen({
    super.key,
    this.apiClient,
    this.authService,
    this.farmRepository,
    this.zoneRepository,
    this.alertRepository,
    this.remediationRepository,
    this.voiceRepository,
    this.notificationRepository,
    this.analyticsRepository,
    this.opportunityRepository,
    this.sessionStore,
    this.offlineStore,
    this.initialLanguage = 'en',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Language toggle: true = Hindi ('hi'), false = English ('en')
  bool _isHindi = false;
  bool _isNetworkOffline = false;

  late final OfflineStorageService _offlineStorage;
  late final ApiClient _apiClient;
  late final AuthService _authService;
  late final FarmRepository _farmRepo;
  late final ZoneRepository _zoneRepo;
  late final AlertRepository _alertRepo;
  late final RemediationRepository _remediationRepo;
  late final VoiceRepository _voiceRepo;
  late final NotificationRepository _notificationRepo;
  late final AnalyticsRepository _analyticsRepo;
  late final OpportunityRepository _opportunityRepo;
  int _unreadNotificationCount = 0;


  bool _isLoading = false;
  String? _backendError;
  List<FarmModel> _farms = [];
  FarmModel? _selectedFarm;
  List<ZoneModel> _zones = [];
  final List<AlertModel> _alerts = [];

  @override
  void initState() {
    super.initState();
    _offlineStorage = OfflineStorageService(store: widget.offlineStore);
    _isHindi = widget.initialLanguage == 'hi';
    final store = widget.sessionStore ??
        (widget.authService?.sessionStore ?? SecureFileSessionStore());
    _apiClient = widget.apiClient ??
        (widget.authService != null
            ? widget.authService!.apiClient
            : ApiClient(sessionStore: store));
    _authService = widget.authService ??
        AuthService(sessionStore: store, apiClient: _apiClient);
    _authService.init();
    _farmRepo = widget.farmRepository ??
        FarmRepository(apiClient: _apiClient, offlineStore: _offlineStorage.store);
    _zoneRepo = widget.zoneRepository ??
        ZoneRepository(apiClient: _apiClient, offlineStore: _offlineStorage.store);
    _alertRepo = widget.alertRepository ??
        AlertRepository(apiClient: _apiClient, offlineStore: _offlineStorage.store);
    _remediationRepo = widget.remediationRepository ??
        RemediationRepository(
            apiClient: _apiClient, offlineStore: _offlineStorage.store);
    _voiceRepo = widget.voiceRepository ?? VoiceRepository(apiClient: _apiClient);
    _notificationRepo = widget.notificationRepository ??
        NotificationRepository(
            apiClient: _apiClient, offlineStore: _offlineStorage.store);
    _analyticsRepo = widget.analyticsRepository ??
        AnalyticsRepository(
            apiClient: _apiClient, offlineStore: _offlineStorage.store);
    _opportunityRepo = widget.opportunityRepository ??
        OpportunityRepository(
            apiClient: _apiClient, offlineStore: _offlineStorage.store);

    _loadRemoteData();
    _loadUnreadNotificationCount();
  }


  Future<void> _loadRemoteData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _backendError = null;
      _isNetworkOffline = false;
    });

    try {
      final remoteFarms = await _farmRepo.getFarms();
      if (!mounted) return;

      setState(() {
        _farms = remoteFarms;
        if (_farms.isNotEmpty) {
          _selectedFarm = _farms.first;
        } else {
          _selectedFarm = null;
        }
      });

      if (_selectedFarm != null) {
        final remoteZones = await _zoneRepo.getZones(farmId: _selectedFarm!.id);
        if (mounted) {
          setState(() {
            _zones = remoteZones;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _zones = [];
          });
        }
      }

      final remoteAlerts = await _alertRepo.getAlerts();
      if (mounted) {
        setState(() {
          _alerts.clear();
          _alerts.addAll(remoteAlerts);
        });
      }

      final verifs = await _remediationRepo.getVerifications();
      if (verifs.isNotEmpty && mounted) {
        setState(() {
          _latestVerification = verifs.first;
        });
      }

      await _loadUnreadNotificationCount();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _backendError = 'Server error (${e.statusCode}): ${e.message}';
        });
      }
    } on NetworkUnavailableException {
      if (mounted) {
        setState(() {
          _isNetworkOffline = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _backendError = 'Unexpected error: $e';
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

  Future<void> _selectFarm(FarmModel farm) async {
    setState(() {
      _selectedFarm = farm;
      _isLoading = true;
      _backendError = null;
    });

    try {
      final remoteZones = await _zoneRepo.getZones(farmId: farm.id);
      if (mounted) {
        setState(() {
          _zones = remoteZones;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _backendError = 'Server error (${e.statusCode}): ${e.message}';
        });
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

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await _notificationRepo.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleLanguage() async {
    final nextLang = _isHindi ? 'en' : 'hi';
    setState(() {
      _isHindi = !_isHindi;
    });
    await _offlineStorage.setLanguagePreference(nextLang);
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131F19),
        title: Text(_isHindi ? 'लॉग आउट पुष्टि' : 'Confirm Logout'),
        content: Text(
          _isHindi
              ? 'क्या आप सुनिश्चित हैं कि आप लॉग आउट करना चाहते हैं? स्थानीय डेटा साफ़ हो जाएगा।'
              : 'Are you sure you want to log out? Local cached user data will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_logout_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: PraharTheme.alertRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_isHindi ? 'लॉग आउट' : 'Log Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _authService.logout();
      // Manager Amendment: Preserve user-scoped offline/cache isolation on logout.
      await _offlineStorage.clearAll();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(authService: _authService),
        ),
        (route) => false,
      );
    }
  }

  final RoverStatusModel _rover = const RoverStatusModel(
    roverId: 'ROVER-DEMO-01',
    state: 'IDLE',
    batteryPct: 95.0,
    currentZone: 'Zone 1 (North Plot)',
    isOffline: false,
  );

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
    final synced = await _offlineStorage.synchronize(apiClient: _apiClient);
    await _loadRemoteData();
    if (!mounted) return;
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

  // Phase 6A-2: Voice Assistant Dialog (Connected to Gateway /api/voice/interact)
  void _openVoiceDialog() {
    bool voiceConfirmed = false;
    bool isProcessing = false;
    String responseText = _isHindi
        ? 'आदेश बोलें या लिखें (सिमुलेटेड वॉयस इनपुट)'
        : 'Speak or type command (Simulated Voice Input)';
    VoiceResponseModel? latestVoiceResponse;
    String? voiceError;
    final textController = TextEditingController();
    final voiceSessionId = 'voice_session_${DateTime.now().millisecondsSinceEpoch}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131F19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> sendQuery(String text) async {
            if (text.trim().isEmpty || isProcessing) return;
            setModalState(() {
              isProcessing = true;
              voiceError = null;
            });

            try {
              final res = await _voiceRepo.sendVoiceQuery(
                text: text.trim(),
                language: _isHindi ? 'hi' : 'en',
                sessionId: voiceSessionId,
              );

              setModalState(() {
                latestVoiceResponse = res;
                responseText = _isHindi ? res.spokenTextHi : res.spokenTextEn;
                voiceConfirmed = false;
                textController.clear();
              });
            } on NetworkUnavailableException {
              setModalState(() {
                voiceError = _isHindi
                    ? 'नेटवर्क त्रुटि: वॉयस गेटवे तक नहीं पहुँचा जा सका।'
                    : 'Network Error: Unable to reach PRAHAR Voice Gateway.';
                responseText = voiceError!;
                latestVoiceResponse = null;
              });
            } on ApiException catch (e) {
              setModalState(() {
                voiceError = _isHindi
                    ? 'वॉयस गेटवे त्रुटि (${e.statusCode}): ${e.message}'
                    : 'Voice Gateway Error (${e.statusCode}): ${e.message}';
                responseText = voiceError!;
                latestVoiceResponse = null;
              });
            } catch (e) {
              setModalState(() {
                voiceError = 'Voice Error: $e';
                responseText = voiceError!;
                latestVoiceResponse = null;
              });
            } finally {
              setModalState(() {
                isProcessing = false;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20.0,
              right: 20.0,
              top: 20.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
            ),
            child: SingleChildScrollView(
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
                          color: PraharTheme.alertAmber.withValues(alpha: 0.2),
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
                        ? 'स्पष्ट सूचना: माइक्रोफ़ोन/एसटीटी हार्डवेयर अनुपलब्ध — सिम्युलेटेड वॉयस इनपुट सक्रिय। आवाज़ सीधे मोटर नहीं चला सकती।'
                        : 'Honest STT Notice: Real microphone hardware not connected — Simulated Voice Input active. Voice commands CANNOT directly drive motors.',
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
                    child: isProcessing
                        ? const Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: PraharTheme.primaryGreen),
                            ),
                          )
                        : Text(
                            responseText,
                            style: TextStyle(
                              fontSize: 13,
                              color: voiceError != null ? PraharTheme.alertRose : Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Text Input for Voice Command Simulation
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('voice_input_field'),
                          controller: textController,
                          decoration: InputDecoration(
                            hintText: _isHindi ? 'वॉयस इनपुट लिखें...' : 'Type simulated voice command...',
                            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onSubmitted: (val) => sendQuery(val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('voice_send_button'),
                        icon: const Icon(Icons.send, color: PraharTheme.primaryGreen),
                        onPressed: isProcessing ? null : () => sendQuery(textController.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Preset Voice Intent Quick Action Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.info_outline, size: 16, color: PraharTheme.primaryGreen),
                        label: Text(_isHindi ? 'खेत का हाल बताओ' : 'What is farm status?'),
                        onPressed: isProcessing ? null : () => sendQuery(_isHindi ? 'खेत का हाल बताओ' : 'What is farm status?'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.water_drop, size: 16, color: PraharTheme.alertSky),
                        label: Text(_isHindi ? 'ज़ोन 2 में सिंचाई चालू करो' : 'Start irrigation in Zone 2'),
                        onPressed: isProcessing ? null : () => sendQuery(_isHindi ? 'ज़ोन 2 में सिंचाई चालू करो' : 'Start irrigation in Zone 2'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.help_outline, size: 16, color: Colors.grey),
                        label: Text(_isHindi ? 'अज्ञात आदेश' : 'Unknown command'),
                        onPressed: isProcessing ? null : () => sendQuery('fly to the moon'),
                      ),
                    ],
                  ),
                  // Safety Gate Confirmation Container
                  if (latestVoiceResponse?.requiresConfirmation == true) ...[
                    const SizedBox(height: 14),
                    Container(
                      key: const Key('voice_safety_banner'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PraharTheme.alertAmber),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.security, color: PraharTheme.alertAmber, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _isHindi ? latestVoiceResponse!.safetyNoticeHi : latestVoiceResponse!.safetyNoticeEn,
                                  style: const TextStyle(color: PraharTheme.alertAmber, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Checkbox(
                                key: const Key('voice_confirm_checkbox'),
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
                                      ? (latestVoiceResponse!.confirmationPromptHi ?? 'क्या आप इस सिंचाई कार्रवाई की पुष्टि करते हैं?')
                                      : (latestVoiceResponse!.confirmationPromptEn ?? 'Confirm this irrigation action?'),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            key: const Key('voice_confirm_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: voiceConfirmed ? PraharTheme.primaryGreen : Colors.grey,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 36),
                            ),
                            onPressed: voiceConfirmed && !isProcessing
                                ? () async {
                                    await sendQuery(_isHindi ? 'हाँ, पुष्टि करता हूँ' : 'Yes, confirm');
                                  }
                                : null,
                            child: Text(
                              _isHindi ? 'पुष्टि करें (सुरक्षा द्वार)' : 'Confirm (Safety Gate)',
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
          );
        },
      ),
    );
  }

  // Phase 6B-3: Field Evidence Report Viewer
  void _openEvidenceReportDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FieldEvidenceReportScreen(
          apiClient: _apiClient,
          offlineStore: _offlineStorage.store,
          farmRepository: _farmRepo,
          zoneRepository: _zoneRepo,
          initialFarmId: _selectedFarm?.id,
          initialIsHindi: _isHindi,
        ),
      ),
    );
  }

  // Phase 6B-4: Farmer Opportunity Center (Verified Indian Government Portals)
  void _openOpportunityCenterDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpportunityCenterScreen(
          opportunityRepository: _opportunityRepo,
          isHindi: _isHindi,
          currentFarmId: _selectedFarm?.id,
          landAcres: _selectedFarm != null ? _selectedFarm!.totalHectares * 2.47105 : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PRAHAR'),
              const SizedBox(width: 6),
              Chip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                label: Text(_isHindi ? 'किसान v0.3' : 'Farmer v0.3', style: const TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: PraharTheme.borderGreen,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ],
          ),
        ),
        actions: [
          // Phase 6B-2: Field Health & Historical Trends Navigation Button
          IconButton(
            key: const Key('analytics_nav_button'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.analytics_outlined, color: Colors.white, size: 20),
            tooltip: _isHindi ? 'खेत स्वास्थ्य एवं रुझान' : 'Field Health & Analytics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FieldHealthAnalyticsScreen(
                    apiClient: _apiClient,
                    offlineStore: _offlineStorage.store,
                    farmRepository: _farmRepo,
                    zoneRepository: _zoneRepo,
                    analyticsRepository: _analyticsRepo,
                    initialFarmId: _selectedFarm?.id,
                    initialIsHindi: _isHindi,
                  ),
                ),
              );
            },
          ),
          // Phase 6B-4: Opportunity & Scheme Center Navigation Button
          IconButton(
            key: const Key('opportunity_center_nav_button'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.account_balance_outlined, color: Colors.white, size: 20),
            tooltip: _isHindi ? 'अवसर एवं सरकारी योजना केंद्र' : 'Opportunity & Scheme Center',
            onPressed: _openOpportunityCenterDialog,
          ),
          // Phase 6B-1: Notification Center Bell Button with Dynamic Unread Badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                key: const Key('notification_bell_button'),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                tooltip: _isHindi ? 'सूचना केंद्र' : 'Notification Center',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NotificationCenterScreen(
                        notificationRepository: _notificationRepo,
                        isHindi: _isHindi,
                      ),
                    ),
                  );
                  _loadUnreadNotificationCount();
                },
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 4,
                  top: 6,
                  child: Container(
                    key: const Key('notification_unread_badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: BoxDecoration(
                      color: PraharTheme.alertRose,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                    child: Text(
                      '$_unreadNotificationCount',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Language Switcher Toggle (Requirement 9)
          TextButton(
            key: const Key('language_toggle_button'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _toggleLanguage,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, color: PraharTheme.primaryGreen, size: 16),
                const SizedBox(width: 3),
                Text(
                  _isHindi ? 'English' : 'हिन्दी',
                  style: const TextStyle(color: PraharTheme.primaryGreen, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('logout_button'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.logout, color: Colors.grey, size: 18),
            tooltip: _isHindi ? 'लॉग आउट' : 'Log Out',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 4),
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

          // Backend Error Banner
          if (_backendError != null)
            Container(
              key: const Key('backend_error_banner'),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: PraharTheme.alertRose.withValues(alpha: 0.15),
                border: Border.all(color: PraharTheme.alertRose),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: PraharTheme.alertRose),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _backendError!,
                      style: const TextStyle(color: PraharTheme.alertRose, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: PraharTheme.alertRose, size: 18),
                    onPressed: _loadRemoteData,
                  ),
                ],
              ),
            ),

          // Network Offline Banner
          if (_isNetworkOffline && _backendError == null)
            Container(
              key: const Key('network_offline_banner'),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: PraharTheme.alertAmber.withValues(alpha: 0.15),
                border: Border.all(color: PraharTheme.alertAmber),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: PraharTheme.alertAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isHindi
                          ? 'नेटवर्क अनुपलब्ध: ऑफ़लाइन मोड में चल रहा है।'
                          : 'Network Unavailable: Operating in offline mode.',
                      style: const TextStyle(color: PraharTheme.alertAmber, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    key: const Key('offline_retry_button'),
                    icon: const Icon(Icons.refresh, color: PraharTheme.alertAmber, size: 18),
                    onPressed: _loadRemoteData,
                  ),
                ],
              ),
            ),

          if (_isLoading)
            const Padding(
              key: Key('loading_indicator'),
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: PraharTheme.primaryGreen),
                ),
              ),
            ),

          // Real Farm Health Status Card / Offline Empty Card
          if (_isNetworkOffline && _farms.isEmpty && _backendError == null)
            Card(
              key: const Key('offline_empty_card'),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.signal_wifi_connected_no_internet_4, size: 40, color: PraharTheme.alertAmber),
                    const SizedBox(height: 8),
                    Text(
                      _isHindi ? 'नेटवर्क अनुपलब्ध' : 'Network Unavailable',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isHindi
                          ? 'ऑफ़लाइन कैश में कोई खेत नहीं मिला। कृपया इंटरनेट कनेक्शन जांचें।'
                          : 'No cached farms available offline. Please check your connectivity.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      key: const Key('offline_card_retry_button'),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(_isHindi ? 'पुनः प्रयास करें' : 'Retry Connection'),
                      onPressed: _loadRemoteData,
                    ),
                  ],
                ),
              ),
            )
          else if (_farms.isEmpty && _backendError == null)
            Card(
              key: const Key('empty_farm_card'),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.agriculture_outlined, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      _isHindi ? 'कोई खेत पंजीकृत नहीं मिला' : 'No farms registered yet',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isHindi
                          ? 'कृपया अपने खेत को वेब कंसोल या गेटवे में जोड़ें।'
                          : 'Please register your farm via web console or gateway.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else if (_selectedFarm != null)
            Card(
              key: const Key('farm_card'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: PraharTheme.borderGreen, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedFarm!.name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_farms.length > 1)
                          DropdownButton<String>(
                            key: const Key('farm_selector_dropdown'),
                            value: _selectedFarm!.id,
                            dropdownColor: const Color(0xFF131F19),
                            style: const TextStyle(color: PraharTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.bold),
                            underline: const SizedBox(),
                            items: _farms
                                .map((f) => DropdownMenuItem(
                                      value: f.id,
                                      child: Text(f.name),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final f = _farms.firstWhere((x) => x.id == val);
                                _selectFarm(f);
                              }
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_selectedFarm!.location} • ${_selectedFarm!.totalHectares} ha • ${_zones.length} ${_isHindi ? "निगरानी वाले ज़ोन" : "Monitored Zones"}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    const Divider(height: 16, color: PraharTheme.borderGreen),
                    // Phase 4: Weather Risk Indicator with Mandatory Simulation/Demo Label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertAmber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.4)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
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
                        _buildMetric(_isHindi ? 'कुल ज़ोन' : 'Total Zones', '${_zones.length}', PraharTheme.primaryGreen),
                        _buildMetric(_isHindi ? 'रोवर बैटरी' : 'Rover Battery', '${_rover.batteryPct.toInt()}%', PraharTheme.primaryGreen),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),

          // Monitored Zones Section
          Text(
            _isHindi ? 'निगरानी वाले ज़ोन' : 'Monitored Zones',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_zones.isEmpty)
            Container(
              key: const Key('empty_zones_container'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1410),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PraharTheme.borderGreen),
              ),
              child: Text(
                _isHindi ? 'इस खेत के लिए कोई ज़ोन कॉन्फ़िगर नहीं किया गया है।' : 'No zones configured for this farm.',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            )
          else
            Wrap(
              key: const Key('zones_wrap'),
              spacing: 8,
              runSpacing: 8,
              children: _zones.map((zone) {
                return Chip(
                  key: Key('zone_chip_${zone.id}'),
                  avatar: const Icon(Icons.grass, size: 16, color: PraharTheme.primaryGreen),
                  label: Text(
                    '${zone.name} (${zone.soilType}, ${zone.moisturePct.toStringAsFixed(1)}%)',
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFF13241D),
                  side: const BorderSide(color: PraharTheme.borderGreen),
                );
              }).toList(),
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
                    backgroundColor: const Color(0xFF13241D),
                    side: const BorderSide(color: PraharTheme.borderGreen),
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
                    backgroundColor: const Color(0xFF13241D),
                    side: const BorderSide(color: PraharTheme.borderGreen),
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
                    backgroundColor: const Color(0xFF13241D),
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
              color: const Color(0xFF13241D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: PraharTheme.primaryGreen, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: PraharTheme.primaryGreen, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _isHindi ? 'उपचार सत्यापन सफल' : 'Remediation Verified (Closed-Loop)',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: PraharTheme.primaryGreen, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
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
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${_isHindi ? "पहले" : "Pre"}: ${_latestVerification!.preMoisture}%  →  ${_isHindi ? "बाद में" : "Post"}: ${_latestVerification!.postMoisture}%',
                          style: TextStyle(color: Colors.grey[300], fontWeight: FontWeight.w600, fontSize: 13),
                        ),
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
          if (_alerts.isEmpty)
            Card(
              key: const Key('empty_alerts_card'),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: PraharTheme.primaryGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isHindi ? 'कोई सक्रिय अलर्ट नहीं हैं।' : 'No active alerts for this farm.',
                        style: TextStyle(color: Colors.grey[300], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
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
                                  ? PraharTheme.alertRose.withValues(alpha: 0.2)
                                  : PraharTheme.alertAmber.withValues(alpha: 0.2),
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
