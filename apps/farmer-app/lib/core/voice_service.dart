import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Playback states for Assistant TTS.
enum TtsPlaybackState {
  idle,
  playing,
  paused,
  stopped,
  completed,
  error,
}

/// Recognition states for Assistant STT.
enum SttState {
  idle,
  requestingPermission,
  ready,
  listening,
  processing,
  error,
}

/// VoiceService bridges Flutter to native Android TTS and STT via a
/// MethodChannel. On platforms without a native voice channel (e.g. tests,
/// iOS simulator) all capability flags are false and all calls are no-ops.
class VoiceService {
  static const _channel = MethodChannel('org.prahar.farmer_app/voice');

  bool _initialized = false;
  bool _ttsAvailable = false;
  bool _sttAvailable = false;
  String? _lastSttError;
  String? _lastPartialTranscript;

  final ValueNotifier<TtsPlaybackState> playbackStateNotifier =
      ValueNotifier(TtsPlaybackState.idle);
  final ValueNotifier<String?> activeUtteranceNotifier = ValueNotifier(null);
  final ValueNotifier<SttState> sttStateNotifier = ValueNotifier(SttState.idle);
  final ValueNotifier<String?> partialTranscriptNotifier = ValueNotifier(null);

  bool get isInitialized => _initialized;
  bool get ttsAvailable => _ttsAvailable;
  bool get sttAvailable => _sttAvailable;
  String? get lastSttError => _lastSttError;
  String? get lastPartialTranscript => _lastPartialTranscript;
  bool get isSpeaking => playbackStateNotifier.value == TtsPlaybackState.playing;
  bool get isListening => sttStateNotifier.value == SttState.listening;

  VoiceService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onTtsReady':
        _ttsAvailable = true;
        _initialized = true;
        break;

      case 'onTtsStart':
        final utteranceId = call.arguments is Map
            ? (call.arguments['utteranceId'] as String?)
            : null;
        activeUtteranceNotifier.value = utteranceId;
        playbackStateNotifier.value = TtsPlaybackState.playing;
        break;

      case 'onTtsDone':
        playbackStateNotifier.value = TtsPlaybackState.completed;
        activeUtteranceNotifier.value = null;
        break;

      case 'onTtsError':
        playbackStateNotifier.value = TtsPlaybackState.error;
        activeUtteranceNotifier.value = null;
        break;

      case 'onSttReady':
        sttStateNotifier.value = SttState.ready;
        break;

      case 'onSttListening':
        sttStateNotifier.value = SttState.listening;
        break;

      case 'onSttProcessing':
        sttStateNotifier.value = SttState.processing;
        break;

