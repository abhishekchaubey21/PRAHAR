import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../data/repositories/notification_repository.dart';

class NotificationCenterScreen extends StatefulWidget {
  final NotificationRepository notificationRepository;
  final bool isHindi;

  const NotificationCenterScreen({
    super.key,
    required this.notificationRepository,
    this.isHindi = false,
  });

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  bool _isLoading = false;
  bool _isOffline = false;
  String? _errorMessage;
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isOffline = false;
    });

    try {
      final items = await widget.notificationRepository.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = items;
          _isOffline = widget.notificationRepository.isLastFetchOffline;
          _isLoading = false;
        });
      }
    } on NetworkUnavailableException {
      if (mounted) {
        setState(() {
          _notifications = [];
          _isOffline = true;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'API Error (${e.statusCode}): ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unexpected error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notif) async {
    if (notif.isRead) return;

    setState(() {
      notif.isRead = true;
    });

    try {
      await widget.notificationRepository.markAsRead(notif.notificationId.isNotEmpty ? notif.notificationId : notif.id);
    } catch (_) {
      // Keep optimistic update or retry quietly
    }
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });

    try {
      await widget.notificationRepository.markAllAsRead();
    } catch (_) {}
  }

  void _showNotificationDetails(NotificationModel notif) {
    _markAsRead(notif);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('notification_details_dialog'),
        backgroundColor: const Color(0xFF131F19),
        title: Row(
          children: [
            Icon(
              _getIconForType(notif.type),
              color: _getColorForSeverity(notif.severity),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.isHindi ? (notif.titleHi ?? notif.title) : notif.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isHindi ? (notif.messageHi ?? notif.message) : notif.message,
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 14),
            const Divider(color: PraharTheme.borderGreen),
            if (notif.zoneId != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.grid_on, size: 14, color: PraharTheme.alertSky),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.isHindi ? "क्षेत्र" : "Zone"}: ${notif.zoneId}',
                    style: const TextStyle(fontSize: 12, color: PraharTheme.alertSky, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            if (notif.alertId != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber, size: 14, color: PraharTheme.alertAmber),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${widget.isHindi ? "चेतावनी आईडी" : "Alert ID"}: ${notif.alertId}',
                      style: const TextStyle(fontSize: 12, color: PraharTheme.alertAmber),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (notif.actionId != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: PraharTheme.primaryGreen),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${widget.isHindi ? "कार्रवाई आईडी" : "Action ID"}: ${notif.actionId}',
                      style: const TextStyle(fontSize: 12, color: PraharTheme.primaryGreen),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('close_notification_dialog_button'),
            onPressed: () => Navigator.pop(ctx),
            child: Text(widget.isHindi ? 'बंद करें' : 'Close'),
          ),
        ],
      ),
    );
  }

  Color _getColorForSeverity(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
        return PraharTheme.alertRose;
      case 'MEDIUM':
        return PraharTheme.alertAmber;
      case 'LOW':
        return PraharTheme.primaryGreen;
      case 'INFO':
      default:
        return PraharTheme.alertSky;
    }
  }

  IconData _getIconForType(String type) {
    switch (type.toUpperCase()) {
      case 'ALERT_CREATED':
      case 'RISK_DETECTED':
        return Icons.warning_rounded;
      case 'ACTION_RECOMMENDED':
        return Icons.lightbulb_outline;
      case 'ACTION_APPROVED':
        return Icons.verified;
      case 'ACTION_EXECUTED':
        return Icons.smart_toy;
      case 'VERIFICATION_COMPLETED':
        return Icons.task_alt;
      case 'VERIFICATION_FAILED':
        return Icons.error_outline;
      case 'SYSTEM':
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.isHindi ? 'सूचना केंद्र' : 'Notification Center'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                key: const Key('unread_count_badge_chip'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: PraharTheme.alertRose,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              key: const Key('mark_all_read_button'),
              onPressed: unreadCount > 0 ? _markAllAsRead : null,
              child: Text(
                widget.isHindi ? 'सभी पढ़ें' : 'Mark All Read',
                style: TextStyle(
                  color: unreadCount > 0 ? PraharTheme.primaryGreen : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: PraharTheme.primaryGreen,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        key: Key('notifications_loading_spinner'),
        child: CircularProgressIndicator(color: PraharTheme.primaryGreen),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: PraharTheme.alertRose, size: 48),
              const SizedBox(height: 12),
              Text(
                key: const Key('notifications_error_message'),
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: PraharTheme.alertRose, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('notifications_retry_button'),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(widget.isHindi ? 'पुनः प्रयास करें' : 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PraharTheme.primaryGreen,
                  foregroundColor: Colors.black,
                ),
                onPressed: _loadNotifications,
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Offline Banner
        if (_isOffline)
          Container(
            key: const Key('notifications_offline_banner'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A1C14),
              border: Border.all(color: PraharTheme.alertAmber),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_off, color: PraharTheme.alertAmber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _notifications.isNotEmpty
                        ? (widget.isHindi
                            ? 'ऑफ़लाइन मोड: संग्रहीत सूचनाएं दिखाई जा रही हैं'
                            : 'Offline Mode: Showing cached notifications')
                        : (widget.isHindi
                            ? 'ऑफ़लाइन: कोई संग्रहीत सूचनाएं उपलब्ध नहीं हैं'
                            : 'Offline: No cached notifications available'),
                    style: const TextStyle(color: PraharTheme.alertAmber, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

        if (_notifications.isEmpty)
          Container(
            key: const Key('notifications_empty_card'),
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: PraharTheme.cardBg,
              border: Border.all(color: PraharTheme.borderGreen),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 48, color: Colors.grey[600]),
                const SizedBox(height: 12),
                Text(
                  widget.isHindi ? 'कोई सूचना नहीं' : 'No Notifications',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isHindi
                      ? 'कृषि जोखिम, कार्रवाई और सत्यापन सूचनाएं यहाँ दिखाई देंगी।'
                      : 'Agricultural hazards, recommendations, and action verifications will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          )
        else
          ..._notifications.map((notif) => _buildNotificationCard(notif)),
      ],
    );
  }

  Widget _buildNotificationCard(NotificationModel notif) {
    final sevColor = _getColorForSeverity(notif.severity);
    final isUnread = !notif.isRead;

    return Container(
      key: Key('notification_item_${notif.notificationId.isNotEmpty ? notif.notificationId : notif.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isUnread ? const Color(0xFF14241E) : PraharTheme.cardBg.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUnread ? PraharTheme.primaryGreen.withOpacity(0.7) : PraharTheme.borderGreen,
          width: isUnread ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: () => _showNotificationDetails(notif),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sevColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getIconForType(notif.type), color: sevColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.isHindi ? (notif.titleHi ?? notif.title) : notif.title,
                            style: TextStyle(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                              color: isUnread ? Colors.white : Colors.grey[300],
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: PraharTheme.primaryGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.isHindi ? (notif.messageHi ?? notif.message) : notif.message,
                      style: TextStyle(
                        fontSize: 11,
                        color: isUnread ? Colors.grey[300] : Colors.grey[500],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sevColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: sevColor.withOpacity(0.5)),
                          ),
                          child: Text(
                            notif.severity,
                            style: TextStyle(color: sevColor, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (notif.zoneId != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            notif.zoneId!,
                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          _formatTimestamp(notif.createdAt),
                          style: TextStyle(color: Colors.grey[500], fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return widget.isHindi ? 'अभी' : 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}${widget.isHindi ? "मि पूर्व" : "m ago"}';
    if (diff.inHours < 24) return '${diff.inHours}${widget.isHindi ? "घंटे पूर्व" : "h ago"}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
