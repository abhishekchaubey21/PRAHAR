import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme.dart';
import '../../core/voice_service.dart';
import '../../domain/assistant_model.dart';
import '../data/assistant/assistant_context_builder.dart';
import '../data/assistant/field_assistant_engine.dart';
import '../data/providers/demo_farm_dataset.dart';
import '../data/repositories/field_assistant_repository.dart';

class PraharChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final bool isVoice;
  final String? voiceDurationText;
  final AssistantStructuredResponse? structuredResponse;

  const PraharChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.isVoice = false,
    this.voiceDurationText,
    this.structuredResponse,
  });
}

class PraharChatScreen extends StatefulWidget {
  final ApiClient? apiClient;
  final FieldAssistantRepository? fieldAssistantRepository;
  final String initialLanguage;
  final FarmerAssistantContext? initialContext;
  final String? activeZoneId;
  final bool autoStartVoice;

  const PraharChatScreen({
    super.key,
    this.apiClient,
    this.fieldAssistantRepository,
    this.initialLanguage = 'en',
    this.initialContext,
    this.activeZoneId,
    this.autoStartVoice = false,
  });

  @override
  State<PraharChatScreen> createState() => _PraharChatScreenState();
}

class _PraharChatScreenState extends State<PraharChatScreen> with SingleTickerProviderStateMixin {
  late final FieldAssistantEngine _assistantEngine;
  late final String _sessionId;
  late String _currentLanguage;
  late FarmerAssistantContext _farmContext;

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  final List<PraharChatMessage> _messages = [];
  bool _isProcessing = false;
  bool _isListening = false;
  String? _currentlyPlayingMessageId;
  String? _errorMessage;
  String? _activeZoneId;
  final Map<String, bool> _actionConfirmedMap = {};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.initialLanguage;
    _sessionId = 'prahar_session_${DateTime.now().millisecondsSinceEpoch}';
    _activeZoneId = widget.activeZoneId ?? 'DEMO-ZONE-02';

    final repo = widget.fieldAssistantRepository ??
        (widget.apiClient != null ? FieldAssistantRepository(apiClient: widget.apiClient!) : null);
    _assistantEngine = FieldAssistantEngine(repository: repo);

    _farmContext = widget.initialContext ??
        AssistantContextBuilder.buildContext(
          profile: CanonicalDemoFarmDataset.profile,
          farm: CanonicalDemoFarmDataset.farmSetup,
          zones: CanonicalDemoFarmDataset.zones,
          alerts: CanonicalDemoFarmDataset.alerts,
          verifications: const [],
          opportunities: const [],
          language: _currentLanguage,
        );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    voiceService.playbackStateNotifier.addListener(_onVoicePlaybackStateChanged);

    _addInitialGreeting();

