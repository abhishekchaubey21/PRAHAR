import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// VoiceService bridges Flutter to native Android TTS and STT via a
/// MethodChannel.  On platforms without a native voice channel (e.g. tests,
/// iOS simulator) all capability flags are false and all calls are no-ops.
class VoiceService {
  static const _channel = MethodChannel('org.prahar.farmer_app/voice');

  // Cached capability flags set by [init].
  bool _ttsAvailable = false;
  bool _sttAvailable = false;

  bool get ttsAvailable => _ttsAvailable;
  bool get sttAvailable => _sttAvailable;

  /// Call once at startup (in the voice dialog init).
  Future<void> init() async {
    try {
      _ttsAvailable = (await _channel.invokeMethod<bool>('isTtsAvailable')) ?? false;
      _sttAvailable = (await _channel.invokeMethod<bool>('isSttAvailable')) ?? false;
    } on MissingPluginException {
      // Running in test or web; no-op
      _ttsAvailable = false;
      _sttAvailable = false;
    } catch (e) {
      debugPrint('[VoiceService] init error: $e');
      _ttsAvailable = false;
      _sttAvailable = false;
    }
  }

  /// Speak [text] in the given BCP-47 language code (e.g. "en", "hi", "mr", "pa").
  /// Returns true if speech started successfully.
  Future<bool> speak(String text, {String lang = 'en'}) async {
    if (!_ttsAvailable) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('speak', {
        'text': text,
        'lang': lang,
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('[VoiceService] speak error: $e');
      return false;
    }
  }

  /// Stop any current TTS utterance.
  Future<void> stopSpeaking() async {
    if (!_ttsAvailable) return;
    try {
      await _channel.invokeMethod('stopSpeaking');
    } catch (e) {
      debugPrint('[VoiceService] stopSpeaking error: $e');
    }
  }

  /// Start a single-utterance STT session.  Returns the transcript if
  /// recognition was successful, or null on failure/unavailability.
  Future<String?> startListening({String lang = 'en'}) async {
    if (!_sttAvailable) return null;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'startListening',
        {'lang': lang},
      );
      if (result == null) return null;
      final success = result['success'] as bool? ?? false;
      if (!success) {
        debugPrint('[VoiceService] STT error: ${result['error']}');
        return null;
      }
      return result['transcript'] as String?;
    } catch (e) {
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

/// Singleton accessor — kept light-weight so it can be shared across widgets.
final VoiceService voiceService = VoiceService();
