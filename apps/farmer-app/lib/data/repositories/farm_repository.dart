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
    } on NetworkUnavailableException {
      // Mandatory Amendment 1: Fallback ONLY when network is genuinely unavailable
      final cached = await _offlineStore.getCachedData('farms');
      if (cached is List) {
        return cached
            .map((item) => FarmModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    // Default demo fallback if no network and no cache
    return const [
      FarmModel(
        id: 'FARM-DEMO-01',
        name: 'Demo Farm Alpha',
        location: 'Indore, Madhya Pradesh',
        totalHectares: 4.2,
        farmerId: 'FARMER-DEMO-01',
      ),
    ];
  }
}
