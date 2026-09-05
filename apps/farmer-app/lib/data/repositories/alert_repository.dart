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
    } on NetworkUnavailableException {
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List) {
        return cached
            .map((item) => AlertModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    // Default baseline alerts if offline and no cache
    return [
      AlertModel(
        id: 'alert-01',
        zoneId: 'DEMO-ZONE-02',
        zoneName: 'Zone 2 (East Sector)',
        type: HazardType.waterStress,
        severity: AlertSeverity.high,
        message: 'High Water Stress: Soil moisture at 17.5% (below 20% critical threshold).',
        messageHi: 'गंभीर जल तनाव: मिट्टी की नमी 17.5% है (20% गंभीर सीमा से कम)।',
        recommendedAction: 'Micro-irrigation recommended for 30s. Awaiting your approval.',
        recommendedActionHi: '30 सेकंड सूक्ष्म-सिंचाई की सिफारिश। आपकी स्वीकृति आवश्यक है।',
        status: AlertStatus.newAlert,
        timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        isApproved: false,
      ),
      AlertModel(
        id: 'alert-02',
        zoneId: 'DEMO-ZONE-03',
        zoneName: 'Zone 3 (South Sector)',
        type: HazardType.disease,
        severity: AlertSeverity.medium,
        message: 'Suspected Early Blight on basal leaves under high humidity (78%).',
        messageHi: 'उच्च आर्द्रता (78%) में निचली पत्तियों पर संदिग्ध Early Blight।',
        recommendedAction: 'Isolate affected plot. Expert agronomist review requested.',
        recommendedActionHi: 'प्रभावित क्षेत्र अलग करें। विशेषज्ञ समीक्षा का अनुरोध किया गया।',
        status: AlertStatus.newAlert,
        timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
        isApproved: false,
      ),
    ];
  }
}
