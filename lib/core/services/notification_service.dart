import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum NotificationType { ride, promo, system, payment }

extension NotificationTypeX on NotificationType {
  String toDbString() {
    switch (this) {
      case NotificationType.ride:
        return 'ride';
      case NotificationType.promo:
        return 'promo';
      case NotificationType.payment:
        return 'payment';
      case NotificationType.system:
        return 'system';
    }
  }

  static NotificationType fromDbString(String val) {
    switch (val) {
      case 'ride':
        return NotificationType.ride;
      case 'promo':
        return NotificationType.promo;
      case 'payment':
        return NotificationType.payment;
      case 'system':
      default:
        return NotificationType.system;
    }
  }
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

  factory TRYPNotification.fromJson(Map<String, dynamic> json) {
    return TRYPNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      timestamp: DateTime.parse(json['created_at'] as String),
      type: NotificationTypeX.fromDbString(json['type'] as String? ?? 'system'),
      isRead: json['is_read'] as bool? ?? false,
      routePath: json['route_path'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

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

/// Riverpod Notifier backed by Supabase — replaces the in-memory mock list.
///
/// Lifecycle:
///  • On build: fetches the 50 most recent notifications for the current user.
///  • Subscribes to a realtime channel so new rows inserted server-side (e.g.
///    from Edge Functions or other clients) appear instantly without polling.
///  • Local actions (addNotification, markAsRead, etc.) write to Supabase and
///    let the realtime channel drive the state update.
class NotificationNotifier extends AsyncNotifier<List<TRYPNotification>> {
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _channel;

  @override
  Future<List<TRYPNotification>> build() async {
    // Unsubscribe from any previous channel when rebuilt.
    await _channel?.unsubscribe();

    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    // Initial fetch: 50 most recent.
    final rows = await _supabase
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    final initial = (rows as List)
        .map((r) => TRYPNotification.fromJson(r as Map<String, dynamic>))
        .toList();

    // Subscribe to realtime so new server-side inserts appear immediately.
    _channel = _supabase
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // newRecord is non-nullable in Supabase SDK; empty map means N/A.
            if (payload.newRecord.isEmpty) return;
            try {
              final notif = TRYPNotification.fromJson(payload.newRecord);
              // Prepend only if not already in list (idempotent).
              final current = state.asData?.value ?? [];
              if (current.any((n) => n.id == notif.id)) return;
              state = AsyncData([notif, ...current]);
            } catch (e) {
              debugPrint('NotificationNotifier: realtime parse error: $e');
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isEmpty) return;
            try {
              final notif = TRYPNotification.fromJson(payload.newRecord);
              final current = state.asData?.value ?? [];
              state = AsyncData(
                current.map((n) => n.id == notif.id ? notif : n).toList(),
              );
            } catch (e) {
              debugPrint(
                'NotificationNotifier: realtime update parse error: $e',
              );
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            // oldRecord is non-nullable; empty map means ID not available.
            final deletedId = payload.oldRecord['id'] as String?;
            if (deletedId == null) return;
            final current = state.asData?.value ?? [];
            state = AsyncData(current.where((n) => n.id != deletedId).toList());
          },
        )
        .subscribe();

    // Auto-unsubscribe when the notifier is disposed.
    ref.onDispose(() => _channel?.unsubscribe());

    return initial;
  }

  // ── Write helpers ─────────────────────────────────────────────────────────

  /// Insert a new notification into Supabase. The realtime subscription will
  /// pick it up and update state — no need to manually modify state here.
  Future<void> addNotification({
    required String title,
    required String body,
    required NotificationType type,
    String? routePath,
    Map<String, dynamic>? payload,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('NotificationNotifier.addNotification: no authenticated user');
      return;
    }
    try {
      await _supabase.rpc(
        'send_notification',
        params: {
          'target_uid': userId,
          'p_title': title,
          'p_body': body,
          'p_type': type.toDbString(),
          'p_route_path': routePath,
          'p_payload': payload,
        },
      );
    } catch (e) {
      debugPrint('NotificationNotifier.addNotification error: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id);
    } catch (e) {
      debugPrint('NotificationNotifier.markAsRead error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('NotificationNotifier.markAllAsRead error: $e');
    }
  }

  Future<void> removeNotification(String id) async {
    try {
      await _supabase.from('notifications').delete().eq('id', id);
    } catch (e) {
      debugPrint('NotificationNotifier.removeNotification error: $e');
    }
  }

  Future<void> clearAll() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('notifications').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('NotificationNotifier.clearAll error: $e');
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationNotifier, List<TRYPNotification>>(
      NotificationNotifier.new,
    );

final unreadNotificationCountProvider = Provider<int>((ref) {
  final asyncList = ref.watch(notificationsProvider);
  return asyncList.asData?.value.where((n) => !n.isRead).length ?? 0;
});
