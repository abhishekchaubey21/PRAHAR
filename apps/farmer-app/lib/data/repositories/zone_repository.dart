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
    } on NetworkUnavailableException {
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List) {
        return cached
            .map((item) => ZoneModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    // Default fallback
    return const [
      ZoneModel(
        id: 'ZONE-A1',
        name: 'Zone 1 (North Plot)',
        soilType: 'Black Cotton',
        moisturePct: 32.5,
        temperatureC: 28.4,
        humidityPct: 62.0,
        ph: 6.8,
      ),
      ZoneModel(
        id: 'DEMO-ZONE-02',
        name: 'Zone 2 (East Sector)',
        soilType: 'Sandy Loam',
        moisturePct: 17.5,
        temperatureC: 34.2,
        humidityPct: 45.0,
        ph: 7.1,
      ),
    ];
  }
}
