import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/trip_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

/// Helper to format DateTime into human-readable strings
String _formatTripDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tripDay = DateTime(dt.year, dt.month, dt.day);

  final timeStr =
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  if (tripDay == today) {
    return 'Today, $timeStr';
  } else if (tripDay == today.subtract(const Duration(days: 1))) {
    return 'Yesterday, $timeStr';
  } else {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $timeStr';
  }
}

/// Passenger Activity Screen — Supabase-backed:
/// Real-time passenger trip activity (Past Trips & Upcoming Rides)
class PassengerActivityScreen extends ConsumerStatefulWidget {
  const PassengerActivityScreen({super.key});

  @override
  ConsumerState<PassengerActivityScreen> createState() =>
      _PassengerActivityScreenState();
}

class _PassengerActivityScreenState
    extends ConsumerState<PassengerActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(passengerTripsProvider);

    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Activity',
          style: TRYPTypography.headingLarge.copyWith(fontSize: 26),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: TRYPColors.divider, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: TRYPColors.secondary,
              indicatorWeight: 3,
              labelColor: TRYPColors.secondary,
              unselectedLabelColor: TRYPColors.grey,
              labelStyle: TRYPTypography.titleLarge.copyWith(fontSize: 15),
              unselectedLabelStyle: TRYPTypography.bodyLarge,
              tabs: const [
                Tab(text: 'Past Trips'),
                Tab(text: 'Upcoming'),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          tripsAsync.when(
            data: (trips) {
              final pastTrips = trips
                  .where(
                    (t) =>
                        t.status == TripStatus.completed ||
                        t.status == TripStatus.cancelled,
                  )
                  .toList();

              final upcomingTrips = trips
                  .where(
                    (t) =>
                        t.status == TripStatus.requested ||
                        t.status == TripStatus.accepted ||
                        t.status == TripStatus.arrived ||
                        t.status == TripStatus.inTrip,
                  )
                  .toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  // Past Trips Tab
                  RefreshIndicator(
                    onRefresh: () async =>
                        ref.refresh(passengerTripsProvider.future),
                    child: pastTrips.isEmpty
                        ? _buildEmptyState(
                            icon: Icons.history_rounded,
                            title: 'No Past Trips',
                            description:
                                'Your completed and cancelled rides will appear here.',
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                            itemCount: pastTrips.length,
                            itemBuilder: (context, index) {
                              return _TripCard(trip: pastTrips[index]);
                            },
                          ),
                  ),

                  // Upcoming Trips Tab
                  RefreshIndicator(
                    onRefresh: () async =>
                        ref.refresh(passengerTripsProvider.future),
                    child: upcomingTrips.isEmpty
                        ? _buildEmptyState(
                            icon: Icons.calendar_today_rounded,
                            title: 'No Upcoming Rides',
                            description:
                                'You don\'t have any active or scheduled trips right now.',
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                            itemCount: upcomingTrips.length,
                            itemBuilder: (context, index) {
                              return _TripCard(trip: upcomingTrips[index]);
                            },
                          ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: TRYPColors.secondary),
            ),
            error: (err, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: TRYPColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        size: 32,
                        color: TRYPColors.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load activity',
                      style: TRYPTypography.headingMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      err.toString(),
                      style: TRYPTypography.bodyMedium.copyWith(
                        color: TRYPColors.grey,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Retry',
                      onPressed: () => ref.refresh(passengerTripsProvider),
                      width: 140,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Shared full-width flat bottom navigation bar
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TRYPBottomNavBar(currentIndex: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: TRYPColors.inputFill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 32, color: TRYPColors.grey),
            ),
            const SizedBox(height: 20),
            Text(title, style: TRYPTypography.headingMedium),
            const SizedBox(height: 8),
            Text(
              description,
              style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Book a Ride Now',
              onPressed: () => context.go(Routes.rideRequest),
              width: 200,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripModel trip;

  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final isCompleted = trip.status == TripStatus.completed;
    final isCancelled = trip.status == TripStatus.cancelled;

    Color statusBgColor;
    Color statusTextColor;
    String statusText;

    if (isCompleted) {
      statusBgColor = TRYPColors.lightGrey;
      statusTextColor = TRYPColors.secondary;
      statusText = 'Completed';
    } else if (isCancelled) {
      statusBgColor = TRYPColors.error.withValues(alpha: 0.12);
      statusTextColor = TRYPColors.error;
      statusText = 'Cancelled';
    } else {
      statusBgColor = TRYPColors.secondary.withValues(alpha: 0.12);
      statusTextColor = TRYPColors.secondary;
      switch (trip.status) {
        case TripStatus.requested:
          statusText = 'Requested';
          break;
        case TripStatus.accepted:
          statusText = 'Accepted';
          break;
        case TripStatus.arrived:
          statusText = 'Driver Arrived';
          break;
        case TripStatus.inTrip:
          statusText = 'In Trip';
          break;
        default:
          statusText = 'Active';
      }
    }

    final driverDisplayName = trip.driverName?.isNotEmpty == true
        ? trip.driverName!
        : (trip.driverId != null
              ? 'Assigned Driver'
              : (isCancelled ? 'N/A' : 'Searching...'));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TRYPColors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? TRYPColors.primary.withValues(alpha: 0.2)
                      : (isCancelled
                            ? TRYPColors.error.withValues(alpha: 0.1)
                            : TRYPColors.secondary.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.directions_car_rounded
                      : (isCancelled
                            ? Icons.close_rounded
                            : Icons.navigation_rounded),
                  color: isCompleted
                      ? TRYPColors.secondary
                      : (isCancelled ? TRYPColors.error : TRYPColors.secondary),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.destination,
                      style: TRYPTypography.titleLarge.copyWith(fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${trip.rideReference.isNotEmpty ? trip.rideReference : 'Trip'} · ${_formatTripDate(trip.requestedAt)}',
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.grey,
                      ),
                    ),
                    if (trip.scheduledFor != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Pickup scheduled: ${_formatTripDate(trip.scheduledFor!)}',
                        style: TRYPTypography.bodySmall.copyWith(
                          color: TRYPColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      'From: ${trip.origin}',
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.grey,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R${trip.fare.toStringAsFixed(2)}',
                    style: TRYPTypography.titleLarge.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      statusText,
                      style: TRYPTypography.labelSmall.copyWith(
                        color: statusTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: TRYPColors.divider),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: TRYPColors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Driver: $driverDisplayName',
                    style: TRYPTypography.bodySmall,
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.go(Routes.rideRequest),
                child: Row(
                  children: [
                    Text(
                      'Rebook',
                      style: TRYPTypography.labelMedium.copyWith(
                        color: TRYPColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: TRYPColors.secondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
