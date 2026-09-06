import '../../core/api_client.dart';
import '../../core/storage/offline_store.dart';
import '../../domain/models.dart';

/// Repository managing the Farmer Opportunity & Scheme Center.
/// Aligned with Phase 6B-4 Specifications & Mandatory Corrections:
/// 1. Supabase is authoritative.
/// 2. Only Flutter may cache catalogue READS for genuine NetworkUnavailableException.
/// 3. Eligibility checks and tracking writes strictly require live backend connectivity.
/// 4. ApiExceptions (400, 401, 403, 404, 422, 500) strictly rethrow; NEVER fallback to cache or demo data.
/// 5. Client never trusts or supplies arbitrary user_id; derived from JWT.
class OpportunityRepository {
  final ApiClient _apiClient;
  final IOfflineStore _offlineStore;

  static const String catalogueCachePrefix = 'opportunity_catalogue_';
  static const String guideCachePrefix = 'opportunity_guide_';

  OpportunityRepository({
    required ApiClient apiClient,
    required IOfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  bool _isLastFetchOffline = false;
  bool get isLastFetchOffline => _isLastFetchOffline;

  /// Fetches verified opportunities catalogue.
  /// Allowed to read local offline cache ONLY on genuine NetworkUnavailableException.
  /// ApiExceptions strictly rethrow.
  Future<List<OpportunityModel>> getOpportunities({
    OpportunityType? type,
    String? category,
  }) async {
    final query = <String, String>{};
    if (type != null) query['type'] = type.toDbString();
    if (category != null && category.isNotEmpty) query['category'] = category;

    final cacheKey = '$catalogueCachePrefix${type?.toDbString() ?? "all"}_${category ?? "all"}';

    try {
      final response = await _apiClient.get(
        '/api/opportunities',
        queryParams: query.isNotEmpty ? query : null,
      );

      _isLastFetchOffline = false;
      final rawList = (response?['data'] ?? response?['schemes']) as List?;
      if (rawList != null) {
        final list = rawList
            .map((e) => OpportunityModel.fromJson(e as Map<String, dynamic>))
            .toList();
        await _offlineStore.cacheData(cacheKey, rawList);
        return list;
      }
      throw ApiException(500, 'Invalid opportunities response structure');
    } on NetworkUnavailableException {
      _isLastFetchOffline = true;
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List) {
        return cached
            .map((e) => OpportunityModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  /// Fetches a single opportunity by ID.
  Future<OpportunityModel> getOpportunityById(String id) async {
    final cacheKey = '$catalogueCachePrefix$id';
    try {
      final response = await _apiClient.get('/api/opportunities/$id');
      _isLastFetchOffline = false;
      final data = response?['data'] ?? response?['scheme'];
      if (data is Map<String, dynamic>) {
        final model = OpportunityModel.fromJson(data);
        await _offlineStore.cacheData(cacheKey, data);
        return model;
      }
      throw ApiException(404, 'Opportunity not found');
    } on NetworkUnavailableException {
      _isLastFetchOffline = true;
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is Map<String, dynamic>) {
        return OpportunityModel.fromJson(cached);
      }
      // Try searching inside full cached catalogue
      final fullCached = await _offlineStore.getCachedData('${catalogueCachePrefix}all_all');
      if (fullCached is List) {
        final match = fullCached.firstWhere(
          (e) => (e['id'] == id || e['scheme_id'] == id),
          orElse: () => null,
        );
        if (match is Map<String, dynamic>) {
          return OpportunityModel.fromJson(match);
        }
      }
      rethrow;
    }
  }

  /// Fetches application guide (document checklist, step-by-step instructions).
  Future<ApplicationGuideModel> getApplicationGuide(String opportunityId) async {
    final cacheKey = '$guideCachePrefix$opportunityId';
    try {
      final response = await _apiClient.get('/api/opportunities/$opportunityId/application-guide');
      _isLastFetchOffline = false;
      final data = response?['data'];
      if (data is Map<String, dynamic>) {
        final guide = ApplicationGuideModel.fromJson(data);
        await _offlineStore.cacheData(cacheKey, data);
        return guide;
      }
      throw ApiException(404, 'Application guide not found');
    } on NetworkUnavailableException {
      _isLastFetchOffline = true;
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is Map<String, dynamic>) {
        return ApplicationGuideModel.fromJson(cached);
      }
      rethrow;
    }
  }

  /// Evaluates deterministic eligibility against farmer profile and landholding.
  /// Strictly requires live backend connectivity; NEVER cached or mocked.
  Future<EligibilityEvaluationModel> checkEligibility({
    required String opportunityId,
    String? farmId,
    double? landAcres,
    String? cropType,
    String? state,
  }) async {
    final body = <String, dynamic>{
      'opportunity_id': opportunityId,
    };
    if (farmId != null && farmId.isNotEmpty) body['farm_id'] = farmId;
    if (landAcres != null) body['land_acres'] = landAcres;
    if (cropType != null && cropType.isNotEmpty) body['crop_type'] = cropType;
    if (state != null && state.isNotEmpty) body['state'] = state;

    final response = await _apiClient.post(
      '/api/opportunities/check-eligibility',
      body: body,
    );

    final data = response?['data'] ?? response?['evaluation'];
    if (data is Map<String, dynamic>) {
      return EligibilityEvaluationModel.fromJson(data);
    }
    throw ApiException(500, 'Invalid eligibility response structure');
  }

  /// Fetches authenticated user's application tracking records.
  /// Authoritative backend connectivity required.
  Future<List<OpportunityTrackingModel>> getTracking() async {
    final response = await _apiClient.get('/api/opportunities/tracking');
    final data = response?['data'] as List?;
    if (data != null) {
      return data
          .map((e) => OpportunityTrackingModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw ApiException(500, 'Invalid tracking response structure');
  }

  /// Creates or updates a tracking record.
  /// Live connectivity strictly required; server derives user_id from verified JWT.
  Future<OpportunityTrackingModel> updateTracking({
    required String opportunityId,
    required ApplicationTrackingStatus status,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'opportunity_id': opportunityId,
      'status': status.toDbString(),
      if (notes != null) 'notes': notes,
    };

    final response = await _apiClient.post(
      '/api/opportunities/tracking',
      body: body,
    );

    final data = response?['data'];
    if (data is Map<String, dynamic>) {
      return OpportunityTrackingModel.fromJson(data);
    }
    throw ApiException(500, 'Invalid tracking update response structure');
  }
}
