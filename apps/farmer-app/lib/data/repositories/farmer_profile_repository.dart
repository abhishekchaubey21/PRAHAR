/// PRAHAR Farmer App — Farmer Profile & Onboarding Repository
/// Aligned with Phase 7A:
/// Handles saving, fetching, and local persistence of the Farmer Profile, Farm Setup, and Crop Details.

import '../../core/api_client.dart';
import '../../core/storage/offline_store.dart';
import '../../domain/farmer_profile.dart';
import '../providers/demo_farm_dataset.dart';

class FarmerProfileRepository {
  final ApiClient _apiClient;
  final IOfflineStore _offlineStore;

  static const String onboardingStateCacheKey = 'farmer_onboarding_state';
  static const String onboardingCompletedCacheKey = 'farmer_onboarding_completed';

  FarmerProfileRepository({
    required ApiClient apiClient,
    required IOfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  /// Loads current onboarding state from remote gateway or local offline store.
  Future<FarmerOnboardingState> getOnboardingState() async {
    // 1. Try remote fetch if online
    try {
      final response = await _apiClient.get('/api/farmer/profile');
      if (response != null && response['data'] is Map<String, dynamic>) {
        final state = FarmerOnboardingState.fromJson(
            response['data'] as Map<String, dynamic>);
        await _offlineStore.cacheData(
            onboardingStateCacheKey, response['data']);
        await _offlineStore.cacheData(
            onboardingCompletedCacheKey, state.isCompleted);
        return state;
      }
    } on NetworkUnavailableException {
      // Fallback to local offline cache
    } catch (_) {
      // Fallback to local offline cache
    }

    // 2. Read from offline store
    final cached = await _offlineStore.getCachedData(onboardingStateCacheKey);
    if (cached is Map<String, dynamic>) {
      return FarmerOnboardingState.fromJson(cached);
    }

    // 3. Default state if not yet configured
    return const FarmerOnboardingState(
      profile: FarmerProfileModel(
        name: '',
        state: 'Maharashtra',
        district: 'Amravati',
        village: '',
        preferredLanguage: 'en',
      ),
      farm: FarmSetupModel(
        areaAcres: 4.2,
        ownershipType: 'OWNED',
        irrigationStatus: 'PARTIAL',
        waterSource: 'BOREWELL',
        soilType: 'Black Cotton Loam',
      ),
      crops: CropSetupModel(
        mainCrops: ['Soybean', 'Wheat'],
        season: 'KHARIF',
        variety: 'JS 335 / GW 322',
        sowingDate: '2026-06-25',
      ),
      isCompleted: false,
    );
  }

  /// Checks if the farmer has completed the onboarding flow.
  Future<bool> isOnboardingCompleted() async {
    final cachedCompleted =
        await _offlineStore.getCachedData(onboardingCompletedCacheKey);
    if (cachedCompleted is bool) {
      return cachedCompleted;
    }
    final state = await getOnboardingState();
    return state.isCompleted;
  }

  /// Saves or updates the onboarding state and persists it locally and remotely.
  Future<bool> saveOnboardingState(FarmerOnboardingState state) async {
    // 1. Persist in local storage
    await _offlineStore.cacheData(
        onboardingStateCacheKey, state.toJson());
    await _offlineStore.cacheData(
        onboardingCompletedCacheKey, state.isCompleted);
    await _offlineStore.cacheData(
        'user_language_preference', state.profile.preferredLanguage);

    // 2. Best-effort push to remote gateway
    try {
      await _apiClient.post(
        '/api/farmer/profile',
        body: state.toJson(),
      );
      return true;
    } catch (_) {
      // Saved locally in offline queue / cache
      return true;
    }
  }

  /// Quick-fills the canonical demo dataset (Ramesh Patil • 4.2 Acres • Maharashtra).
  Future<FarmerOnboardingState> quickFillCanonicalDemo({
    String preferredLanguage = 'en',
  }) async {
    final canonical = CanonicalDemoDataset.onboardingState;
    final state = FarmerOnboardingState(
      profile: canonical.profile.copyWith(preferredLanguage: preferredLanguage),
      farm: canonical.farm,
      crops: canonical.crops,
      isCompleted: true,
      completedAt: DateTime.now().toIso8601String(),
    );
    await saveOnboardingState(state);
    return state;
  }

  /// Clears onboarding state (on user logout)
  Future<void> clear() async {
    await _offlineStore.cacheData(onboardingStateCacheKey, null);
    await _offlineStore.cacheData(onboardingCompletedCacheKey, null);
  }
}
