import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class TripActivityItem {
  final String id;
  final String destinationName;
  final String pickupName;
  final String date;
  final String rideType;
  final double fare;
  final String status; // 'Completed', 'Cancelled'
  final String driverName;

  const TripActivityItem({
    required this.id,
    required this.destinationName,
    required this.pickupName,
    required this.date,
    required this.rideType,
    required this.fare,
    required this.status,
    required this.driverName,
  });
}

/// Passenger Activity Screen — Bolt-style:
/// High contrast typography, clean modern trip cards, pill badges, floating TRYPBottomNavBar
class PassengerActivityScreen extends StatefulWidget {
  const PassengerActivityScreen({super.key});

  @override
  State<PassengerActivityScreen> createState() => _PassengerActivityScreenState();
}

class _PassengerActivityScreenState extends State<PassengerActivityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<TripActivityItem> _recentTrips = const [
    TripActivityItem(
      id: 'TRIP-9021',
      destinationName: 'Rosebank Mall',
      pickupName: 'Sandton City, Sandton',
      date: 'Today, 14:30',
      rideType: 'TRYP Go',
      fare: 41.00,
      status: 'Completed',
      driverName: 'K. Mokoena',
    ),
    TripActivityItem(
      id: 'TRIP-8842',
      destinationName: 'O.R. Tambo Airport',
      pickupName: 'Sandton City, Sandton',
      date: '24 Jul 2026, 09:15',
      rideType: 'TRYP Exec',
      fare: 258.00,
      status: 'Completed',
      driverName: 'David K.',
    ),
    TripActivityItem(
      id: 'TRIP-7710',
      destinationName: 'Mall of Africa',
      pickupName: 'Waterfall Estate, Midrand',
      date: '18 Jul 2026, 18:45',
      rideType: 'TRYP Comfort',
      fare: 109.38,
      status: 'Completed',
      driverName: 'Thabo N.',
    ),
    TripActivityItem(
      id: 'TRIP-6490',
      destinationName: 'Johannesburg Park Station',
      pickupName: 'Rosebank, Johannesburg',
      date: '10 Jul 2026, 11:20',
      rideType: 'TRYP Go',
      fare: 65.50,
      status: 'Cancelled',
      driverName: 'John D.',
    ),
  ];

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
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Activity',
          style: TRYPTypography.headingLarge.copyWith(
            fontSize: 26,
          ),
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
          TabBarView(
            controller: _tabController,
            children: [
              // Past Trips Tab
              ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                itemCount: _recentTrips.length,
                itemBuilder: (context, index) {
                  final trip = _recentTrips[index];
                  return _TripCard(trip: trip);
                },
              ),

              // Upcoming Trips Tab (Empty State)
              Center(
                child: Padding(
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
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          size: 32,
                          color: TRYPColors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No Upcoming Rides',
                        style: TRYPTypography.headingMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You don\'t have any scheduled trips right now.',
                        style: TRYPTypography.bodyMedium.copyWith(
                          color: TRYPColors.grey,
                        ),
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
              ),
            ],
          ),

          // Shared Floating Bottom Navigation Bar
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TRYPBottomNavBar(currentIndex: 2),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final TripActivityItem trip;

  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final isCompleted = trip.status == 'Completed';

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
                      : TRYPColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.directions_car_rounded
                      : Icons.close_rounded,
                  color: isCompleted ? TRYPColors.secondary : TRYPColors.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.destinationName,
                      style: TRYPTypography.titleLarge.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      trip.date,
                      style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
                    ),
                  ],
                ),
              ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? TRYPColors.success.withValues(alpha: 0.12)
                          : TRYPColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      trip.status,
                      style: TRYPTypography.labelSmall.copyWith(
                        color: isCompleted ? TRYPColors.success : TRYPColors.error,
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
                  const Icon(Icons.person_outline_rounded, size: 16, color: TRYPColors.grey),
                  const SizedBox(width: 6),
                  Text(
                    'Driver: ${trip.driverName}',
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
                    const Icon(Icons.refresh_rounded, size: 16, color: TRYPColors.secondary),
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
