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
import '../domain/farmer_profile.dart';
import '../data/repositories/farmer_profile_repository.dart';
import '../data/providers/telemetry_provider.dart';
import 'onboarding_screen.dart';
import '../domain/assistant_model.dart';
import '../data/repositories/field_assistant_repository.dart';
import '../data/assistant/assistant_context_builder.dart';
import '../data/assistant/field_assistant_engine.dart';
import '../core/localization/app_localizations.dart';

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
  final FarmerProfileRepository? farmerProfileRepository;
  final FieldAssistantRepository? fieldAssistantRepository;
  final ITelemetryProvider? telemetryProvider;
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
    this.farmerProfileRepository,
    this.fieldAssistantRepository,
    this.telemetryProvider,
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
  String _currentLanguage = 'en';
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
  late final FarmerProfileRepository _farmerProfileRepo;
  late final ITelemetryProvider _telemetryProvider;
  late final FieldAssistantEngine _assistantEngine;
  int _unreadNotificationCount = 0;

  FarmerOnboardingState? _onboardingState;
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
    _currentLanguage = widget.initialLanguage;
    _isHindi = _currentLanguage == 'hi';
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
    _farmerProfileRepo = widget.farmerProfileRepository ??
        FarmerProfileRepository(
            apiClient: _apiClient, offlineStore: _offlineStorage.store);
    final assistantRepo = widget.fieldAssistantRepository ?? FieldAssistantRepository(apiClient: _apiClient);
    _assistantEngine = FieldAssistantEngine(repository: assistantRepo);
    _telemetryProvider = widget.telemetryProvider ?? DemoFieldDataProvider();

    _loadProfile();
    _loadRemoteData();
    _loadUnreadNotificationCount();
  }

  Future<void> _loadProfile() async {
    try {
      final state = await _farmerProfileRepo.getOnboardingState();
      if (mounted) {
        setState(() {
          _onboardingState = state;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _onboardingState = FarmerOnboardingState.canonicalDemo();
        });
      }
    }
  }

  Future<void> _openOnboardingEdit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(
          profileRepository: _farmerProfileRepo,
          authService: _authService,
          offlineStore: _offlineStorage.store,
          initialLanguage: _currentLanguage,
          isEditing: true,
        ),
      ),
    );
    if (result == true && mounted) {
      await _loadProfile();
      await _loadRemoteData();
    }
  }

  String get _farmerIdentityTitle {
    final name = _onboardingState?.profile.name ?? 'Ramesh Patil';
    final dist = _onboardingState?.profile.district ?? 'Amravati';
    final st = _onboardingState?.profile.state ?? 'Maharashtra';
    return '$name • $dist, $st';
  }

  String get _farmerIdentitySubtitle {
    final acres = _onboardingState?.farm.landAcres ?? 4.2;
    final crops = _onboardingState?.crops.mainCrops.join(' & ') ?? 'Soybean & Wheat';
    final ownership = _onboardingState?.farm.ownershipType ?? 'Owned';
    return '$acres Acres • $crops • $ownership';
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

    _telemetryProvider.executeSimulatedRemediation(alert.id, alert.zoneId);
    setState(() {
      alert.isApproved = true;
      alert.status = AlertStatus.actionTaken;

      // Simulate closed-loop remediation verification (Phase 7A canonical demo)
      _latestVerification = RemediationVerificationModel(
        zoneId: alert.zoneId,
        preMoisture: 16.8,
        postMoisture: 28.2,
        moistureDelta: 11.4,
        resolved: true,
        summaryEn: 'Zone 2 East Sector simulated micro-irrigation complete: Moisture improved from 16.8% to 28.2% (+11.4%). Water stress resolved (SIMULATED ACTION).',
        summaryHi: 'ज़ोन 2 पूर्व खंड में सिमुलेटेड सूक्ष्म-सिंचाई पूर्ण: नमी 16.8% से बढ़कर 28.2% हो गई (+11.4%)। समस्या हल (सिम्युलेटेड कार्रवाई)!',
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

  // Phase 7B: PRAHAR Contextual Field Assistant Dialog
  void _openFieldAssistantDialog() {
    bool isProcessing = false;
    bool actionConfirmed = false;
    AssistantStructuredResponse? latestResponse;
    String? assistantError;
    final textController = TextEditingController();
    final assistantSessionId = 'assistant_session_${DateTime.now().millisecondsSinceEpoch}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1813),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> sendQuery(String queryText) async {
            if (queryText.trim().isEmpty || isProcessing) return;
            setModalState(() {
              isProcessing = true;
              assistantError = null;
            });

            try {
              final farmerContext = AssistantContextBuilder.buildContext(
                profile: _onboardingState?.profile,
                farm: _selectedFarm,
                zones: _zones,
                alerts: _alerts,
              );

              final res = await _assistantEngine.processQuery(
                queryText.trim(),
                language: _currentLanguage,
                context: farmerContext,
                sessionId: assistantSessionId,
              );

              setModalState(() {
                latestResponse = res;
                actionConfirmed = false;
                textController.clear();
              });
            } catch (e) {
              setModalState(() {
                assistantError = 'Assistant Error: $e';
              });
            } finally {
              setModalState(() {
                isProcessing = false;
              });
            }
          }

          Future<void> executeConfirmedAction() async {
            if (isProcessing) return;
            setModalState(() {
              isProcessing = true;
            });

            try {
              final farmerContext = AssistantContextBuilder.buildContext(
                profile: _onboardingState?.profile,
                farm: _selectedFarm,
                zones: _zones,
                alerts: _alerts,
              );

              final res = await _assistantEngine.processQuery(
                'Confirm irrigation',
                language: _currentLanguage,
                context: farmerContext,
                sessionId: assistantSessionId,
                confirmAction: true,
                pendingActionId: latestResponse?.pendingAction?.actionType,
              );

              setModalState(() {
                latestResponse = res;
                actionConfirmed = false;
              });

              _loadRemoteData();
            } catch (e) {
              setModalState(() {
                assistantError = 'Action Confirmation Error: $e';
              });
            } finally {
              setModalState(() {
                isProcessing = false;
              });
            }
          }

          return Container(
            key: const Key('assistant_modal_bottom_sheet'),
            padding: EdgeInsets.only(
              left: 18.0,
              right: 18.0,
              top: 18.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 18.0,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: PraharTheme.primaryGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: PraharTheme.borderGreen),
                        ),
                        child: const Icon(Icons.smart_toy, color: PraharTheme.primaryGreen, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.getText('assistant_title', _currentLanguage),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            ),
                            Text(
                              AppLocalizations.getText('assistant_tagline', _currentLanguage),
                              style: TextStyle(color: Colors.grey[400], fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: PraharTheme.alertAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 14, color: PraharTheme.alertAmber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            AppLocalizations.getText('assistant_simulation_banner', _currentLanguage),
                            style: const TextStyle(fontSize: 10, color: PraharTheme.alertAmber, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Chip(
                        avatar: const Icon(Icons.person, size: 12, color: PraharTheme.primaryGreen),
                        label: Text(_onboardingState?.profile.name ?? 'Ramesh Patil', style: const TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: const Color(0xFF13241D),
                        side: const BorderSide(color: PraharTheme.borderGreen),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        avatar: const Icon(Icons.landscape, size: 12, color: PraharTheme.primaryGreen),
                        label: Text('${_onboardingState?.farm.areaAcres ?? 4.2} Acres', style: const TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: const Color(0xFF13241D),
                        side: const BorderSide(color: PraharTheme.borderGreen),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        avatar: const Icon(Icons.grass, size: 12, color: PraharTheme.primaryGreen),
                        label: Text('${_zones.isNotEmpty ? _zones.length : 4} Zones', style: const TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: const Color(0xFF13241D),
                        side: const BorderSide(color: PraharTheme.borderGreen),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Chip(
                        avatar: const Icon(Icons.warning_amber_rounded, size: 12, color: PraharTheme.alertAmber),
                        label: Text('${_alerts.isNotEmpty ? _alerts.length : 3} Alerts', style: const TextStyle(fontSize: 10, color: Colors.white)),
                        backgroundColor: const Color(0xFF13241D),
                        side: const BorderSide(color: PraharTheme.alertAmber),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ActionChip(
                          key: const Key('assistant_chip_attention'),
                          label: Text(AppLocalizations.getText('assistant_chip_attention', _currentLanguage), style: const TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: const Color(0xFF1A3327),
                          side: const BorderSide(color: PraharTheme.primaryGreen),
                          onPressed: () => sendQuery('Which zone needs attention first?'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          key: const Key('assistant_chip_farm_status'),
                          label: const Text('Farm Status', style: TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: const Color(0xFF1A3327),
                          side: const BorderSide(color: PraharTheme.primaryGreen),
                          onPressed: () => sendQuery('What is the current farm status?'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          key: const Key('assistant_chip_zone2'),
                          label: const Text('Zone 2 Moisture', style: TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: const Color(0xFF1A3327),
                          side: const BorderSide(color: PraharTheme.primaryGreen),
                          onPressed: () => sendQuery('Why is Zone 2 under water stress?'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          key: const Key('assistant_chip_stress'),
                          label: Text(AppLocalizations.getText('assistant_chip_stress', _currentLanguage), style: const TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: const Color(0xFF1A3327),
                          side: const BorderSide(color: PraharTheme.primaryGreen),
                          onPressed: () => sendQuery('Why is Zone 2 under water stress?'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          key: const Key('assistant_chip_pest'),
                          label: Text(AppLocalizations.getText('assistant_chip_pest', _currentLanguage), style: const TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: const Color(0xFF1A3327),
                          side: const BorderSide(color: PraharTheme.primaryGreen),
                          onPressed: () => sendQuery('What should I do about the pest detected in South Sector?'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          key: const Key('assistant_chip_schemes'),
                          label: Text(AppLocalizations.getText('assistant_chip_schemes', _currentLanguage), style: const TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: const Color(0xFF1A3327),
                          side: const BorderSide(color: PraharTheme.alertSky),
                          onPressed: () => sendQuery('Which government schemes may be relevant to me?'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          key: const Key('assistant_chip_verification'),
                          label: Text(AppLocalizations.getText('assistant_chip_verification', _currentLanguage), style: const TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: const Color(0xFF1A3327),
                          side: const BorderSide(color: PraharTheme.borderGreen),
                          onPressed: () => sendQuery('Show me what happened after the irrigation action'),
                        ),
                        const SizedBox(width: 6),
                        ActionChip(
                          key: const Key('assistant_chip_profile'),
                          label: Text(AppLocalizations.getText('assistant_chip_profile', _currentLanguage), style: const TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: const Color(0xFF1A3327),
                          side: const BorderSide(color: PraharTheme.borderGreen),
                          onPressed: () => sendQuery('Show my farm profile and acres'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('assistant_input_field'),
                          controller: textController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.getText('assistant_query_hint', _currentLanguage),
                            hintStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                            filled: true,
                            fillColor: const Color(0xFF09140F),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: PraharTheme.borderGreen),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: PraharTheme.borderGreen),
                            ),
                          ),
                          onSubmitted: sendQuery,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const Key('assistant_send_button'),
                        icon: isProcessing
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: PraharTheme.primaryGreen))
                            : const Icon(Icons.send, color: PraharTheme.primaryGreen),
                        onPressed: isProcessing ? null : () => sendQuery(textController.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (assistantError != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertRose.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(assistantError!, style: const TextStyle(color: PraharTheme.alertRose, fontSize: 11)),
                    ),
                  if (latestResponse != null) ...[
                    Container(
                      key: const Key('assistant_response_card'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF09140F),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PraharTheme.borderGreen),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                key: const Key('assistant_intent_chip'),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: PraharTheme.primaryGreen.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  latestResponse!.intent.toWireString(),
                                  style: const TextStyle(color: PraharTheme.primaryGreen, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (latestResponse!.referencedZone != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  key: const Key('assistant_zone_chip'),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    latestResponse!.referencedZone!,
                                    style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Container(
                                key: const Key('assistant_severity_chip'),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: latestResponse!.severity == 'HIGH'
                                      ? PraharTheme.alertRose.withValues(alpha: 0.2)
                                      : (latestResponse!.severity == 'MEDIUM'
                                          ? PraharTheme.alertAmber.withValues(alpha: 0.2)
                                          : PraharTheme.primaryGreen.withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  latestResponse!.severity,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: latestResponse!.severity == 'HIGH'
                                        ? PraharTheme.alertRose
                                        : (latestResponse!.severity == 'MEDIUM' ? PraharTheme.alertAmber : PraharTheme.primaryGreen),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            latestResponse!.answer,
                            key: const Key('assistant_answer_text'),
                            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                          ),
                          if (latestResponse!.evidence != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              key: const Key('assistant_evidence_box'),
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF132018),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Evidence: ${latestResponse!.evidence!}',
                                style: TextStyle(color: Colors.grey[300], fontSize: 11),
                              ),
                            ),
                          ],
                          if (latestResponse!.recommendation != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              key: const Key('assistant_recommendation_box'),
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF162B21),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Recommendation: ${latestResponse!.recommendation!}',
                                style: const TextStyle(color: PraharTheme.primaryGreen, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          if (latestResponse!.indicativeDisclaimer != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              latestResponse!.indicativeDisclaimer!,
                              key: const Key('assistant_disclaimer_text'),
                              style: TextStyle(color: Colors.grey[500], fontSize: 10, fontStyle: FontStyle.italic),
                            ),
                          ],
                          if (latestResponse!.safetyLevel == AssistantSafetyLevel.prohibitedAutonomous) ...[
                            const SizedBox(height: 12),
                            Container(
                              key: const Key('assistant_prohibited_box'),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: PraharTheme.alertRose.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: PraharTheme.alertRose.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.block, color: PraharTheme.alertRose, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'ACTION PROHIBITED BY SAFETY PROTOCOL',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PraharTheme.alertRose),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (latestResponse!.requiresConfirmation) ...[
                            const SizedBox(height: 12),
                            Container(
                              key: const Key('assistant_safety_gate_box'),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: PraharTheme.alertAmber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.shield_outlined, color: PraharTheme.alertAmber, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'CONFIRMATION REQUIRED (Simulation Only)',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PraharTheme.alertAmber),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Checkbox(
                                        key: const Key('assistant_confirm_checkbox'),
                                        value: actionConfirmed,
                                        activeColor: PraharTheme.primaryGreen,
                                        onChanged: (v) {
                                          setModalState(() {
                                            actionConfirmed = v ?? false;
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          AppLocalizations.getText('assistant_confirm_action', _currentLanguage),
                                          style: const TextStyle(fontSize: 12, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      key: const Key('assistant_confirm_button'),
                                      icon: const Icon(Icons.play_arrow, size: 16),
                                      label: const Text('Dispatch Simulation Action', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: actionConfirmed ? PraharTheme.primaryGreen : Colors.grey,
                                        foregroundColor: Colors.black,
                                      ),
                                      onPressed: actionConfirmed && !isProcessing ? executeConfirmedAction : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
          landAcres: _onboardingState?.farm.landAcres ?? (_selectedFarm != null ? _selectedFarm!.totalHectares * 2.47105 : null),
          cropType: _onboardingState?.crops.mainCrops.isNotEmpty == true ? _onboardingState!.crops.mainCrops.first : null,
          stateName: _onboardingState?.profile.state ?? 'Maharashtra',
          irrigationStatus: _onboardingState?.farm.irrigationStatus,
          ownershipType: _onboardingState?.farm.ownershipType,
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
          // Phase 7A: 4-Language Selector Menu (en, hi, mr, pa)
          PopupMenuButton<String>(
            key: const Key('language_selector_menu_button'),
            icon: const Icon(Icons.translate, color: PraharTheme.primaryGreen, size: 18),
            tooltip: _isHindi ? 'भाषा चुनें' : 'Select Language',
            color: const Color(0xFF131F19),
            onSelected: (String langCode) async {
              setState(() {
                _currentLanguage = langCode;
                _isHindi = langCode == 'hi';
              });
              await _offlineStorage.setLanguagePreference(langCode);
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'en',
                child: Text('English', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const PopupMenuItem<String>(
                value: 'hi',
                child: Text('हिन्दी', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const PopupMenuItem<String>(
                value: 'mr',
                child: Text('मराठी', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
              const PopupMenuItem<String>(
                value: 'pa',
                child: Text('ਪੰਜਾਬੀ', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ],
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
          // Phase 7A Demo Data & Backend Status Banner
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            _offlineStorage.isOnline ? Icons.cloud_done : Icons.cloud_off,
                            color: _offlineStorage.isOnline ? PraharTheme.primaryGreen : PraharTheme.alertAmber,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _offlineStorage.isOnline
                                        ? (_isHindi ? 'क्लाउड सिंक सक्रिय (ऑनलाइन)' : 'Backend Sync: Online (Physical Rover Disconnected)')
                                        : (_isHindi ? 'ऑफ़लाइन मोड (स्थानीय कैश)' : 'Offline Mode (Local Cache)'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: _offlineStorage.isOnline ? PraharTheme.primaryGreen : PraharTheme.alertAmber,
                                    ),
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
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Offline toggle for field testing
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
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
                        if (_offlineStorage.pendingCount > 0 && _offlineStorage.isOnline) ...[
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: _syncNow,
                            style: TextButton.styleFrom(
                              backgroundColor: PraharTheme.primaryGreen,
                              foregroundColor: Colors.black,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            child: Text(
                              _isHindi ? 'सिंक करें' : 'Sync Now',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1, color: PraharTheme.borderGreen),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      key: const Key('demo_data_source_badge'),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertAmber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        _isHindi ? 'डेटा स्रोत: डेमो रोवर टेलीमेट्री' : 'Data: DEMO ROVER TELEMETRY',
                        style: const TextStyle(fontSize: 10, color: PraharTheme.alertAmber, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isHindi ? 'भौतिक रोवर: डिस्कनेक्टेड' : 'Physical Rover: Disconnected',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        overflow: TextOverflow.ellipsis,
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
          else if (_selectedFarm != null) ...[
            // Phase 7A: Farmer & Farm Profile Identity Card
            Container(
              key: const Key('farmer_identity_card'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1E17),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PraharTheme.primaryGreen.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: PraharTheme.primaryGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: PraharTheme.primaryGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _farmerIdentityTitle,
                                key: const Key('farmer_identity_title'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: PraharTheme.alertAmber.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.5)),
                              ),
                              child: const Text(
                                'DEMO FARM',
                                style: TextStyle(fontSize: 9, color: PraharTheme.alertAmber, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _farmerIdentitySubtitle,
                          key: const Key('farmer_identity_subtitle'),
                          style: TextStyle(color: Colors.grey[300], fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('onboarding_edit_button'),
                    icon: const Icon(Icons.edit, size: 16, color: PraharTheme.primaryGreen),
                    tooltip: _isHindi ? 'प्रोफ़ाइल एवं खेत संपादित करें' : 'Edit Profile & Farm',
                    onPressed: _openOnboardingEdit,
                  ),
                ],
              ),
            ),
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
                    const SizedBox(height: 12),
                    Container(
                      key: const Key('simulated_rover_telemetry_card'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF09140F),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PraharTheme.borderGreen),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.smart_toy_outlined, color: PraharTheme.primaryGreen, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isHindi ? 'सिम्युलेटेड रोवर टेलीमेट्री' : 'SIMULATED ROVER TELEMETRY',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: PraharTheme.primaryGreen),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: PraharTheme.alertAmber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  _isHindi ? 'हार्डवेयर अलग है' : 'Benchmark',
                                  style: const TextStyle(fontSize: 9, color: PraharTheme.alertAmber, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Rover: ${_rover.roverId} • State: ${_rover.state} • GPS: 20.9320° N, 77.7523° E (Amravati)',
                            style: TextStyle(color: Colors.grey[300], fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isHindi
                                ? 'फ़ील्ड कवरेज: 100% (4/4 ज़ोन स्कैन किए गए • डेमोंस्ट्रेशन मोड)'
                                : 'Field Coverage: 100% (4/4 Zones Scanned • Demo Mode)',
                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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

          // Phase 7B: PRAHAR Contextual Field Assistant Entry Card
          Card(
            color: const Color(0xFF0C1D16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: PraharTheme.primaryGreen, width: 1.5),
            ),
            child: InkWell(
              key: const Key('open_field_assistant_button'),
              borderRadius: BorderRadius.circular(10),
              onTap: _openFieldAssistantDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PraharTheme.primaryGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.smart_toy, color: PraharTheme.primaryGreen, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                AppLocalizations.getText('assistant_title', _currentLanguage),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: PraharTheme.alertAmber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'DEMO AI',
                                  style: TextStyle(fontSize: 8, color: PraharTheme.alertAmber, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.getText('assistant_query_hint', _currentLanguage),
                            style: TextStyle(color: Colors.grey[400], fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: PraharTheme.primaryGreen),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

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
                                    ? 'पहचान: डेमो एआई परिदृश्य (YOLOv8-संगत • 89% विश्वास)'
                                    : 'Detection: Demo AI Scenario (YOLOv8-compatible • 89% Confidence)',
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
                                    ? (_isHindi ? 'प्रेक्षित नमी: 16.8% | सुरक्षा सीमा: < 20.0%' : 'Observed Moisture: 16.8% | Safety Threshold: < 20.0%')
                                    : (_isHindi ? 'प्रेक्षित आर्द्रता: 74.0% | कीट अनुकूल सीमा: > 70.0%' : 'Observed RH: 74.0% | Pest Favorable: > 70.0%'),
                                style: TextStyle(fontSize: 11, color: Colors.grey[300]),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Safety Gate Approval Action
                      if (alert.type == HazardType.waterStress) ...[
                        if (!alert.isApproved) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: PraharTheme.alertAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sim_card_alert_outlined, size: 12, color: PraharTheme.alertAmber),
                                const SizedBox(width: 4),
                                Text(
                                  _isHindi ? 'सिम्युलेटेड कार्रवाई • कोई भौतिक कमांड नहीं' : 'SIMULATED ACTION • No physical actuator command',
                                  style: const TextStyle(fontSize: 10, color: PraharTheme.alertAmber, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
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
                          ),
                        ]
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
