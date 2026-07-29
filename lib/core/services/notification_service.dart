import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationType {
  ride,
  promo,
  system,
  payment,
}

class TRYPNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? routePath;
  final Map<String, dynamic>? payload;

  const TRYPNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.routePath,
    this.payload,
  });

  TRYPNotification copyWith({
    String? id,
    String? title,
    String? body,
    DateTime? timestamp,
    NotificationType? type,
    bool? isRead,
    String? routePath,
    Map<String, dynamic>? payload,
  }) {
    return TRYPNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      routePath: routePath ?? this.routePath,
      payload: payload ?? this.payload,
    );
  }
}

class NotificationNotifier extends Notifier<List<TRYPNotification>> {
  @override
  List<TRYPNotification> build() {
    return _initialMockNotifications;
  }

  static final List<TRYPNotification> _initialMockNotifications = [
    TRYPNotification(
      id: 'notif_1',
      title: 'Driver Arrived at Pickup! 🚘',
      body: 'Your driver in a Toyota Corolla (ND 123-456) has arrived at Sandton City Mall.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      type: NotificationType.ride,
      routePath: '/passenger/ride-tracking',
      isRead: false,
    ),
    TRYPNotification(
      id: 'notif_2',
      title: '20% Off Weekend Rides 🎉',
      body: 'Use promo code TRYPWEEKEND to get 20% off your next 3 rides across Sandton and Rosebank!',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      type: NotificationType.promo,
      isRead: false,
    ),
    TRYPNotification(
      id: 'notif_3',
      title: 'Payment Receipt Available 🧾',
      body: 'Your ride to Rosebank Mall for R82.50 was paid via Paystack Card. Tap to view receipt.',
      timestamp: DateTime.now().subtract(const Duration(hours: 26)),
      type: NotificationType.payment,
      routePath: '/passenger/activity',
      isRead: true,
    ),
    TRYPNotification(
      id: 'notif_4',
      title: 'Driver Document Status Update 🛡️',
      body: 'Your SA PrDP driving license verification is currently under review by our safety team.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: NotificationType.system,
      routePath: '/driver/documents',
      isRead: true,
    ),
  ];

  void addNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? routePath,
  }) {
    final newNotif = TRYPNotification(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      timestamp: DateTime.now(),
      type: type,
      routePath: routePath,
      isRead: false,
    );
    state = [newNotif, ...state];
  }

  void markAsRead(String id) {
    state = state.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
  }

  void markAllAsRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void removeNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void clearAll() {
    state = [];
  }
}

final notificationsProvider =
    NotifierProvider<NotificationNotifier, List<TRYPNotification>>(NotificationNotifier.new);

final unreadNotificationCountProvider = Provider<int>((ref) {
  final list = ref.watch(notificationsProvider);
  return list.where((n) => !n.isRead).length;
});
