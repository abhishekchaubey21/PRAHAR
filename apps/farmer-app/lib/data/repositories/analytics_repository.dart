import '../../core/api_client.dart';
import '../../core/storage/offline_store.dart';
import '../../domain/models.dart';

/// Repository managing Field Health and Historical Analytics for the Farmer App.
/// Aligned with Phase 6B-2 Specifications:
/// - Supabase authoritative whenever online (Gateway endpoints under RLS)
/// - Strict tenant isolation: user-scoped JWT authentication
/// - Genuine NetworkUnavailableException falls back to local cache
/// - ApiExceptions (400, 401, 403, 404, 422, 500) strictly rethrow; never substituted with fake data
class AnalyticsRepository {
  final ApiClient _apiClient;
  final IOfflineStore _offlineStore;

  static const String summaryCachePrefix = 'analytics_summary_';
  static const String trendsCachePrefix = 'analytics_trends_';
  static const String interventionsCachePrefix = 'analytics_interventions_';

  AnalyticsRepository({
    required ApiClient apiClient,
    required IOfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  bool _isLastFetchOffline = false;
  bool get isLastFetchOffline => _isLastFetchOffline;

  Future<void> clearCache() async {
    // Overwritten or cleared on user logout
  }

  /// Fetches current Field/Zone Health Summary
  Future<FarmAnalyticsSummaryModel> getSummary({
    required String farmId,
    String? zoneId,
  }) async {
    final query = <String, String>{
      'farm_id': farmId,
    };
    if (zoneId != null) query['zone_id'] = zoneId;

    final cacheKey = '$summaryCachePrefix${farmId}_${zoneId ?? "all"}';

    try {
      final response = await _apiClient.get(
        '/api/analytics/summary',
        queryParams: query,
      );

      _isLastFetchOffline = false;
      if (response != null && response['data'] != null) {
        final data = FarmAnalyticsSummaryModel.fromJson(response['data'] as Map<String, dynamic>);
        await _offlineStore.cacheData(cacheKey, response['data']);
        return data;
      }
      throw ApiException(500, 'Invalid summary response structure');
    } on NetworkUnavailableException {
      _isLastFetchOffline = true;
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is Map<String, dynamic>) {
        return FarmAnalyticsSummaryModel.fromJson(cached);
      }
      rethrow;
    }
  }

  /// Fetches Historical Sensor & Hazard Trends for a zone
  Future<AnalyticsTrendsModel> getTrends({
    required String zoneId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final query = <String, String>{
      'zone_id': zoneId,
    };
    if (from != null) query['from'] = from.toIso8601String();
    if (to != null) query['to'] = to.toIso8601String();
    if (limit != null) query['limit'] = limit.toString();

    final cacheKey = '$trendsCachePrefix$zoneId';

    try {
      final response = await _apiClient.get(
        '/api/analytics/trends',
        queryParams: query,
      );

      _isLastFetchOffline = false;
      if (response != null && response['data'] != null) {
        final data = AnalyticsTrendsModel.fromJson(response['data'] as Map<String, dynamic>);
        await _offlineStore.cacheData(cacheKey, response['data']);
        return data;
      }
      throw ApiException(500, 'Invalid trends response structure');
    } on NetworkUnavailableException {
      _isLastFetchOffline = true;
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is Map<String, dynamic>) {
        return AnalyticsTrendsModel.fromJson(cached);
      }
      rethrow;
    }
  }

  /// Fetches Remediation Interventions & Verification history
  Future<AnalyticsInterventionsModel> getInterventions({
    String? farmId,
    String? zoneId,
    int? limit,
  }) async {
    final query = <String, String>{};
    if (farmId != null) query['farm_id'] = farmId;
    if (zoneId != null) query['zone_id'] = zoneId;
    if (limit != null) query['limit'] = limit.toString();

    final cacheKey = '$interventionsCachePrefix${farmId ?? "all"}_${zoneId ?? "all"}';

    try {
      final response = await _apiClient.get(
        '/api/analytics/interventions',
        queryParams: query.isNotEmpty ? query : null,
      );

      _isLastFetchOffline = false;
      if (response != null && response['data'] != null) {
        final data = AnalyticsInterventionsModel.fromJson(response['data'] as Map<String, dynamic>);
        await _offlineStore.cacheData(cacheKey, response['data']);
        return data;
      }
      throw ApiException(500, 'Invalid interventions response structure');
    } on NetworkUnavailableException {
      _isLastFetchOffline = true;
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is Map<String, dynamic>) {
        return AnalyticsInterventionsModel.fromJson(cached);
      }
      rethrow;
    }
  }
}
