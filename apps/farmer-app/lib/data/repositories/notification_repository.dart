import '../../core/api_client.dart';
import '../../core/storage/offline_store.dart';
import '../../domain/models.dart';

/// Repository managing In-App Notifications for the Farmer App.
/// Aligned with Phase 6B-1 Specifications:
/// - Supabase authoritative whenever online
/// - Strict tenant isolation (server-authenticated Bearer JWT)
/// - Network failures fall back to cached data
/// - ApiException (400/401/403/422/500) strictly rethrows without fallback
class NotificationRepository {
  final ApiClient _apiClient;
  final IOfflineStore _offlineStore;

  static const String cacheKey = 'notifications_cache';

  NotificationRepository({
    required ApiClient apiClient,
    required IOfflineStore offlineStore,
  })  : _apiClient = apiClient,
        _offlineStore = offlineStore;

  bool _isLastFetchOffline = false;
  bool get isLastFetchOffline => _isLastFetchOffline;

  Future<void> clearCache() async {
    await _offlineStore.cacheData(cacheKey, []);
  }

  Future<List<NotificationModel>> getNotifications({
    bool? isRead,
    int? limit,
    bool forceRefresh = false,
  }) async {
    final query = <String, String>{};
    if (isRead != null) query['is_read'] = isRead.toString();
    if (limit != null) query['limit'] = limit.toString();

    try {
      final response = await _apiClient.get(
        '/api/notifications',
        queryParams: query.isNotEmpty ? query : null,
      );

      _isLastFetchOffline = false;
      if (response != null && response['data'] is List) {
        final list = (response['data'] as List)
            .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
            .toList();

        await _offlineStore.cacheData(cacheKey, response['data']);
        return list;
      }
      return [];
    } on NetworkUnavailableException {
      // Offline fallback: Use cached data if available
      _isLastFetchOffline = true;
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List && cached.isNotEmpty) {
        final list = cached
            .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
            .toList();
        if (isRead != null) {
          return list.where((n) => n.isRead == isRead).toList();
        }
        return list;
      }
      rethrow;
    }
    // ApiException (400, 401, 403, 422, 500) propagates directly to caller
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.get('/api/notifications/unread-count');
      if (response != null && response['count'] is num) {
        return (response['count'] as num).toInt();
      }
      return 0;
    } on NetworkUnavailableException {
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List && cached.isNotEmpty) {
        return cached
            .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
            .where((n) => !n.isRead)
            .length;
      }
      return 0;
    }
  }

  Future<NotificationModel?> markAsRead(String notificationId) async {
    try {
      final response = await _apiClient.patch('/api/notifications/$notificationId/read');
      if (response != null && response['data'] is Map<String, dynamic>) {
        final updated = NotificationModel.fromJson(response['data'] as Map<String, dynamic>);

        // Update local cache
        final cached = await _offlineStore.getCachedData(cacheKey);
        if (cached is List) {
          final updatedList = cached.map((item) {
            if (item is Map && (item['id'] == notificationId || item['notification_id'] == notificationId)) {
              return {...item, 'is_read': true, 'read_at': DateTime.now().toIso8601String()};
            }
            return item;
          }).toList();
          await _offlineStore.cacheData(cacheKey, updatedList);
        }

        return updated;
      }
      return null;
    } on NetworkUnavailableException {
      // Offline: mark read in local cache if present
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List) {
        NotificationModel? localMatch;
        final updatedList = cached.map((item) {
          if (item is Map && (item['id'] == notificationId || item['notification_id'] == notificationId)) {
            final modified = {...item, 'is_read': true, 'read_at': DateTime.now().toIso8601String()};
            localMatch = NotificationModel.fromJson(Map<String, dynamic>.from(modified));
            return modified;
          }
          return item;
        }).toList();
        await _offlineStore.cacheData(cacheKey, updatedList);
        return localMatch;
      }
      rethrow;
    }
  }

  Future<int> markAllAsRead() async {
    try {
      final response = await _apiClient.post('/api/notifications/read-all');
      final count = (response != null && response['count'] is num)
          ? (response['count'] as num).toInt()
          : 0;

      // Update local cache
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List) {
        final updatedList = cached.map((item) {
          if (item is Map) {
            return {...item, 'is_read': true, 'read_at': DateTime.now().toIso8601String()};
          }
          return item;
        }).toList();
        await _offlineStore.cacheData(cacheKey, updatedList);
      }

      return count;
    } on NetworkUnavailableException {
      final cached = await _offlineStore.getCachedData(cacheKey);
      if (cached is List) {
        int localCount = 0;
        final updatedList = cached.map((item) {
          if (item is Map && item['is_read'] == false) {
            localCount++;
            return {...item, 'is_read': true, 'read_at': DateTime.now().toIso8601String()};
          }
          return item;
        }).toList();
        await _offlineStore.cacheData(cacheKey, updatedList);
        return localCount;
      }
      rethrow;
    }
  }
}
