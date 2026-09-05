import 'dart:convert';
import 'dart:io';
import '../offline_storage.dart';

/// Storage abstraction for offline action queue and domain caching.
/// Aligned with Mandatory Amendment 2:
/// - OfflineStore must be replaceable.
/// - Prefer structured persistent storage for offline queue/cache.
abstract class IOfflineStore {
  Future<void> saveAction(OfflineSyncAction action);
  Future<void> updateAction(OfflineSyncAction action);
  Future<List<OfflineSyncAction>> getPendingActions();
  Future<List<OfflineSyncAction>> getAllActions();
  Future<void> clear();

  Future<void> cacheData(String key, dynamic data);
  Future<dynamic> getCachedData(String key);
}

/// In-memory implementation for fast tests and transient storage
class InMemoryOfflineStore implements IOfflineStore {
  final List<OfflineSyncAction> _actions = [];
  final Map<String, dynamic> _cache = {};

  @override
  Future<void> saveAction(OfflineSyncAction action) async {
    _actions.removeWhere((a) => a.eventId == action.eventId);
    _actions.add(action);
  }

  @override
  Future<void> updateAction(OfflineSyncAction action) async {
    final idx = _actions.indexWhere((a) => a.eventId == action.eventId);
    if (idx != -1) {
      _actions[idx] = action;
    } else {
      _actions.add(action);
    }
  }

  @override
  Future<List<OfflineSyncAction>> getPendingActions() async {
    return _actions
        .where((a) => a.status == SyncStatus.pending || a.status == SyncStatus.failed)
        .toList();
  }

  @override
  Future<List<OfflineSyncAction>> getAllActions() async {
    return List.unmodifiable(_actions);
  }

  @override
  Future<void> clear() async {
    _actions.clear();
    _cache.clear();
  }

  @override
  Future<void> cacheData(String key, dynamic data) async {
    _cache[key] = data;
  }

  @override
  Future<dynamic> getCachedData(String key) async {
    return _cache[key];
  }
}

/// Structured persistent storage implementation for mobile disk / platform storage
class StructuredFileOfflineStore implements IOfflineStore {
  final String queueFilePath;
  final String cacheFilePath;

  final Map<String, dynamic> _memoryCache = {};
  final List<OfflineSyncAction> _actions = [];
  bool _initialized = false;

  StructuredFileOfflineStore({
    this.queueFilePath = '.prahar_farmer_offline_queue.json',
    this.cacheFilePath = '.prahar_farmer_offline_cache.json',
  });

  Future<void> _ensureLoaded() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final queueFile = File(queueFilePath);
      if (queueFile.existsSync()) {
        final content = queueFile.readAsStringSync();
        if (content.trim().isNotEmpty) {
          final list = jsonDecode(content) as List<dynamic>;
          for (final item in list) {
            final map = item as Map<String, dynamic>;
            final statusStr = (map['status'] as String? ?? 'PENDING').toLowerCase();
            SyncStatus status = SyncStatus.pending;
            if (statusStr == 'syncing') status = SyncStatus.syncing;
            if (statusStr == 'synced') status = SyncStatus.synced;
            if (statusStr == 'failed') status = SyncStatus.failed;
            if (statusStr == 'conflict') status = SyncStatus.conflict;

            _actions.add(OfflineSyncAction(
              eventId: map['event_id'] as String,
              idempotencyKey: map['idempotency_key'] as String,
              actionType: map['action_type'] as String,
              payload: Map<String, dynamic>.from(map['payload'] as Map),
              createdAt: map['created_at'] as String,
              status: status,
              retryCount: (map['retry_count'] as int?) ?? 0,
              lastError: map['last_error'] as String?,
              syncedAt: map['synced_at'] as String?,
            ));
          }
        }
      }

      final cacheFile = File(cacheFilePath);
      if (cacheFile.existsSync()) {
        final content = cacheFile.readAsStringSync();
        if (content.trim().isNotEmpty) {
          final cacheJson = jsonDecode(content) as Map<String, dynamic>;
          _memoryCache.addAll(cacheJson);
        }
      }
    } catch (_) {
      // Graceful degraded mode
    }
  }

  Future<void> _persistQueue() async {
    try {
      final file = File(queueFilePath);
      final jsonList = _actions.map((a) => a.toJson()).toList();
      file.writeAsStringSync(jsonEncode(jsonList), flush: true);
    } catch (_) {}
  }

  Future<void> _persistCache() async {
    try {
      final file = File(cacheFilePath);
      file.writeAsStringSync(jsonEncode(_memoryCache), flush: true);
    } catch (_) {}
  }

  @override
  Future<void> saveAction(OfflineSyncAction action) async {
    await _ensureLoaded();
    _actions.removeWhere((a) => a.eventId == action.eventId);
    _actions.add(action);
    await _persistQueue();
  }

  @override
  Future<void> updateAction(OfflineSyncAction action) async {
    await _ensureLoaded();
    final idx = _actions.indexWhere((a) => a.eventId == action.eventId);
    if (idx != -1) {
      _actions[idx] = action;
    } else {
      _actions.add(action);
    }
    await _persistQueue();
  }

  @override
  Future<List<OfflineSyncAction>> getPendingActions() async {
    await _ensureLoaded();
    return _actions
        .where((a) => a.status == SyncStatus.pending || a.status == SyncStatus.failed)
        .toList();
  }

  @override
  Future<List<OfflineSyncAction>> getAllActions() async {
    await _ensureLoaded();
    return List.unmodifiable(_actions);
  }

  @override
  Future<void> clear() async {
    _actions.clear();
    _memoryCache.clear();
    await _persistQueue();
    await _persistCache();
  }

  @override
  Future<void> cacheData(String key, dynamic data) async {
    await _ensureLoaded();
    _memoryCache[key] = data;
    await _persistCache();
  }

  @override
  Future<dynamic> getCachedData(String key) async {
    await _ensureLoaded();
    return _memoryCache[key];
  }
}
