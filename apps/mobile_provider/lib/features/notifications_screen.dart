import 'package:flutter/material.dart';

import '../core/theme/thali_partner_theme.dart';
import '../core/widgets/partner_widgets.dart';
import '../models/models.dart';
import '../services/provider_api_service.dart';

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
          _notifications = (res['notifications'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
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
      backgroundColor: ThaliColors.scaffold,
      appBar: AppBar(
        title: const Text('Partner Notifications'),
        leading: widget.onBack != null ? IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 26), onPressed: widget.onBack) : null,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark read', style: TextStyle(color: ThaliColors.primary, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: ThaliColors.primary,
        child: _loading
            ? const PartnerSkeletonList(itemCount: 4, cardHeight: 82)
            : _notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 48),
                      CardSurface(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded, size: 44, color: ThaliColors.primary),
                            SizedBox(height: 12),
                            Text('No Notifications Yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ThaliColors.ink)),
                            SizedBox(height: 6),
                            Text(
                              'New subscriptions, counter cash approvals, meal skips, and QR check-ins appear here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: ThaliColors.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final isUnread = n['read'] != true;
                      final type = n['type']?.toString() ?? 'info';
                      final isPending = type == 'pending_payment' || type == 'plan_upgrade';

                      return CardSurface(
                        onTap: () {
                          if (isPending && widget.onOpenPending != null) widget.onOpenPending!();
                        },
                        color: isUnread ? ThaliColors.primarySoft : ThaliColors.card,
                        borderColor: isUnread ? ThaliColors.primary : ThaliColors.stroke,
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isPending ? ThaliColors.primarySoft : ThaliColors.subtle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                type == 'redemption'
                                    ? Icons.restaurant_rounded
                                    : (isPending ? Icons.payments_outlined : Icons.notifications_none_rounded),
                                color: isPending ? ThaliColors.primary : ThaliColors.ink,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    n['title']?.toString() ?? 'Notification',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                      color: ThaliColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    n['message']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 12.5, color: ThaliColors.body, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
