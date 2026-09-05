/// Offline Cache & Action Queue Abstraction for Farmer Mobile App
/// Aligned with PRAHAR Engineering Specification v1.0 Section 14 (P0).

class OfflineStorageService {
  final Map<String, dynamic> _memoryCache = {};
  final List<Map<String, dynamic>> _queuedActions = [];

  void cacheZoneStatus(String zoneId, Map<String, dynamic> statusData) {
    _memoryCache['zone_$zoneId'] = statusData;
  }

  Map<String, dynamic>? getCachedZoneStatus(String zoneId) {
    return _memoryCache['zone_$zoneId'] as Map<String, dynamic>?;
  }

  void queueAction(String actionType, Map<String, dynamic> payload) {
    _queuedActions.add({
      'action_id': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'action_type': actionType,
      'payload': payload,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  List<Map<String, dynamic>> getPendingActions() {
    return List.unmodifiable(_queuedActions);
  }

  void clearPendingActions() {
    _queuedActions.clear();
  }
}
