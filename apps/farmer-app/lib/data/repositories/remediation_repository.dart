import '../../core/api_client.dart';
import '../../core/storage/offline_store.dart';
import '../../domain/models.dart';

class RemediationRepository {
  final ApiClient _apiClient;
  final IOfflineStore _offlineStore;

  RemediationRepository({
    required ApiClient apiClient,
    required IOfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  Future<List<RemediationVerificationModel>> getVerifications({String? zoneId}) async {
    final query = zoneId != null ? {'zone_id': zoneId} : null;
    final cacheKey = 'verifications_${zoneId ?? 'all'}';

    try {
      final response = await _apiClient.get('/api/remediation/verifications', queryParams: query);
      if (response != null && response['data'] is List) {
        final list = (response['data'] as List)
            .map((item) => RemediationVerificationModel.fromJson(item as Map<String, dynamic>))
            .toList();

        await _offlineStore.cacheData(cacheKey, response['data']);
        return list;
      }
    } on NetworkUnavailableException {
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List) {
        return cached
            .map((item) => RemediationVerificationModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    return [];
  }

  Future<bool> executeIntervention(String actionId) async {
    try {
      final response = await _apiClient.post('/api/remediation/execute', body: {
        'action_id': actionId,
      });
      return response != null && response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<RemediationVerificationModel?> verifyIntervention(String actionId) async {
    try {
      final response = await _apiClient.post('/api/remediation/verify', body: {
        'action_id': actionId,
      });
      if (response != null && response['data'] != null) {
        return RemediationVerificationModel.fromJson(response['data'] as Map<String, dynamic>);
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
