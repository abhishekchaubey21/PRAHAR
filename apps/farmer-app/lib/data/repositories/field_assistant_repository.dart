/// PRAHAR Phase 7B — Field Assistant Repository
/// Connects to Gateway POST /api/assistant/query with JWT auth and resilient fallback

import '../../core/api_client.dart';
import '../../domain/assistant_model.dart';

class FieldAssistantRepository {
  final ApiClient _apiClient;

  FieldAssistantRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<AssistantStructuredResponse> queryAssistant({
    required String query,
    required String language,
    String? sessionId,
    FarmerAssistantContext? context,
    bool? confirmAction,
    String? pendingActionId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/api/assistant/query',
        body: {
          'query': query,
          'language': language,
          if (sessionId != null) 'session_id': sessionId,
          if (context != null) 'context': context.toJson(),
          if (confirmAction != null) 'confirm_action': confirmAction,
          if (pendingActionId != null) 'pending_action_id': pendingActionId,
        },
      );

      final responseData = (response != null && response['response'] is Map<String, dynamic>)
          ? response['response'] as Map<String, dynamic>
          : (response is Map<String, dynamic> ? response : null);

      if (responseData != null) {
        return AssistantStructuredResponse.fromJson(responseData);
      }
    } catch (_) {
      // Handled by caller or offline engine fallback
      rethrow;
    }

    throw const ApiException(500, 'Invalid assistant response format from server');
  }

  Future<AssistantStructuredResponse?> query(AssistantQueryRequest request) async {
    return queryAssistant(
      query: request.query,
      language: request.language,
      sessionId: request.sessionId,
      context: request.context,
      confirmAction: request.confirmAction,
      pendingActionId: request.pendingActionId,
    );
  }
}
