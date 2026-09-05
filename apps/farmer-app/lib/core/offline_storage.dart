/// Offline Cache & 5-State Action Queue for Farmer Mobile App
/// Aligned with PRAHAR Engineering Specification v1.0 Section 14 (P0) & Phase 3.

enum SyncStatus { pending, syncing, synced, failed, conflict }

class OfflineSyncAction {
  final String eventId;
  final String idempotencyKey;
  final String actionType;
  final Map<String, dynamic> payload;
  final String createdAt;
  SyncStatus status;
  int retryCount;
  String? lastError;
  String? syncedAt;

  OfflineSyncAction({
    required this.eventId,
    required this.idempotencyKey,
    required this.actionType,
    required this.payload,
    required this.createdAt,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
    this.lastError,
    this.syncedAt,
  });

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'idempotency_key': idempotencyKey,
        'action_type': actionType,
        'payload': payload,
        'created_at': createdAt,
        'status': status.name.toUpperCase(),
        'retry_count': retryCount,
        'last_error': lastError,
        'synced_at': syncedAt,
      };
}

class OfflineStorageService {
  final Map<String, dynamic> _memoryCache = {};
  final List<OfflineSyncAction> _queuedActions = [];
  String _languagePreference = 'hi'; // Default Hindi for rural farmers
  bool _isOnline = true;

  // Language Preference
  String get languagePreference => _languagePreference;
  set languagePreference(String lang) {
    _languagePreference = lang;
  }

  // Connectivity state
  bool get isOnline => _isOnline;
  set isOnline(bool online) {
    _isOnline = online;
  }

  // Zone status caching
  void cacheZoneStatus(String zoneId, Map<String, dynamic> statusData) {
    _memoryCache['zone_$zoneId'] = statusData;
  }

  Map<String, dynamic>? getCachedZoneStatus(String zoneId) {
    return _memoryCache['zone_$zoneId'] as Map<String, dynamic>?;
  }

  // Enqueue action into 5-state sync queue
  OfflineSyncAction queueAction(String actionType, Map<String, dynamic> payload) {
    final now = DateTime.now();
    final action = OfflineSyncAction(
      eventId: 'evt_${now.millisecondsSinceEpoch}',
      idempotencyKey: 'idemp_${actionType.toLowerCase()}_${now.millisecondsSinceEpoch}_${payload['zone_id'] ?? 'field'}',
      actionType: actionType,
      payload: payload,
      createdAt: now.toIso8601String(),
      status: SyncStatus.pending,
    );
    _queuedActions.add(action);
    return action;
  }

  List<OfflineSyncAction> getPendingActions() {
    return _queuedActions.where((a) => a.status == SyncStatus.pending || a.status == SyncStatus.failed).toList();
  }

  List<OfflineSyncAction> getAllActions() {
    return List.unmodifiable(_queuedActions);
  }

  int get pendingCount => getPendingActions().length;

  /// Synchronizes pending actions against backend gateway
  Future<int> synchronize({Future<bool> Function(OfflineSyncAction)? remoteSyncHandler}) async {
    if (!_isOnline) return 0;

    final pending = getPendingActions();
    int syncedCount = 0;

    for (final action in pending) {
      action.status = SyncStatus.syncing;
      try {
        bool success = true;
        if (remoteSyncHandler != null) {
          success = await remoteSyncHandler(action);
        }

        if (success) {
          action.status = SyncStatus.synced;
          action.syncedAt = DateTime.now().toIso8601String();
          syncedCount++;
        } else {
          action.retryCount++;
          action.status = action.retryCount >= 3 ? SyncStatus.failed : SyncStatus.pending;
          action.lastError = 'Remote sync failed';
        }
      } catch (e) {
        action.retryCount++;
        action.status = action.retryCount >= 3 ? SyncStatus.failed : SyncStatus.pending;
        action.lastError = e.toString();
      }
    }

    return syncedCount;
  }

  void clearPendingActions() {
    _queuedActions.clear();
  }
}
