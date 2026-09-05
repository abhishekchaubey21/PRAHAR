import '../../core/api_client.dart';
import '../../core/storage/offline_store.dart';
import '../../domain/models.dart';

class ZoneRepository {
  final ApiClient _apiClient;
  final IOfflineStore _offlineStore;

  ZoneRepository({
    required ApiClient apiClient,
    required IOfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  Future<List<ZoneModel>> getZones({String? farmId}) async {
    final query = farmId != null ? {'farm_id': farmId} : null;
    final cacheKey = 'zones_${farmId ?? 'all'}';

    try {
      final response = await _apiClient.get('/api/zones', queryParams: query);
      if (response != null && response['zones'] is List) {
        final list = (response['zones'] as List)
            .map((item) => ZoneModel.fromJson(item as Map<String, dynamic>))
            .toList();

        await _offlineStore.cacheData(cacheKey, response['zones']);
        return list;
      }
      return [];
    } on NetworkUnavailableException {
      // Manager Amendment: NetworkUnavailableException may use cached data when available, and otherwise show offline/empty state
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List && cached.isNotEmpty) {
        return cached
            .map((item) => ZoneModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    }
    // ApiException (401/403/400/422/500) will propagate directly to caller
  }
}
