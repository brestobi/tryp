import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';

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

class PassengerActivityScreen extends StatefulWidget {
  const PassengerActivityScreen({Key? key}) : super(key: key);

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
        automaticallyImplyLeading: false,
        title: Text(
          'Activity',
          style: TRYPTypography.headingMedium.copyWith(
            color: TRYPColors.secondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TRYPColors.primary,
          indicatorWeight: 3,
          labelColor: TRYPColors.secondary,
          unselectedLabelColor: TRYPColors.grey,
          labelStyle: TRYPTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Past Trips'),
            Tab(text: 'Upcoming'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Past Trips Tab
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _recentTrips.length,
            itemBuilder: (context, index) {
              final trip = _recentTrips[index];
              return _TripCard(trip: trip);
            },
          ),

          // Upcoming Trips Tab (Empty State)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: TRYPColors.lightGrey,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    size: 36,
                    color: TRYPColors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Upcoming Rides',
                  style: TRYPTypography.headingSmall.copyWith(
                    color: TRYPColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You don\'t have any scheduled trips right now.',
                  style: TRYPTypography.bodyMedium.copyWith(
                    color: TRYPColors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(Routes.rideRequest),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TRYPColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Book a Ride Now'),
                ),
              ],
            ),
          ),
        ],
      ),

      // Floating bottom bar
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 20),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: TRYPColors.secondary,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                selected: false,
                onTap: () => context.go(Routes.passengerHome),
              ),
              _NavItem(
                icon: Icons.directions_car_rounded,
                label: 'Rides',
                selected: false,
                onTap: () => context.go(Routes.rideRequest),
              ),
              _NavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Activity',
                selected: true,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Account',
                selected: false,
                onTap: () => context.go(Routes.passengerProfile),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TRYPColors.lightGrey, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? TRYPColors.primary.withValues(alpha: 0.2)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.directions_car_rounded
                      : Icons.cancel_outlined,
                  color: isCompleted ? TRYPColors.secondary : Colors.red,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.destinationName,
                      style: TRYPTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
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
                    style: TRYPTypography.headingSmall.copyWith(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      trip.status,
                      style: TRYPTypography.bodySmall.copyWith(
                        color: isCompleted ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: TRYPColors.lightGrey),
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
                    style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.darkGrey),
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
                        fontWeight: FontWeight.bold,
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? TRYPColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? TRYPColors.secondary : TRYPColors.grey,
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TRYPTypography.labelMedium.copyWith(
                  color: TRYPColors.secondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
