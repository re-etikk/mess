import 'package:flutter/foundation.dart';

enum NotificationType {
  redemption,
  subscription,
  menu,
  upgrade,
  general,
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.type = NotificationType.general,
    this.isRead = false,
    this.actionRoute,
    this.metadata,
  });

  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? actionRoute;
  final Map<String, dynamic>? metadata;

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationType? type,
    bool? isRead,
    String? actionRoute,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute ?? this.actionRoute,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'is_read': isRead,
    'action_route': actionRoute,
    'metadata': metadata,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    NotificationType nType = NotificationType.general;
    try {
      final t = json['type']?.toString();
      if (t != null) {
        nType = NotificationType.values.firstWhere((e) => e.name == t, orElse: () => NotificationType.general);
      }
    } catch (_) {}

    DateTime time;
    try {
      time = DateTime.parse(json['timestamp']?.toString() ?? '');
    } catch (_) {
      time = DateTime.now();
    }

    return AppNotification(
      id: json['id']?.toString() ?? 'notif-${DateTime.now().microsecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      timestamp: time,
      type: nType,
      isRead: json['is_read'] == true,
      actionRoute: json['action_route']?.toString(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