      case 'onSttPartial':
        if (call.arguments is Map) {
          final partial = call.arguments['partial'] as String?;
          _lastPartialTranscript = partial;
          partialTranscriptNotifier.value = partial;
        }
        break;
    }
  }

  /// Call once at startup or when checking capability.
  Future<void> init() async {
    try {
      final tts = await _channel.invokeMethod<bool>('isTtsAvailable');
      _ttsAvailable = tts ?? false;
      final stt = await _channel.invokeMethod<bool>('isSttAvailable');
      _sttAvailable = stt ?? false;
      _initialized = true;
    } on MissingPluginException {
      // Running in test or web; no-op
      _ttsAvailable = false;
      _sttAvailable = false;
      _initialized = true;
    } catch (e) {
      debugPrint('[VoiceService] init error: $e');
      _ttsAvailable = false;
      _sttAvailable = false;
      _initialized = true;
    }
  }

  /// Check if runtime microphone permission is granted.
  Future<bool> checkPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('checkPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Request runtime microphone permission from the user.
  Future<bool> requestPermission() async {
    try {
      sttStateNotifier.value = SttState.requestingPermission;
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      sttStateNotifier.value = SttState.idle;
      return granted ?? false;
    } catch (_) {
      sttStateNotifier.value = SttState.idle;
      return false;
    }
  }

  /// Check if the native TTS engine supports the given language.
  Future<bool> isLanguageSupported(String lang) async {
    await init();
    if (!_ttsAvailable) return false;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'isLanguageAvailable',
        {'lang': lang},
      );
      return res?['available'] == true;
    } catch (_) {
      return true; // Assume standard Indian locale fallback
    }
  }

  /// Speak [text] in the given BCP-47 language code (e.g. "en", "hi", "mr", "pa").
  /// Returns true if speech started successfully.
  Future<bool> speak(String text, {String lang = 'en', String? utteranceId}) async {
    await init();
    if (!_ttsAvailable) {
      playbackStateNotifier.value = TtsPlaybackState.error;
      return false;
    }
    try {
      playbackStateNotifier.value = TtsPlaybackState.playing;
      activeUtteranceNotifier.value = utteranceId ?? 'prahar_speech';
      final ok = await _channel.invokeMethod<bool>('speak', {
        'text': text,
        'lang': lang,
      });
      if (ok != true) {
        playbackStateNotifier.value = TtsPlaybackState.error;
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('[VoiceService] speak error: $e');
      playbackStateNotifier.value = TtsPlaybackState.error;
      return false;
    }
  }

  /// Stop any current TTS utterance.
  Future<void> stopSpeaking() async {
    if (!_ttsAvailable) return;
    try {
      await _channel.invokeMethod('stopSpeaking');
      playbackStateNotifier.value = TtsPlaybackState.stopped;
      activeUtteranceNotifier.value = null;
    } catch (e) {
      debugPrint('[VoiceService] stopSpeaking error: $e');
    }
  }

  /// Start a single-utterance STT session. Returns the transcript if
  /// recognition was successful, or null on failure/unavailability.
  Future<String?> startListening({String lang = 'en'}) async {
    await init();
    _lastSttError = null;
    _lastPartialTranscript = null;
    partialTranscriptNotifier.value = null;

    if (!_sttAvailable) {
      _lastSttError = 'STT_NOT_AVAILABLE';
      sttStateNotifier.value = SttState.error;
      return null;
    }

    // Check / request runtime microphone permission
    final hasPerm = await checkPermission();
    if (!hasPerm) {
      final granted = await requestPermission();
      if (!granted) {
        _lastSttError = 'PERMISSION_DENIED';
        sttStateNotifier.value = SttState.error;
        return null;
      }
    }

    try {
      sttStateNotifier.value = SttState.listening;
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'startListening',
        {'lang': lang},
      );

      sttStateNotifier.value = SttState.idle;

      if (result == null) {
        _lastSttError = 'NO_RESPONSE';
        return null;
      }

      final success = result['success'] as bool? ?? false;
      if (!success) {
        _lastSttError = result['error'] as String? ?? 'UNKNOWN_ERROR';
        debugPrint('[VoiceService] STT error: $_lastSttError');
        return null;
      }

      final transcript = result['transcript'] as String?;
      return transcript;
    } catch (e) {
      sttStateNotifier.value = SttState.idle;
      _lastSttError = e.toString();
      debugPrint('[VoiceService] startListening error: $e');
      return null;
    }
  }

  /// Stops an ongoing STT session early and awaits final results.
  Future<void> stopListening() async {
    if (!_sttAvailable) return;
    try {
      await _channel.invokeMethod('stopListening');
      sttStateNotifier.value = SttState.idle;
    } catch (e) {
      debugPrint('[VoiceService] stopListening error: $e');
    }
  }

  /// Cancels an ongoing STT session and releases the microphone immediately.
  Future<void> cancelListening() async {
    try {
      await _channel.invokeMethod('cancelListening');
      sttStateNotifier.value = SttState.idle;
    } catch (e) {
      debugPrint('[VoiceService] cancelListening error: $e');
    }
  }

  /// Returns user-friendly localized error messages for specific STT error codes.
  static String getLocalizedErrorMessage(String? errorCode, String lang) {
    switch (errorCode) {
      case 'PERMISSION_DENIED':
        switch (lang) {
          case 'hi':
            return 'प्रहार से बोलकर पूछने के लिए माइक्रोफ़ोन की अनुमति आवश्यक है। कृपया सेटिंग में अनुमति दें।';
          case 'mr':
            return 'प्रहारशी बोलण्यासाठी मायक्रोफोन परवानगी आवश्यक आहे. कृपया सेटिंग्जमध्ये परवानगी द्या.';
          case 'pa':
            return 'ਪ੍ਰਹਾਰ ਨਾਲ ਬੋਲਣ ਲਈ ਮਾਈਕ੍ਰੋਫੋਨ ਦੀ ਇਜਾਜ਼ਤ ਲੋੜੀਂਦੀ ਹੈ। ਕਿਰਪਾ ਕਰਕੇ ਇਜਾਜ਼ਤ ਦਿਓ।';
          default:
            return 'Microphone permission is required to speak to PRAHAR. Please enable it in Settings.';
        }

      case 'NO_MATCH':
        switch (lang) {
          case 'hi':
            return 'आवाज़ स्पष्ट सुनाई नहीं दी। कृपया माइक बटन दबाकर दोबारा बोलें।';
          case 'mr':
            return 'आवाज स्पष्ट ऐकू आला नाही. कृपया माइक दाबून पुन्हा बोला.';
          case 'pa':
            return 'ਆਵਾਜ਼ ਸਪਸ਼ਟ ਨਹੀਂ ਸੁਣੀ। ਕਿਰਪਾ ਕਰਕੇ ਮਾਈਕ ਦਬਾ ਕੇ ਦੁਬਾਰਾ ਬੋਲੋ।';
          default:
            return "I couldn't hear that clearly. Please tap the mic and try again.";
        }

      case 'TIMEOUT':
        switch (lang) {
          case 'hi':
            return 'समय समाप्त हो गया। कृपया माइक बटन दबाएं और तुरंत अपना प्रश्न बोलें।';
          case 'mr':
            return 'वेळ संपली. कृपया माइक दाबून प्रश्न बोला.';
          case 'pa':
            return 'ਸਮਾਂ ਸਮਾਪਤ ਹੋ ਗਿਆ। ਕਿਰਪਾ ਕਰਕੇ ਮਾਈਕ ਦਬਾ ਕੇ ਆਪਣਾ ਸਵਾਲ ਬੋਲੋ।';
          default:
            return 'Listening timed out. Please tap the mic and speak your question.';
        }

      case 'NETWORK_ERROR':
      case 'NETWORK_TIMEOUT':
        switch (lang) {
          case 'hi':
            return 'नेटवर्क समस्या के कारण आवाज़ पहचान नहीं हो सकी। आप टाइप करके भी पूछ सकते हैं।';
          case 'mr':
            return 'नेटवर्क समस्येमुळे आवाज ओळखता आला नाही. आपण टाइप करू शकता.';
          case 'pa':
            return 'ਨੈੱਟਵਰਕ ਸਮੱਸਿਆ ਕਾਰਨ ਆਵਾਜ਼ ਪਛਾਣ ਨਹੀਂ ਹੋ ਸਕੀ। ਤੁਸੀਂ ਟਾਈਪ ਵੀ ਕਰ ਸਕਦੇ ਹੋ।';
          default:
            return 'Speech recognition network error. You can also type your question.';
        }

      case 'LANGUAGE_NOT_SUPPORTED':
      case 'LANGUAGE_UNAVAILABLE':
        switch (lang) {
          case 'hi':
            return 'इस डिवाइस पर हिंदी वॉइस इनपुट उपलब्ध नहीं है। आप अंग्रेजी में बोल सकते हैं या टाइप कर सकते हैं।';
          case 'mr':
            return 'या डिव्हाइसवर मराठी व्हॉईस इनपुट उपलब्ध नाही. आपण इंग्रजीत बोलू शकता किंवा टाइप करू शकता.';
          case 'pa':
            return 'ਇਸ ਡਿਵਾਈਸ ਤੇ ਪੰਜਾਬੀ ਵੌਇਸ ਇਨਪੁਟ ਉਪਲਬਧ ਨਹੀਂ ਹੈ। ਤੁਸੀਂ ਅੰਗਰੇਜ਼ੀ ਵਿੱਚ ਬੋਲ ਸਕਦੇ ਹੋ ਜਾਂ ਟਾਈਪ ਕਰ ਸਕਦੇ ਹੋ।';
          default:
            return 'Speech recognition in this language is not supported on this device.';
        }

      case 'STT_NOT_AVAILABLE':
        switch (lang) {
          case 'hi':
            return 'इस डिवाइस पर वॉइस इनपुट उपलब्ध नहीं है। आप नीचे सवाल टाइप कर सकते हैं।';
          case 'mr':
            return 'या डिव्हाइसवर व्हॉईस इनपुट उपलब्ध नाही. आपण खाली प्रश्न टाइप करू शकता.';
          case 'pa':
            return 'ਇਸ ਡਿਵਾਈਸ ਤੇ ਵੌਇਸ ਇਨਪੁਟ ਉਪਲਬਧ ਨਹੀਂ ਹੈ। ਤੁਸੀਂ ਹੇਠਾਂ ਸਵਾਲ ਟਾਈਪ ਕਰ ਸਕਦੇ ਹੋ।';
          default:
            return "Voice input is not available on this device. You can type your question below.";
        }

      default:
        switch (lang) {
          case 'hi':
            return 'वॉइस इनपुट में समस्या आई। कृपया दोबारा प्रयास करें या टाइप करें।';
          case 'mr':
            return 'व्हॉईस इनपुटमध्ये अडचण आली. कृपया पुन्हा प्रयत्न करा किंवा टाइप करा.';
          case 'pa':
            return 'ਵੌਇਸ ਇਨਪੁਟ ਵਿੱਚ ਸਮੱਸਿਆ ਆਈ। ਕਿਰਪਾ ਕਰਕੇ ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ।';
          default:
            return 'Voice input encountered an error. Please try again or type your question.';
        }
    }
  }
}

/// Singleton accessor — shared across widgets.
final VoiceService voiceService = VoiceService();
