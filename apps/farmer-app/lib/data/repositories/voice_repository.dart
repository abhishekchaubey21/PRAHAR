import '../../core/api_client.dart';

class VoiceResponseModel {
  final String spokenTextEn;
  final String spokenTextHi;
  final String intent;
  final bool requiresConfirmation;
  final String? confirmationPromptEn;
  final String? confirmationPromptHi;
  final Map<String, dynamic>? pendingAction;
  final String safetyNoticeEn;
  final String safetyNoticeHi;

  const VoiceResponseModel({
    required this.spokenTextEn,
    required this.spokenTextHi,
    required this.intent,
    required this.requiresConfirmation,
    this.confirmationPromptEn,
    this.confirmationPromptHi,
    this.pendingAction,
    required this.safetyNoticeEn,
    required this.safetyNoticeHi,
  });

  factory VoiceResponseModel.fromJson(Map<String, dynamic> json) {
    return VoiceResponseModel(
      spokenTextEn: json['spoken_text_en'] as String? ?? '',
      spokenTextHi: json['spoken_text_hi'] as String? ?? '',
      intent: json['intent'] as String? ?? 'UNKNOWN',
      requiresConfirmation: json['requires_confirmation'] as bool? ?? false,
      confirmationPromptEn: json['confirmation_prompt_en'] as String?,
      confirmationPromptHi: json['confirmation_prompt_hi'] as String?,
      pendingAction: json['pending_action'] is Map
          ? Map<String, dynamic>.from(json['pending_action'] as Map)
          : null,
      safetyNoticeEn: json['safety_notice_en'] as String? ?? '',
      safetyNoticeHi: json['safety_notice_hi'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'spoken_text_en': spokenTextEn,
        'spoken_text_hi': spokenTextHi,
        'intent': intent,
        'requires_confirmation': requiresConfirmation,
        'confirmation_prompt_en': confirmationPromptEn,
        'confirmation_prompt_hi': confirmationPromptHi,
        'pending_action': pendingAction,
        'safety_notice_en': safetyNoticeEn,
        'safety_notice_hi': safetyNoticeHi,
      };
}

class VoiceRepository {
  final ApiClient _apiClient;

  VoiceRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Sends voice natural language query to the authenticated Gateway endpoint
  /// Voice flows through: STT/input -> classification -> safety policy -> response -> confirmation.
  /// Absolute safety rule: Voice never directly executes physical actuators.
  Future<VoiceResponseModel> sendVoiceQuery({
    required String text,
    required String language,
    String inputType = 'SIMULATED_VOICE_INTENT',
    String? sessionId,
  }) async {
    final response = await _apiClient.post(
      '/api/voice/interact',
      body: {
        'text': text,
        'query': text,
        'language': language,
        'input_type': inputType,
        if (sessionId != null) 'session_id': sessionId,
      },
    );

    final responseData = (response != null && response['response'] is Map<String, dynamic>)
        ? response['response'] as Map<String, dynamic>
        : (response is Map<String, dynamic> ? response : null);

    if (responseData != null) {
      return VoiceResponseModel.fromJson(responseData);
    }

    throw const ApiException(500, 'Invalid voice response format from server');
  }
}
