import '../../core/api_client.dart';
import '../../core/storage/offline_store.dart';
import '../../domain/models.dart';

class FarmRepository {
  final ApiClient _apiClient;
  final IOfflineStore _offlineStore;

  FarmRepository({
    required ApiClient apiClient,
    required IOfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  Future<List<FarmModel>> getFarms() async {
    try {
      final response = await _apiClient.get('/api/farms');
      if (response != null && response['farms'] is List) {
        final list = (response['farms'] as List)
            .map((item) => FarmModel.fromJson(item as Map<String, dynamic>))
            .toList();

        // Cache for genuine offline fallback
        await _offlineStore.cacheData('farms', response['farms']);
        return list;
      }
      return [];
    } on NetworkUnavailableException {
      // Manager Amendment: NetworkUnavailableException may use cached data when available, and otherwise show offline/empty state
      final cached = await _offlineStore.getCachedData('farms');
      if (cached is List && cached.isNotEmpty) {
        return cached
            .map((item) => FarmModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
    // ApiException (401/403/400/422/500) will propagate directly to caller
  }
}
