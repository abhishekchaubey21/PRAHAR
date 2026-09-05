import '../../core/api_client.dart';
import '../../core/storage/offline_store.dart';
import '../../domain/models.dart';

class AlertRepository {
  final ApiClient _apiClient;
  final IOfflineStore _offlineStore;

  AlertRepository({
    required ApiClient apiClient,
    required IOfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  Future<List<AlertModel>> getAlerts({String? zoneId, String? status}) async {
    final query = <String, String>{};
    if (zoneId != null) query['zone_id'] = zoneId;
    if (status != null) query['status'] = status;

    final cacheKey = 'alerts_${zoneId ?? 'all'}_${status ?? 'all'}';

    try {
      final response = await _apiClient.get('/api/alerts', queryParams: query.isNotEmpty ? query : null);
      if (response != null && response['data'] is List) {
        final list = (response['data'] as List)
            .map((item) => AlertModel.fromJson(item as Map<String, dynamic>))
            .toList();

        await _offlineStore.cacheData(cacheKey, response['data']);
        return list;
      }
      return [];
    } on NetworkUnavailableException {
      // Manager Amendment: NetworkUnavailableException may use cached data when available, and otherwise show offline/empty state
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List && cached.isNotEmpty) {
        return cached
            .map((item) => AlertModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
    // ApiException (401/403/400/422/500) will propagate directly to caller
  }
}
