import 'package:flutter/material.dart';
import '../services/provider_api_service.dart';

const Color ink = Color(0xFF182435);
const Color orange = Color(0xFFFF6B1A);
const Color muted = Color(0xFF687382);
const Color card = Color(0xFFFFFFFF);
const Color line = Color(0xFFE9E0D5);
const Color cream = Color(0xFFFBF6EE);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.session, this.onBack, this.onOpenPending});
  final ProviderSession session;
  final VoidCallback? onBack;
  final VoidCallback? onOpenPending;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final res = await ProviderApiService.fetchNotifications(widget.session.providerId);
      if (mounted) {
        setState(() {
          _notifications = (res['notifications'] as List<dynamic>? ?? []).map((e) => e as Map<String, dynamic>).toList();
          _unreadCount = (res['unread_count'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await ProviderApiService.markNotificationsRead(widget.session.providerId);
    if (mounted) {
      setState(() {
        _unreadCount = 0;
        for (final n in _notifications) {
          n['read'] = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        title: const Text('Partner Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack) : null,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: orange, fontWeight: FontWeight.w700)),
            ),
          IconButton(icon: const Icon(Icons.refresh, color: orange), onPressed: _loadNotifications),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: orange))
          : _notifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(color: Color(0xFFFFF0E5), shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_none_rounded, size: 48, color: orange),
                        ),
                        const SizedBox(height: 16),
                        const Text('No Notifications Yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
                        const SizedBox(height: 8),
                        const Text(
                          'You will receive instant alerts here whenever a student purchases a pass, requests an upgrade, or redeems a meal.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: orange,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final n = _notifications[i];
                      final isUnread = n['read'] != true;
                      final type = n['type']?.toString() ?? 'info';
                      final title = n['title']?.toString() ?? 'Notification';
                      final message = n['message']?.toString() ?? '';
                      final isPending = type == 'pending_payment' || type == 'plan_upgrade';

                      return InkWell(
                        onTap: () {
                          if (isPending && widget.onOpenPending != null) {
                            widget.onOpenPending!();
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isUnread ? const Color(0xFFFFF7ED) : card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: isUnread ? const Color(0xFFFDBA74) : line),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                backgroundColor: isPending ? const Color(0xFFFFEDD5) : const Color(0xFFE2E8F0),
                                radius: 18,
                                child: Icon(
                                  type == 'plan_upgrade'
                                      ? Icons.upgrade_rounded
                                      : (type == 'pending_payment' ? Icons.payment_outlined : Icons.notifications_outlined),
                                  color: isPending ? orange : ink,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700, fontSize: 14, color: ink),
                                          ),
                                        ),
                                        if (isUnread)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(color: orange, shape: BoxShape.circle),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message,
                                      style: const TextStyle(fontSize: 12.5, color: muted, height: 1.35),
                                    ),
                                    if (isPending) ...[
                                      const SizedBox(height: 8),
                                      const Row(
                                        children: [
                                          Text('Tap to review and approve', style: TextStyle(color: orange, fontWeight: FontWeight.w700, fontSize: 12)),
                                          SizedBox(width: 4),
                                          Icon(Icons.arrow_forward_ios, size: 10, color: orange),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
