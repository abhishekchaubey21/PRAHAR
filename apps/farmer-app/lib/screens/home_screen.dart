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
import '../data/repositories/field_assistant_repository.dart';
import '../data/assistant/assistant_context_builder.dart';
import '../data/assistant/field_assistant_engine.dart';
import '../core/localization/app_localizations.dart';
import '../data/providers/demo_scenarios_provider.dart';
import '../data/providers/demo_farm_dataset.dart';
import 'judge_mode_sheet.dart';
import 'prahar_chat_screen.dart';
import '../core/voice_service.dart';

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
  final DemoScenariosProvider? demoScenariosProvider;
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
    this.demoScenariosProvider,
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
  late final DemoScenariosProvider _scenariosProvider;
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
    _scenariosProvider = widget.demoScenariosProvider ??
        DemoScenariosProvider(client: _apiClient.httpClient);
    _scenariosProvider.fetchScenarios();

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

  bool get _isCanonicalDemo {
    final name = _onboardingState?.profile.name.trim();
    return name == null || name.isEmpty || name == 'Ramesh Patil';
  }

  String get _farmerIdentityTitle {
    if (_authService.currentUser?.fullName.isNotEmpty == true &&
        _authService.currentUser!.fullName != 'Ramesh Patil') {
      final name = _authService.currentUser!.fullName;
      final dist = _onboardingState?.profile.district.isNotEmpty == true
          ? _onboardingState!.profile.district
          : 'Local District';
      final st = _onboardingState?.profile.state.isNotEmpty == true
          ? _onboardingState!.profile.state
          : 'India';
      return '$name • $dist, $st';
    }
    final name = _onboardingState?.profile.name.isNotEmpty == true
        ? _onboardingState!.profile.name
        : 'Ramesh Patil';
    final dist = _onboardingState?.profile.district.isNotEmpty == true
        ? _onboardingState!.profile.district
        : 'Amravati';
    final st = _onboardingState?.profile.state.isNotEmpty == true
        ? _onboardingState!.profile.state
        : 'Maharashtra';
    return _isCanonicalDemo ? 'DEMO • $name • $dist, $st' : '$name • $dist, $st';
  }

  String get _farmerIdentitySubtitle {
    final acres = _onboardingState?.farm.landAcres ?? 4.2;
    final crops = _onboardingState?.crops.mainCrops.isNotEmpty == true
        ? _onboardingState!.crops.mainCrops.join(' & ')
        : 'Soybean & Wheat';
    final ownership = _onboardingState?.farm.ownershipType.isNotEmpty == true
        ? _onboardingState!.farm.ownershipType
        : 'Owned';
    final farmLabel = _isCanonicalDemo ? 'Demo Farm' : 'My Farm';
    return '$farmLabel • $acres Acres • $crops • $ownership';
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
      _currentLanguage = nextLang;
    });
    await _offlineStorage.setLanguagePreference(nextLang);
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isHindi ? 'लॉग आउट पुष्टि' : 'Confirm Logout'),
        content: Text(
          _isHindi
              ? 'क्या आप सुनिश्चित हैं कि आप लॉग आउट करना चाहते हैं? स्थानीय डेटा साफ़ हो जाएगा।'
              : 'Are you sure you want to log out? Local cached user data will be cleared.',
          style: const TextStyle(color: PraharTheme.textBody),
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

  // Voice Assistant Dialog (with native TTS + backend AI)
  void _openVoiceDialog() {
    bool voiceConfirmed = false;
    bool isProcessing = false;
    bool isSpeaking = false;
    bool isListeningNative = false;
    String responseText = _isHindi
        ? 'नीचे टाइप करें या माइक बटन दबाएं'
        : 'Type your question below or tap the mic';
    VoiceResponseModel? latestVoiceResponse;
    String? voiceError;
    final textController = TextEditingController();
    final voiceSessionId = 'voice_session_${DateTime.now().millisecondsSinceEpoch}';

    // Initialize native voice on first open
    voiceService.init();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PraharTheme.cardBg,
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
                language: _currentLanguage,
                sessionId: voiceSessionId,
              );

              setModalState(() {
                latestVoiceResponse = res;
                responseText = _currentLanguage == 'hi'
                    ? res.spokenTextHi
                    : res.spokenTextEn;
                voiceConfirmed = false;
                textController.clear();
              });

              // Speak the response via native TTS
              final spokenText = _currentLanguage == 'hi'
                  ? res.spokenTextHi
                  : res.spokenTextEn;
              if (voiceService.ttsAvailable) {
                setModalState(() => isSpeaking = true);
                await voiceService.speak(spokenText, lang: _currentLanguage);
                if (context.mounted) setModalState(() => isSpeaking = false);
              }
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

          Future<void> startNativeListening() async {
            if (!voiceService.sttAvailable || isProcessing || isListeningNative) return;
            setModalState(() => isListeningNative = true);
            final transcript = await voiceService.startListening(lang: _currentLanguage);
            if (context.mounted) {
              setModalState(() => isListeningNative = false);
              if (transcript != null && transcript.isNotEmpty) {
                textController.text = transcript;
                await sendQuery(transcript);
              }
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
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: PraharTheme.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: PraharTheme.primaryGreenLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.mic, color: PraharTheme.primaryGreen, size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isHindi ? 'प्रहार आवाज़ सहायक' : 'PRAHAR Voice Assistant',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: PraharTheme.textHeading),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    voiceService.ttsAvailable
                                        ? (_isHindi ? 'टीटीएस सक्रिय — उत्तर सुनाई देगा' : 'TTS active — answers spoken aloud')
                                        : (_isHindi ? 'टीटीएस अनुपलब्ध — टेक्स्ट उत्तर' : 'TTS unavailable — text answers'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: voiceService.ttsAvailable ? PraharTheme.primaryGreen : PraharTheme.textMuted,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: PraharTheme.alertAmberLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: PraharTheme.alertAmber),
                            ),
                            child: const Text(
                              'SIMULATION / DEMO INTENT',
                              style: TextStyle(fontSize: 9, color: PraharTheme.alertAmber, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: PraharTheme.textMuted),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isHindi
                        ? 'स्पष्ट सूचना: माइक्रोफ़ोन/एसटीटी हार्डवेयर अनुपलब्ध — सिम्युलेटेड वॉयस इनपुट सक्रिय। आवाज़ सीधे मोटर नहीं चला सकती।'
                        : 'Honest STT Notice: Real microphone hardware not connected — Simulated Voice Input active. Voice commands CANNOT directly drive motors.',
                    style: const TextStyle(color: PraharTheme.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                  // Response area
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isProcessing || isSpeaking
                          ? PraharTheme.primaryGreenLight
                          : (voiceError != null ? PraharTheme.alertRoseLight : PraharTheme.cardBgGreen),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: voiceError != null ? PraharTheme.alertRose : PraharTheme.borderGreen,
                      ),
                    ),
                    child: isProcessing
                        ? Row(
                            children: [
                              const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: PraharTheme.primaryGreen)),
                              const SizedBox(width: 10),
                              Text(_isHindi ? 'सोच रहा हूं...' : 'Thinking...', style: const TextStyle(color: PraharTheme.primaryGreen, fontWeight: FontWeight.w600)),
                            ],
                          )
                        : isSpeaking
                          ? Row(
                              children: [
                                const Icon(Icons.volume_up, color: PraharTheme.primaryGreen, size: 18),
                                const SizedBox(width: 8),
                                Text(_isHindi ? 'बोल रहा हूं...' : 'Speaking...', style: const TextStyle(color: PraharTheme.primaryGreen, fontWeight: FontWeight.w600)),
                              ],
                            )
                          : Text(
                              responseText,
                              style: TextStyle(
                                fontSize: 14,
                                color: voiceError != null ? PraharTheme.alertRose : PraharTheme.textBody,
                                height: 1.4,
                              ),
                            ),
                  ),
                  if (isSpeaking) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.stop_circle_outlined, size: 16),
                        label: Text(_isHindi ? 'बोलना रोकें' : 'Stop Speaking'),
                        onPressed: () async {
                          await voiceService.stopSpeaking();
                          setModalState(() => isSpeaking = false);
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Input row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('voice_input_field'),
                          controller: textController,
                          style: const TextStyle(color: PraharTheme.textBody),
                          decoration: InputDecoration(
                            hintText: _isHindi ? 'सवाल लिखें...' : 'Type your question...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onSubmitted: (val) => sendQuery(val),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Native mic button
                      if (voiceService.sttAvailable)
                        IconButton(
                          key: const Key('voice_native_mic_button'),
                          tooltip: _isHindi ? 'बोलकर पूछें' : 'Speak your question',
                          icon: Icon(
                            isListeningNative ? Icons.mic_off : Icons.mic,
                            color: isListeningNative ? PraharTheme.alertRose : PraharTheme.primaryGreen,
                          ),
                          onPressed: isProcessing ? null : startNativeListening,
                        ),
                      IconButton(
                        key: const Key('voice_send_button'),
                        icon: const Icon(Icons.send, color: PraharTheme.primaryGreen),
                        onPressed: isProcessing ? null : () => sendQuery(textController.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Quick intent chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.info_outline, size: 16, color: PraharTheme.primaryGreen),
                        label: Text(_isHindi ? 'खेत का हाल बताओ' : 'What is farm status?', style: const TextStyle(color: PraharTheme.darkGreen)),
                        onPressed: isProcessing ? null : () => sendQuery(_isHindi ? 'खेत का हाल बताओ' : 'What is farm status?'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.water_drop, size: 16, color: PraharTheme.alertSky),
                        label: Text(_isHindi ? 'ज़ोन 2 में सिंचाई' : 'Zone 2 irrigation', style: const TextStyle(color: PraharTheme.darkGreen)),
                        onPressed: isProcessing ? null : () => sendQuery(_isHindi ? 'ज़ोन 2 में सिंचाई चालू करो' : 'Start irrigation in Zone 2'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.help_outline, size: 16, color: PraharTheme.textMuted),
                        label: Text(_isHindi ? 'अज्ञात आदेश' : 'Unknown command', style: const TextStyle(color: PraharTheme.darkGreen)),
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
                        color: PraharTheme.alertAmberLight,
                        borderRadius: BorderRadius.circular(10),
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
                              backgroundColor: voiceConfirmed ? PraharTheme.primaryGreen : Colors.grey[300],
                              foregroundColor: voiceConfirmed ? Colors.white : Colors.grey,
                              minimumSize: const Size(double.infinity, 40),
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

  // Phase 8: 12-Step Judge Mode Flow Sheet
  void _openJudgeModeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => JudgeModeSheet(
        scenariosProvider: _scenariosProvider,
        assistantEngine: _assistantEngine,
        farmerContext: AssistantContextBuilder.buildContext(
          profile: _onboardingState?.profile,
          farm: _selectedFarm,
          zones: _zones,
          alerts: _alerts,
        ),
        currentLanguage: _currentLanguage,
        onFieldReset: () async {
          await _loadRemoteData();
        },
      ),
    );
  }

  // Phase 7B/8/V2: Dedicated Full Chat Screen PRAHAR Assistant
  void _openFieldAssistantDialog() {
    final farmerContext = AssistantContextBuilder.buildContext(
      profile: _onboardingState?.profile,
      farm: _selectedFarm,
      zones: _zones.isNotEmpty ? _zones : CanonicalDemoFarmDataset.zones,
      alerts: _alerts.isNotEmpty ? _alerts : CanonicalDemoFarmDataset.alerts,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PraharChatScreen(
          apiClient: _apiClient,
          fieldAssistantRepository: widget.fieldAssistantRepository,
          initialLanguage: _currentLanguage,
          initialContext: farmerContext,
          activeZoneId: _zones.firstOrNull?.id ?? 'DEMO-ZONE-02',
        ),
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
        backgroundColor: PraharTheme.cardBg,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: PraharTheme.borderLight),
        ),
        titleSpacing: 8,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.agriculture, color: PraharTheme.primaryGreen, size: 22),
              const SizedBox(width: 6),
              const Text('PRAHAR', style: TextStyle(color: PraharTheme.textHeading, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: PraharTheme.primaryGreenLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: PraharTheme.borderGreen),
                ),
                child: Text(_isHindi ? 'किसान' : 'Farmer App', style: const TextStyle(fontSize: 10, color: PraharTheme.darkGreen, fontWeight: FontWeight.bold)),
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
            icon: const Icon(Icons.analytics_outlined, color: PraharTheme.textHeading, size: 20),
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
            icon: const Icon(Icons.account_balance_outlined, color: PraharTheme.textHeading, size: 20),
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
                icon: const Icon(Icons.notifications_outlined, color: PraharTheme.textHeading, size: 20),
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
                child: Text('English', style: TextStyle(color: PraharTheme.textBody, fontSize: 13)),
              ),
              const PopupMenuItem<String>(
                value: 'hi',
                child: Text('हिन्दी', style: TextStyle(color: PraharTheme.textBody, fontSize: 13)),
              ),
              const PopupMenuItem<String>(
                value: 'mr',
                child: Text('मराठी', style: TextStyle(color: PraharTheme.textBody, fontSize: 13)),
              ),
              const PopupMenuItem<String>(
                value: 'pa',
                child: Text('ਪੰਜਾਬੀ', style: TextStyle(color: PraharTheme.textBody, fontSize: 13)),
              ),
            ],
          ),
          IconButton(
            key: const Key('logout_button'),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.logout, color: PraharTheme.textMuted, size: 18),
            tooltip: _isHindi ? 'लॉग आउट' : 'Log Out',
            onPressed: _handleLogout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Farmer-first status banner (light)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: _offlineStorage.isOnline ? PraharTheme.primaryGreenLight : PraharTheme.alertAmberLight,
              border: Border.all(
                color: _offlineStorage.isOnline ? PraharTheme.borderGreen : PraharTheme.alertAmber,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _offlineStorage.isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: _offlineStorage.isOnline ? PraharTheme.primaryGreen : PraharTheme.alertAmber,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _offlineStorage.isOnline
                            ? (_isHindi ? 'आपका खेत जुड़ा हुआ है' : 'Farm Connected — Live Data')
                            : (_isHindi ? 'ऑफ़लाइन मोड' : 'Offline Mode — Cached Data'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _offlineStorage.isOnline ? PraharTheme.darkGreen : PraharTheme.alertAmber,
                        ),
                      ),
                      Text(
                        _isHindi
                            ? '${_offlineStorage.pendingCount} लंबित कार्य  •  डेमो टेलीमेट्री'
                            : '${_offlineStorage.pendingCount} buffered  •  Demo Rover Telemetry',
                        style: const TextStyle(color: PraharTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                // Offline toggle for field testing
                IconButton(
                  key: const Key('wifi_toggle_button'),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _offlineStorage.isOnline ? Icons.wifi : Icons.wifi_off,
                    size: 20,
                    color: PraharTheme.textMuted,
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
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: Text(
                      _isHindi ? 'सिंक' : 'Sync',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
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
                color: PraharTheme.alertRoseLight,
                border: Border.all(color: PraharTheme.alertRose),
                borderRadius: BorderRadius.circular(10),
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
                color: PraharTheme.alertAmberLight,
                border: Border.all(color: PraharTheme.alertAmber),
                borderRadius: BorderRadius.circular(10),
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
            // Farmer & Farm Profile Identity Card (light)
            Container(
              key: const Key('farmer_identity_card'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: PraharTheme.cardBgGreen,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PraharTheme.borderGreen),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: PraharTheme.primaryGreenLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: PraharTheme.primaryGreen, size: 22),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: PraharTheme.textHeading),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _isCanonicalDemo ? PraharTheme.alertAmberLight : PraharTheme.primaryGreenLight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _isCanonicalDemo ? PraharTheme.alertAmber.withValues(alpha: 0.5) : PraharTheme.borderGreen),
                              ),
                              child: Text(
                                _isCanonicalDemo ? 'DEMO MODE' : 'VERIFIED FARMER',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: _isCanonicalDemo ? PraharTheme.alertAmber : PraharTheme.darkGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _farmerIdentitySubtitle,
                          key: const Key('farmer_identity_subtitle'),
                          style: const TextStyle(color: PraharTheme.textMuted, fontSize: 11),
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
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: PraharTheme.textHeading),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_farms.length > 1)
                          DropdownButton<String>(
                            key: const Key('farm_selector_dropdown'),
                            value: _selectedFarm!.id,
                            dropdownColor: PraharTheme.cardBg,
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
                      '${_selectedFarm!.location} • ${_selectedFarm!.totalHectares.toStringAsFixed(1)} ha • ${_zones.length} ${_isHindi ? "निगरानी वाले ज़ोन" : "Monitored Zones"}',
                      style: const TextStyle(color: PraharTheme.textMuted, fontSize: 12),
                    ),
                    const Divider(height: 16, color: PraharTheme.borderLight),
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
                            style: const TextStyle(color: PraharTheme.textMuted, fontSize: 11),
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
                        color: PraharTheme.primaryGreenLight,
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
                                  color: PraharTheme.alertAmberLight,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.5)),
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
                            style: const TextStyle(color: PraharTheme.textBody, fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isHindi
                                ? 'फ़ील्ड कवरेज: 100% (4/4 ज़ोन स्कैन किए गए • डेमोंस्ट्रेशन मोड)'
                                : 'Field Coverage: 100% (4/4 Zones Scanned • Demo Mode)',
                            style: const TextStyle(color: PraharTheme.textMuted, fontSize: 10),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PraharTheme.textHeading),
          ),
          const SizedBox(height: 8),
          if (_zones.isEmpty)
            Container(
              key: const Key('empty_zones_container'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: PraharTheme.primaryGreenLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PraharTheme.borderGreen),
              ),
              child: Text(
                _isHindi ? 'इस खेत के लिए कोई ज़ोन कॉन्फ़िगर नहीं किया गया है।' : 'No zones configured for this farm.',
                style: const TextStyle(color: PraharTheme.textMuted, fontSize: 12),
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
                    style: const TextStyle(fontSize: 12, color: PraharTheme.darkGreen),
                  ),
                );
              }).toList(),
            ),
          // Demo Scenario Selector Card (light theme)
          AnimatedBuilder(
            animation: _scenariosProvider,
            builder: (context, _) {
              return Card(
                key: const Key('demo_scenario_selector_card'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.science_outlined, size: 16, color: PraharTheme.primaryGreen),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    AppLocalizations.getText('demo_scenarios_title', _currentLanguage),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: PraharTheme.textHeading),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            key: const Key('reset_scenario_button'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            ),
                            icon: const Icon(Icons.refresh, size: 14, color: PraharTheme.alertAmber),
                            label: Text(
                              AppLocalizations.getText('reset_scenario', _currentLanguage),
                              style: const TextStyle(fontSize: 11, color: PraharTheme.alertAmber, fontWeight: FontWeight.bold),
                            ),
                            onPressed: _scenariosProvider.isLoading
                                ? null
                                : () async {
                                    await _scenariosProvider.resetFieldState();
                                    if (mounted) {
                                      await _loadRemoteData();
                                    }
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _scenariosProvider.scenarios.map((sc) {
                            final isSelected = sc.id == _scenariosProvider.activeScenarioId;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                key: Key('scenario_chip_${sc.id}'),
                                label: Text(
                                  sc.name,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.white : PraharTheme.darkGreen,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: PraharTheme.primaryGreen,
                                onSelected: (sel) async {
                                  if (sel) {
                                    await _scenariosProvider.selectScenario(sc.id);
                                    if (mounted) {
                                      await _loadRemoteData();
                                    }
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Judge Mode Entry Card (light)
          Card(
            key: const Key('judge_mode_entry_card'),
            color: PraharTheme.alertSkyLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: PraharTheme.alertSky, width: 1.2),
            ),
            child: InkWell(
              key: const Key('open_judge_mode_button'),
              borderRadius: BorderRadius.circular(12),
              onTap: _openJudgeModeSheet,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertSky.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.gavel_rounded, color: PraharTheme.alertSky, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                AppLocalizations.getText('judge_mode_title', _currentLanguage),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: PraharTheme.alertSky),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: PraharTheme.alertSky.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  AppLocalizations.getText('judge_mode_badge', _currentLanguage),
                                  style: const TextStyle(fontSize: 8, color: PraharTheme.alertSky, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppLocalizations.getText('judge_mode_subtitle', _currentLanguage),
                            style: const TextStyle(color: PraharTheme.textMuted, fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 14, color: PraharTheme.alertSky),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Action Hub (Voice Assistant, Evidence Report, Opportunities)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.mic, size: 16, color: PraharTheme.primaryGreen),
                  label: Text(
                    _isHindi ? 'आवाज़ सहायक' : 'Voice (Demo)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PraharTheme.darkGreen),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: PraharTheme.cardBgGreen,
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
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PraharTheme.darkGreen),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: PraharTheme.cardBgGreen,
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
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PraharTheme.darkGreen),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: PraharTheme.cardBgGreen,
                    side: const BorderSide(color: PraharTheme.alertSky),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: _openOpportunityCenterDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── ASK PRAHAR — Prominent Farmer-First CTA ───────────────────────────
          GestureDetector(
            onTap: _openFieldAssistantDialog,
            child: Container(
              key: const Key('open_field_assistant_button'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [PraharTheme.primaryGreen, PraharTheme.mediumGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: PraharTheme.primaryGreen.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.smart_toy, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isHindi ? 'PRAHAR से पूछें' : 'Ask PRAHAR',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isHindi
                              ? 'खेत के बारे में कोई भी सवाल पूछें'
                              : (_currentLanguage == 'mr'
                                  ? 'शेताबद्दल कोणताही प्रश्न विचारा'
                                  : (_currentLanguage == 'pa'
                                      ? 'ਖੇਤ ਬਾਰੇ ਕੋਈ ਵੀ ਸਵਾਲ ਪੁੱਛੋ'
                                      : 'Ask anything about your farm')),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          const SizedBox(height: 16),

          // Closed-Loop Verification Result Card (if verified)
          if (_latestVerification != null) ...[
            Card(
              color: PraharTheme.primaryGreenLight,
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
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: PraharTheme.darkGreen, fontSize: 13),
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
                          label: Text(_isHindi ? 'सत्यापित' : 'RESOLVED', style: const TextStyle(fontSize: 10, color: Colors.white)),
                          backgroundColor: PraharTheme.primaryGreen,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _isHindi ? _latestVerification!.summaryHi : _latestVerification!.summaryEn,
                      style: const TextStyle(fontSize: 13, color: PraharTheme.textBody),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${_isHindi ? "पहले" : "Pre"}: ${_latestVerification!.preMoisture}%  →  ${_isHindi ? "बाद में" : "Post"}: ${_latestVerification!.postMoisture}%',
                          style: const TextStyle(color: PraharTheme.textBody, fontWeight: FontWeight.w600, fontSize: 13),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PraharTheme.textHeading),
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
                            style: const TextStyle(color: PraharTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isHindi ? alert.messageHi : alert.message,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: PraharTheme.textBody),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: PraharTheme.alertAmberLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb, size: 16, color: PraharTheme.alertAmber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isHindi ? alert.recommendedActionHi : alert.recommendedAction,
                                style: const TextStyle(color: PraharTheme.textBody, fontSize: 12),
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
                          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
                          decoration: BoxDecoration(
                            color: PraharTheme.primaryGreenLight,
                            borderRadius: BorderRadius.circular(8),
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
                                    _isHindi ? 'कारण और साक्ष्य देखें' : 'Inspect "WHY" Reasoning',
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
                            color: PraharTheme.primaryGreenLight,
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
                                style: const TextStyle(fontSize: 11, color: PraharTheme.textBody),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: PraharTheme.alertAmberLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.5)),
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
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _approveAndIrrigate(alert),
                            ),
                          ),
                        ]
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: PraharTheme.primaryGreenLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: PraharTheme.borderGreen),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, size: 16, color: PraharTheme.primaryGreen),
                                const SizedBox(width: 6),
                                Text(
                                  _isHindi ? 'स्वीकृत - रोवर द्वारा उपचार पूरा' : 'Approved — Remediated by Rover',
                                  style: const TextStyle(fontSize: 12, color: PraharTheme.darkGreen, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              )),

          // ── SIH 2026 Identity Footer ─────────────────────────────────────────
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: PraharTheme.cardBgGreen,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PraharTheme.borderGreen),
            ),
            child: Column(
              children: const [
                Text(
                  'PRAHAR — प्रहार',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: PraharTheme.textHeading,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Smart Rover-Based Precision Agriculture Platform',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: PraharTheme.textMuted),
                ),
                SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text('SIH 2026 • Team KYROS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PraharTheme.darkGreen)),
                      padding: EdgeInsets.zero,
                    ),
                    Chip(
                      label: Text('Vivekananda Institute of Professional Studies', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PraharTheme.darkGreen)),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
        Text(label, style: const TextStyle(color: PraharTheme.textMuted, fontSize: 11)),
      ],
    );
  }
}