    if (widget.autoStartVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startVoiceInput();
      });
    }
  }

  @override
  void dispose() {
    voiceService.playbackStateNotifier.removeListener(_onVoicePlaybackStateChanged);
    voiceService.stopSpeaking();
    voiceService.stopListening();
    _pulseController.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _onVoicePlaybackStateChanged() {
    if (!mounted) return;
    final state = voiceService.playbackStateNotifier.value;
    if (state == TtsPlaybackState.completed ||
        state == TtsPlaybackState.stopped ||
        state == TtsPlaybackState.error) {
      setState(() {
        _currentlyPlayingMessageId = null;
      });
    }
  }

  void _addInitialGreeting() {
    final farmerName = _farmContext.farmerName;
    final greeting = _translate(
      'Namaste $farmerName! I am your PRAHAR Field Assistant. I am monitoring your 4 zones at Patil Krishi Farm (4.2 Acres). Ask me anything in English, Hindi, Marathi, or Punjabi, or tap a question below.',
      'नमस्ते $farmerName! मैं आपका प्रहार खेत सहायक हूँ। मैं पाटिल कृषि फार्म (4.2 एकड़) के 4 ज़ोन की निगरानी कर रहा हूँ। मुझसे अंग्रेजी, हिंदी, मराठी या पंजाबी में कोई भी सवाल पूछें।',
      'नमस्कार $farmerName! मी तुमचा प्रहार शेती सहाय्यक आहे. मी पाटील कृषी फार्म (4.2 एकर) मधील 4 झोनचे निरीक्षण करत आहे.',
      'ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ $farmerName! ਮੈਂ ਤੁਹਾਡਾ ਪ੍ਰਹਾਰ ਖੇਤ ਸਹਾਇਕ ਹਾਂ। ਮੈਂ ਪਾਟਿਲ ਕ੍ਰਿਸ਼ੀ ਫਾਰਮ ਦੀ ਨਿਗਰਾਨੀ ਕਰ ਰਿਹਾ ਹਾਂ।',
      _currentLanguage,
    );

    _messages.add(PraharChatMessage(
      id: 'greeting_${DateTime.now().millisecondsSinceEpoch}',
      isUser: false,
      text: greeting,
      timestamp: DateTime.now(),
    ));
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String queryText, {bool isVoice = false}) async {
    final cleanText = queryText.trim();
    if (cleanText.isEmpty || _isProcessing) return;

    _inputController.clear();
    setState(() {
      _errorMessage = null;
      _isProcessing = true;
      _messages.add(PraharChatMessage(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        isUser: true,
        text: cleanText,
        timestamp: DateTime.now(),
        isVoice: isVoice,
        voiceDurationText: isVoice ? '0:04' : null,
      ));
    });
    _scrollToBottom();

    try {
      final response = await _assistantEngine.processQuery(
        cleanText,
        context: _farmContext,
        language: _currentLanguage,
        sessionId: _sessionId,
      );

      if (response.referencedZone != null && response.referencedZone!.isNotEmpty) {
        _activeZoneId = response.referencedZone;
      }

      final assistantMsgId = 'assistant_${DateTime.now().millisecondsSinceEpoch}';
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _messages.add(PraharChatMessage(
            id: assistantMsgId,
            isUser: false,
            text: response.answer,
            timestamp: DateTime.now(),
            structuredResponse: response,
          ));
        });
        _scrollToBottom();
      }

      // PRIMARY VOICE RULE: Speak output aloud ONLY if input was Voice
      if (isVoice && mounted) {
        await _speakResponse(response.answer, assistantMsgId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _speakResponse(String text, String messageId) async {
    setState(() {
      _currentlyPlayingMessageId = messageId;
    });

    final success = await voiceService.speak(
      text,
      lang: _currentLanguage,
      utteranceId: messageId,
    );

    if (!success && mounted) {
      setState(() {
        _currentlyPlayingMessageId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.getText('voice_tts_unavailable', _currentLanguage).isNotEmpty
                ? AppLocalizations.getText('voice_tts_unavailable', _currentLanguage)
                : 'Your answer is ready below. Voice playback is temporarily unavailable.',
          ),
          backgroundColor: PraharTheme.textHeading,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _toggleAudioPlayback(String messageId, String text) async {
    if (_currentlyPlayingMessageId == messageId && voiceService.isSpeaking) {
      await voiceService.stopSpeaking();
      setState(() {
        _currentlyPlayingMessageId = null;
      });
    } else {
      await voiceService.stopSpeaking();
      await _speakResponse(text, messageId);
    }
  }

  Future<void> _startVoiceInput() async {
    if (_isListening || _isProcessing) return;

    setState(() {
      _isListening = true;
      _errorMessage = null;
    });
    _pulseController.repeat(reverse: true);

    try {
      final transcript = await voiceService.startListening(lang: _currentLanguage);
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      _pulseController.stop();
      _pulseController.reset();

      if (transcript != null && transcript.trim().isNotEmpty) {
        await _sendMessage(transcript.trim(), isVoice: true);
      } else {
        final err = voiceService.lastSttError;
        if (mounted && err != null && err != 'NO_MATCH' && err != 'TIMEOUT') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.getText('voice_stt_unavailable', _currentLanguage).isNotEmpty
                    ? AppLocalizations.getText('voice_stt_unavailable', _currentLanguage)
                    : "Voice input isn't available right now. You can type your question instead.",
              ),
              backgroundColor: PraharTheme.alertAmber,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  Future<void> _confirmAction(bool confirm, String? pendingId) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final response = await _assistantEngine.processQuery(
        confirm ? 'Confirm irrigation' : 'Cancel action',
        context: _farmContext,
        language: _currentLanguage,
        sessionId: _sessionId,
        confirmAction: confirm,
        pendingActionId: pendingId,
      );

      final assistantMsgId = 'assistant_${DateTime.now().millisecondsSinceEpoch}';
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _messages.add(PraharChatMessage(
            id: assistantMsgId,
            isUser: false,
            text: response.answer,
            timestamp: DateTime.now(),
            structuredResponse: response,
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _currentLanguage == 'hi'
              ? 'बातचीत साफ़ करें?'
              : (_currentLanguage == 'mr'
                  ? 'संभाषण साफ करा?'
                  : (_currentLanguage == 'pa' ? 'ਗੱਲਬਾਤ ਸਾਫ਼ ਕਰੋ?' : 'Clear Conversation?')),
          style: const TextStyle(fontWeight: FontWeight.bold, color: PraharTheme.textHeading),
        ),
        content: Text(
          _currentLanguage == 'hi'
              ? 'क्या आप यह बातचीत साफ़ करना चाहते हैं? आपका खेत डेटा और रोवर स्थिति सुरक्षित रहेगी।'
              : (_currentLanguage == 'mr'
                  ? 'हे संभाषण साफ करायचे आहे का? तुमचा शेताचा डेटा सुरक्षित राहील.'
                  : (_currentLanguage == 'pa'
                      ? 'ਕੀ ਤੁਸੀਂ ਇਹ ਗੱਲਬਾਤ ਸਾਫ਼ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ?'
                      : 'Clear this conversation? Your farm data and telemetry will remain safe.')),
          style: const TextStyle(fontSize: 13, color: PraharTheme.textBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              _currentLanguage == 'hi' ? 'रद्द करें' : 'Cancel',
              style: const TextStyle(color: PraharTheme.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: PraharTheme.alertRose,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _messages.clear();
                _addInitialGreeting();
              });
            },
            child: Text(_currentLanguage == 'hi' ? 'साफ़ करें' : 'Clear'),
          ),
        ],
      ),
    );
  }

  List<String> _getDynamicSuggestions() {
    if (_messages.isEmpty) return const [];
    final lastMsg = _messages.last;
    if (lastMsg.isUser || lastMsg.structuredResponse == null) {
      return [
        'How is my farm today?',
        'Which zone needs attention?',
        'Why is Zone 2 getting dry?',
        "What happened during today's scan?",
      ];
    }

    final intent = lastMsg.structuredResponse!.intent;
    final zone = lastMsg.structuredResponse!.referencedZone ?? _activeZoneId ?? 'DEMO-ZONE-02';

    switch (intent) {
      case AssistantIntent.fieldStatus:
        return [
          'Why is Zone 2 getting dry?',
          'What should I do about Zone 2?',
          'Pest guidance for South Sector?',
          'Explain my field health',
        ];

      case AssistantIntent.zoneStatus:
      case AssistantIntent.hazardExplanation:
        return [
          'What should I do?',
          'Why is this happening?',
          'Show recent readings for $zone',
          'Has this happened before?',
        ];

      case AssistantIntent.recommendationExplanation:
        return [
          'Start micro-irrigation for $zone',
          'Why is this recommendation best?',
          'What happened after the last irrigation?',
          'Which government schemes may be relevant to me?',
        ];

      case AssistantIntent.actionStatus:
      case AssistantIntent.verificationStatus:
        return [
          'Did the action work?',
          'Show the result',
          'How is my farm today?',
          'Predict zone outcome',
        ];

      case AssistantIntent.schemeQuery:
        return [
          'My farm profile & acres',
          'How is my farm today?',
          'Which zone needs attention?',
        ];

      default:
        return [
          'How is my farm today?',
          'Which zone needs attention?',
          'Why is Zone 2 getting dry?',
          'Relevant government schemes?',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PraharTheme.lightBg,
      appBar: _buildAppBar(),
      body: Container(
        key: const Key('assistant_modal_bottom_sheet'),
        child: SafeArea(
          child: Column(
            children: [
              _buildContextBanner(),
              if (_errorMessage != null) _buildErrorBanner(),
              Expanded(child: _buildChatList()),
              if (_isProcessing) _buildProcessingIndicator(),
              _buildSuggestionBar(),
              _buildComposer(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 18, color: PraharTheme.textHeading),
        onPressed: () {
          voiceService.stopSpeaking();
          Navigator.of(context).pop();
        },
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: PraharTheme.primaryGreenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, size: 20, color: PraharTheme.primaryGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      _currentLanguage == 'hi'
                          ? 'प्रहार सहायक'
                          : (_currentLanguage == 'mr'
                              ? 'प्रहार सहाय्यक'
                              : (_currentLanguage == 'pa' ? 'ਪ੍ਰਹਾਰ ਸਹਾਇਕ' : 'PRAHAR Field Assistant')),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: PraharTheme.textHeading,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: PraharTheme.cardBgGreen,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: PraharTheme.borderGreen),
                      ),
                      child: const Text(
                        'DEMO AGENT',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: PraharTheme.darkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_farmContext.farmName} • ${_farmContext.landAcres} Acres • ${_farmContext.district}',
                  style: const TextStyle(fontSize: 10, color: PraharTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          icon: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: PraharTheme.primaryGreenLight,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: PraharTheme.borderGreen),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.language, size: 14, color: PraharTheme.primaryGreen),
                const SizedBox(width: 3),
                Text(
                  _currentLanguage.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PraharTheme.darkGreen),
                ),
              ],
            ),
          ),
          onSelected: (lang) {
            setState(() {
              _currentLanguage = lang;
            });
          },
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'en', child: Text('English (EN)')),
            const PopupMenuItem(value: 'hi', child: Text('हिंदी (Hindi)')),
            const PopupMenuItem(value: 'mr', child: Text('मराठी (Marathi)')),
            const PopupMenuItem(value: 'pa', child: Text('ਪੰਜਾਬੀ (Punjabi)')),
          ],
        ),
        IconButton(
          tooltip: 'Clear Conversation',
          icon: const Icon(Icons.delete_outline, size: 20, color: PraharTheme.textMuted),
          onPressed: _clearChat,
        ),
      ],
    );
  }

  Widget _buildContextBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: PraharTheme.cardBgGreen,
        border: Border(
          bottom: BorderSide(color: PraharTheme.borderGreen, width: 0.8),
        ),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: PraharTheme.primaryGreenLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: PraharTheme.borderGreen),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.landscape_outlined, size: 11, color: PraharTheme.primaryGreen),
                const SizedBox(width: 4),
                Text(
                  '${_farmContext.landAcres} Acres',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PraharTheme.darkGreen),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: PraharTheme.primaryGreenLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: PraharTheme.borderGreen),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.grid_view, size: 11, color: PraharTheme.primaryGreen),
                const SizedBox(width: 4),
                Text(
                  '${_farmContext.zones.length} Zones',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PraharTheme.darkGreen),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: PraharTheme.alertAmberLight,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: PraharTheme.alertAmber),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 11, color: PraharTheme.alertAmber),
                const SizedBox(width: 4),
                Text(
                  '${_farmContext.alerts.length} Alerts',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PraharTheme.alertAmber),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: PraharTheme.cardBgGreen,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: PraharTheme.borderGreen),
            ),
            child: Text(
              '${_farmContext.farm?['crop_type'] ?? 'Soybean + Wheat'}',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: PraharTheme.darkGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: PraharTheme.alertRose.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: PraharTheme.alertRose),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 11, color: PraharTheme.alertRose),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.close, size: 14, color: PraharTheme.alertRose),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return msg.isUser ? _buildUserBubble(msg) : _buildAssistantBubble(msg);
      },
    );
  }

  Widget _buildUserBubble(PraharChatMessage msg) {
    final timeStr = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [PraharTheme.primaryGreen, PraharTheme.mediumGreen],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: PraharTheme.primaryGreen.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (msg.isVoice) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.mic, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          'Voice Message • ${msg.voiceDurationText ?? '0:04'}',
                          style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    msg.text,
                    style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: const TextStyle(fontSize: 9, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          const CircleAvatar(
            radius: 13,
            backgroundColor: PraharTheme.cardBgGreen,
            child: Icon(Icons.person, size: 16, color: PraharTheme.darkGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantBubble(PraharChatMessage msg) {
    final timeStr = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
    final structured = msg.structuredResponse;
    final isPlaying = _currentlyPlayingMessageId == msg.id && voiceService.isSpeaking;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14, right: 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: PraharTheme.primaryGreenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy, size: 16, color: PraharTheme.primaryGreen),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              key: structured != null ? const Key('assistant_response_card') : null,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: PraharTheme.borderGreen, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (structured != null) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          key: const Key('assistant_intent_chip'),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: PraharTheme.primaryGreenLight,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            structured.intent.toWireString(),
                            style: const TextStyle(
                              color: PraharTheme.darkGreen,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (structured.aiProvider.isNotEmpty)
                          Container(
                            key: const Key('assistant_provider_badge'),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: structured.aiProvider == 'OLLAMA_QWEN3_8B'
                                  ? PraharTheme.primaryGreenLight
                                  : PraharTheme.alertAmberLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: structured.aiProvider == 'OLLAMA_QWEN3_8B'
                                    ? PraharTheme.borderGreen
                                    : PraharTheme.alertAmber,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  structured.aiProvider == 'OLLAMA_QWEN3_8B' ? Icons.psychology : Icons.settings_backup_restore,
                                  size: 10,
                                  color: structured.aiProvider == 'OLLAMA_QWEN3_8B' ? PraharTheme.primaryGreen : PraharTheme.alertAmber,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  structured.aiProvider == 'OLLAMA_QWEN3_8B' ? 'Qwen3 8B' : 'Deterministic Fallback',
                                  style: TextStyle(
                                    color: structured.aiProvider == 'OLLAMA_QWEN3_8B' ? PraharTheme.darkGreen : PraharTheme.alertAmber,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (structured.referencedZone != null)
                          Container(
                            key: const Key('assistant_zone_chip'),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: PraharTheme.alertSkyLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: PraharTheme.alertSky, width: 0.8),
                            ),
                            child: Text(
                              structured.referencedZone!,
                              style: const TextStyle(color: PraharTheme.alertSky, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        Container(
                          key: const Key('assistant_severity_chip'),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: structured.severity == 'HIGH'
                                ? PraharTheme.alertRose.withValues(alpha: 0.15)
                                : (structured.severity == 'MEDIUM'
                                    ? PraharTheme.alertAmberLight
                                    : PraharTheme.primaryGreenLight),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            structured.severity,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: structured.severity == 'HIGH'
                                  ? PraharTheme.alertRose
                                  : (structured.severity == 'MEDIUM' ? PraharTheme.alertAmber : PraharTheme.darkGreen),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (structured?.isPrediction == true) ...[
                    Container(
                      key: const Key('assistant_prediction_banner'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertAmberLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PraharTheme.alertAmber),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.analytics_outlined, size: 14, color: PraharTheme.alertAmber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              structured?.predictionLabel ?? 'PRAHAR Scenario Estimate • Indicative Simulation',
                              style: const TextStyle(fontSize: 10, color: PraharTheme.alertAmber, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    msg.text,
                    key: const Key('assistant_answer_text'),
                    style: const TextStyle(
                      color: PraharTheme.textHeading,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  if (structured?.evidence != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      key: const Key('assistant_evidence_box'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PraharTheme.cardBgGreen,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PraharTheme.borderGreen),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: PraharTheme.primaryGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Evidence: ${structured!.evidence!}',
                              style: const TextStyle(fontSize: 11, color: PraharTheme.textBody),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (structured?.evidenceBreakdown.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      key: const Key('assistant_evidence_breakdown_card'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PraharTheme.borderGreen),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentLanguage == 'hi' ? 'सटीक सेंसर डेटा' : 'Current Sensor Telemetry',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PraharTheme.darkGreen),
                          ),
                          const SizedBox(height: 4),
                          ...structured!.evidenceBreakdown.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(item.metric, style: const TextStyle(fontSize: 10, color: PraharTheme.textBody)),
                                    Text(item.observed, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: PraharTheme.textHeading)),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                  if (structured?.recommendation != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertAmberLight,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: PraharTheme.alertAmber),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 14, color: PraharTheme.alertAmber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Recommendation: ${structured!.recommendation!}',
                              style: const TextStyle(fontSize: 11, color: PraharTheme.textHeading, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                                    if (structured?.safetyLevel == AssistantSafetyLevel.prohibitedAutonomous) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: const Key('assistant_prohibited_box'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertRoseLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PraharTheme.alertRose.withValues(alpha: 0.5)),
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
                  if (structured?.requiresConfirmation == true) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: const Key('assistant_safety_gate_box'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: PraharTheme.alertAmberLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: PraharTheme.alertAmber.withValues(alpha: 0.5)),
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
                                value: _actionConfirmedMap[msg.id] ?? false,
                                activeColor: PraharTheme.primaryGreen,
                                onChanged: (val) {
                                  setState(() {
                                    _actionConfirmedMap[msg.id] = val ?? false;
                                  });
                                },
                              ),
                              const Expanded(
                                child: Text(
                                  'I explicitly authorize simulated execution of this action.',
                                  style: TextStyle(fontSize: 11, color: PraharTheme.textBody),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              key: const Key('assistant_confirm_button'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_actionConfirmedMap[msg.id] ?? false) ? PraharTheme.primaryGreen : Colors.grey[300],
                                foregroundColor: (_actionConfirmedMap[msg.id] ?? false) ? Colors.white : Colors.grey[600],
                              ),
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('Execute Action (Simulated)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                              onPressed: (_actionConfirmedMap[msg.id] ?? false) && !_isProcessing
                                  ? () => _confirmAction(true, structured?.pendingAction?.id ?? structured?.pendingAction?.actionType)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => _toggleAudioPlayback(msg.id, msg.text),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPlaying ? PraharTheme.primaryGreen : PraharTheme.primaryGreenLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isPlaying ? PraharTheme.primaryGreen : PraharTheme.borderGreen),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPlaying ? Icons.stop : Icons.volume_up,
                                size: 13,
                                color: isPlaying ? Colors.white : PraharTheme.darkGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPlaying ? 'Stop' : 'Listen',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isPlaying ? Colors.white : PraharTheme.darkGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(fontSize: 9, color: PraharTheme.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: PraharTheme.primaryGreen),
          ),
          const SizedBox(width: 8),
          Text(
            _currentLanguage == 'hi'
                ? 'प्रहार आपके खेत का विश्लेषण कर रहा है...'
                : (_currentLanguage == 'mr'
                    ? 'प्रहार शेताचे विश्लेषण करत आहे...'
                    : 'PRAHAR is analyzing your field...'),
            style: const TextStyle(fontSize: 11, color: PraharTheme.darkGreen, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionBar() {
    final suggestions = _getDynamicSuggestions();
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 38,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
          ActionChip(
            key: const Key('assistant_chip_attention'),
            label: Text(
              _currentLanguage == 'hi' ? 'किस ज़ोन पर ध्यान दें?' : 'What needs attention first?',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: PraharTheme.darkGreen),
            ),
            backgroundColor: PraharTheme.cardBgGreen,
            side: const BorderSide(color: PraharTheme.borderGreen),
            onPressed: () => _sendMessage('What needs attention first?'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            key: const Key('assistant_chip_prediction'),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_graph, size: 12, color: PraharTheme.alertSky),
                SizedBox(width: 4),
                Text('Prediction: Zone 2 moisture 6h', style: TextStyle(fontSize: 11, color: PraharTheme.alertSky)),
              ],
            ),
            backgroundColor: PraharTheme.alertSkyLight,
            side: const BorderSide(color: PraharTheme.alertSky),
            onPressed: () => _sendMessage('Predict soil moisture for Zone 2 in 6 hours'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            key: const Key('assistant_chip_farm_status'),
            label: Text(
              _currentLanguage == 'hi' ? 'खेत का हाल' : 'Farm Overview',
              style: const TextStyle(fontSize: 11, color: PraharTheme.darkGreen),
            ),
            backgroundColor: PraharTheme.cardBgGreen,
            side: const BorderSide(color: PraharTheme.borderGreen),
            onPressed: () => _sendMessage('How is my farm today?'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            key: const Key('assistant_chip_analysis'),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.analytics, size: 12, color: PraharTheme.primaryGreen),
                SizedBox(width: 4),
                Text('Analysis: Zone 2 vs Zone 1', style: TextStyle(fontSize: 11, color: PraharTheme.primaryGreen)),
              ],
            ),
            backgroundColor: PraharTheme.cardBgGreen,
            side: const BorderSide(color: PraharTheme.borderGreen),
            onPressed: () => _sendMessage('Compare telemetry between Zone 1 and Zone 2'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            key: const Key('assistant_chip_zone2'),
            label: Text(
              _currentLanguage == 'hi' ? 'ज़ोन 2 सूखा क्यों?' : 'Why is Zone 2 getting dry?',
              style: const TextStyle(fontSize: 11, color: PraharTheme.alertAmber),
            ),
            backgroundColor: PraharTheme.alertAmberLight,
            side: const BorderSide(color: PraharTheme.alertAmber),
            onPressed: () => _sendMessage('Why is Zone 2 getting dry?'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            key: const Key('assistant_chip_compare'),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 12, color: PraharTheme.alertAmber),
                SizedBox(width: 4),
                Text('Scan History: Last 7 Days', style: TextStyle(fontSize: 11, color: PraharTheme.alertAmber)),
              ],
            ),
            backgroundColor: PraharTheme.alertAmberLight,
            side: const BorderSide(color: PraharTheme.alertAmber),
            onPressed: () => _sendMessage('Show recent scan history breakdown'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            key: const Key('assistant_chip_schemes'),
            label: Text(
              _currentLanguage == 'hi' ? 'सरकारी योजनाएं' : 'Government Schemes',
              style: const TextStyle(fontSize: 11, color: PraharTheme.alertSky),
            ),
            backgroundColor: PraharTheme.alertSkyLight,
            side: const BorderSide(color: PraharTheme.alertSky),
            onPressed: () => _sendMessage('Which government schemes may be relevant to me?'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            key: const Key('assistant_chip_pest'),
            label: Text(
              _currentLanguage == 'hi' ? 'कीट सलाह (दक्षिण)' : 'Pest Guidance',
              style: const TextStyle(fontSize: 11, color: PraharTheme.darkGreen),
            ),
            backgroundColor: PraharTheme.cardBgGreen,
            side: const BorderSide(color: PraharTheme.borderGreen),
            onPressed: () => _sendMessage('What should I do about the pest detected in South Sector?'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            key: const Key('assistant_chip_verification'),
            label: Text(
              _currentLanguage == 'hi' ? 'सत्यापन परिणाम' : 'Verification Delta',
              style: const TextStyle(fontSize: 11, color: PraharTheme.darkGreen),
            ),
            backgroundColor: PraharTheme.cardBgGreen,
            side: const BorderSide(color: PraharTheme.borderGreen),
            onPressed: () => _sendMessage('Show me what happened after the irrigation action'),
          ),
          const SizedBox(width: 6),
          ActionChip(
            key: const Key('assistant_chip_profile'),
            label: Text(
              _currentLanguage == 'hi' ? 'मेरी प्रोफ़ाइल' : 'My Profile',
              style: const TextStyle(fontSize: 11, color: PraharTheme.darkGreen),
            ),
            backgroundColor: PraharTheme.cardBgGreen,
            side: const BorderSide(color: PraharTheme.borderGreen),
            onPressed: () => _sendMessage('Show my farm profile and acres'),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: PraharTheme.borderGreen, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('assistant_input_field'),
              controller: _inputController,
              focusNode: _inputFocusNode,
              textInputAction: TextInputAction.send,
              style: const TextStyle(fontSize: 14, color: PraharTheme.textHeading),
              decoration: InputDecoration(
                hintText: _currentLanguage == 'hi'
                    ? 'प्रहार से पूछें...'
                    : (_currentLanguage == 'mr'
                        ? 'प्रहारला विचारा...'
                        : (_currentLanguage == 'pa' ? 'ਪ੍ਰਹਾਰ ਨੂੰ ਪੁੱਛੋ...' : 'Ask PRAHAR anything...')),
                hintStyle: const TextStyle(fontSize: 13, color: PraharTheme.textMuted),
                filled: true,
                fillColor: PraharTheme.lightBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: PraharTheme.borderGreen),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: PraharTheme.borderGreen),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: PraharTheme.primaryGreen, width: 1.5),
                ),
              ),
              onSubmitted: (val) => _sendMessage(val, isVoice: false),
            ),
          ),
          const SizedBox(width: 8),
          ScaleTransition(
            scale: _isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
            child: Material(
              color: _isListening ? PraharTheme.alertRose : PraharTheme.primaryGreen,
              shape: const CircleBorder(),
              elevation: 2,
              child: IconButton(
                key: const Key('assistant_mic_button'),
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 22),
                tooltip: 'Speak to PRAHAR',
                onPressed: _isProcessing ? null : _startVoiceInput,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: PraharTheme.primaryGreenLight,
            shape: const CircleBorder(),
            child: IconButton(
              key: const Key('assistant_send_button'),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: PraharTheme.primaryGreen),
                    )
                  : const Icon(Icons.send, color: PraharTheme.primaryGreen, size: 20),
              tooltip: 'Send',
              onPressed: _isProcessing ? null : () => _sendMessage(_inputController.text, isVoice: false),
            ),
          ),
        ],
      ),
    );
  }
}
