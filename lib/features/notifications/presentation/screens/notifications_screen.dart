import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/routes.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/notification_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final asyncNotifications = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    // Resolve the async list; while loading show an empty list.
    final notifications = asyncNotifications.asData?.value ?? [];

    // Apply Filter
    final filteredNotifications = notifications.where((n) {
      if (_selectedFilter == 'Unread') return !n.isRead;
      if (_selectedFilter == 'Rides') return n.type == NotificationType.ride;
      if (_selectedFilter == 'Promos') return n.type == NotificationType.promo;
      if (_selectedFilter == 'System')
        return n.type == NotificationType.system ||
            n.type == NotificationType.payment;
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Text(
              'Notifications',
              style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: TRYPColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount New',
                  style: TRYPTypography.bodySmall.copyWith(
                    color: TRYPColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: TRYPColors.secondary,
              ),
              onSelected: (value) {
                if (value == 'mark_read') {
                  ref.read(notificationsProvider.notifier).markAllAsRead();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All notifications marked as read'),
                    ),
                  );
                } else if (value == 'clear_all') {
                  ref.read(notificationsProvider.notifier).clearAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_read',
                  child: Row(
                    children: [
                      Icon(
                        Icons.done_all_rounded,
                        size: 18,
                        color: TRYPColors.secondary,
                      ),
                      SizedBox(width: 10),
                      Text('Mark all as read'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Colors.red,
                      ),
                      SizedBox(width: 10),
                      Text('Clear all', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Chips Bar
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: ['All', 'Unread', 'Rides', 'Promos', 'System'].map((
                  filter,
                ) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(filter),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? TRYPColors.secondary
                            : TRYPColors.grey,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      selectedColor: TRYPColors.primary,
                      backgroundColor: TRYPColors.lightGrey,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (val) {
                        setState(() => _selectedFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // Loading / error states
            if (asyncNotifications.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (asyncNotifications.hasError)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 48,
                        color: TRYPColors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Could not load notifications',
                        style: TRYPTypography.bodyLarge.copyWith(
                          color: TRYPColors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(notificationsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            // Notification List
            else
              Expanded(
                child: filteredNotifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              size: 64,
                              color: TRYPColors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications found',
                              style: TRYPTypography.headingSmall.copyWith(
                                color: TRYPColors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'We will notify you about ride updates & offers here.',
                              style: TRYPTypography.bodySmall.copyWith(
                                color: TRYPColors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        itemCount: filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final notif = filteredNotifications[index];
                          return _NotificationCard(
                            notification: notif,
                            onTap: () {
                              ref
                                  .read(notificationsProvider.notifier)
                                  .markAsRead(notif.id);
                              // The notification view is opened on top of the
                              // current passenger screen; tapping a card should
                              // return there instead of replacing the stack.
                              if (context.canPop()) {
                                context.pop();
                              } else {
                                context.go(
                                  notif.routePath ?? Routes.passengerHome,
                                );
                              }
                            },
                            onDismissed: () {
                              ref
                                  .read(notificationsProvider.notifier)
                                  .removeNotification(notif.id);
                            },
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final TRYPNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismissed,
  });

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    Color iconBg;
    Color iconColor;
    IconData icon;

    switch (notification.type) {
      case NotificationType.ride:
        iconBg = TRYPColors.primary.withValues(alpha: 0.2);
        iconColor = TRYPColors.secondary;
        icon = Icons.directions_car_rounded;
        break;
      case NotificationType.promo:
        iconBg = Colors.purple.withValues(alpha: 0.15);
        iconColor = Colors.purple;
        icon = Icons.local_offer_rounded;
        break;
      case NotificationType.payment:
        iconBg = Colors.green.withValues(alpha: 0.15);
        iconColor = Colors.green;
        icon = Icons.receipt_long_rounded;
        break;
      case NotificationType.system:
        iconBg = Colors.orange.withValues(alpha: 0.15);
        iconColor = Colors.orange;
        icon = Icons.shield_rounded;
        break;
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? TRYPColors.lightGrey
                : TRYPColors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: notification.isRead
                  ? Colors.transparent
                  : TRYPColors.primary,
              width: 1.5,
            ),
            boxShadow: notification.isRead
                ? null
                : [
                    BoxShadow(
                      color: TRYPColors.primary.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TRYPTypography.bodyLarge.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              color: TRYPColors.secondary,
                            ),
                          ),
                        ),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: TRYPTypography.bodySmall.copyWith(
                            color: TRYPColors.grey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.grey,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: TRYPColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
