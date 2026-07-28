import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';

class PassengerHomeScreenPage extends StatefulWidget {
  const PassengerHomeScreenPage({Key? key}) : super(key: key);

  @override
  State<PassengerHomeScreenPage> createState() => _PassengerHomeScreenPageState();
}

class _PassengerHomeScreenPageState extends State<PassengerHomeScreenPage> {
  int _selectedIndex = 0;

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() => _selectedIndex = 0);
    } else if (index == 1) {
      context.go(Routes.rideRequest);
    } else if (index == 2) {
      context.go(Routes.passengerActivity);
    } else if (index == 3) {
      context.go(Routes.passengerProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      extendBodyBehindAppBar: true,
      // Minimal top bar — just a greeting + notification icon
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/tryp_icon.png',
              width: 36,
              height: 36,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.local_taxi,
                color: TRYPColors.primary,
                size: 32,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'TRYP',
              style: TRYPTypography.headingSmall.copyWith(
                color: TRYPColors.primary,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(14),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none, color: TRYPColors.white),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full-screen map
          const GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(-26.2041, 28.0473),
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          // Bottom sheet panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Where to?" search card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () => context.go(Routes.rideRequest),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        color: TRYPColors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: TRYPColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.search, color: TRYPColors.secondary, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Where to?',
                                  style: TRYPTypography.bodySmall.copyWith(
                                    color: TRYPColors.grey,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Choose your destination',
                                  style: TRYPTypography.bodyLarge.copyWith(
                                    color: TRYPColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: TRYPColors.grey),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Floating bottom nav bar
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, bottom: 28),
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
                          selected: _selectedIndex == 0,
                          onTap: () => _onNavTap(0),
                        ),
                        _NavItem(
                          icon: Icons.directions_car_rounded,
                          label: 'Rides',
                          selected: _selectedIndex == 1,
                          onTap: () => _onNavTap(1),
                        ),
                        _NavItem(
                          icon: Icons.receipt_long_rounded,
                          label: 'Activity',
                          selected: _selectedIndex == 2,
                          onTap: () => _onNavTap(2),
                        ),
                        _NavItem(
                          icon: Icons.person_rounded,
                          label: 'Account',
                          selected: _selectedIndex == 3,
                          onTap: () => _onNavTap(3),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // My location button
          Positioned(
            right: 20,
            bottom: 160,
            child: Container(
              decoration: BoxDecoration(
                color: TRYPColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.my_location, color: TRYPColors.primary),
                onPressed: () {},
              ),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? TRYPColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? TRYPColors.secondary : TRYPColors.grey,
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TRYPTypography.labelMedium.copyWith(
                  color: TRYPColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
