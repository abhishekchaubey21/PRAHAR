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

/// VoiceService bridges Flutter to native Android TTS and STT via a
/// MethodChannel. On platforms without a native voice channel (e.g. tests,
/// iOS simulator) all capability flags are false and all calls are no-ops.
class VoiceService {
  static const _channel = MethodChannel('org.prahar.farmer_app/voice');

  bool _initialized = false;
  bool _ttsAvailable = false;
  bool _sttAvailable = false;
  String? _lastSttError;

  final ValueNotifier<TtsPlaybackState> playbackStateNotifier =
      ValueNotifier(TtsPlaybackState.idle);
  final ValueNotifier<String?> activeUtteranceNotifier = ValueNotifier(null);

  bool get isInitialized => _initialized;
  bool get ttsAvailable => _ttsAvailable;
  bool get sttAvailable => _sttAvailable;
  String? get lastSttError => _lastSttError;
  bool get isSpeaking => playbackStateNotifier.value == TtsPlaybackState.playing;

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
    if (!_sttAvailable) {
      _lastSttError = 'STT_NOT_AVAILABLE';
      return null;
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'startListening',
        {'lang': lang},
      );
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
      return result['transcript'] as String?;
    } catch (e) {
      _lastSttError = e.toString();
      debugPrint('[VoiceService] startListening error: $e');
      return null;
    }
  }

  /// Stops an ongoing STT session early.
  Future<void> stopListening() async {
    if (!_sttAvailable) return;
    try {
      await _channel.invokeMethod('stopListening');
    } catch (e) {
      debugPrint('[VoiceService] stopListening error: $e');
    }
  }
}

/// Singleton accessor — shared across widgets.
final VoiceService voiceService = VoiceService();
