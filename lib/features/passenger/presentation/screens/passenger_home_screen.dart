import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/notification_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

/// Passenger Home Screen — Bolt-style:
/// Full-screen map, floating minimal top bar, white bottom panel, pill nav
class PassengerHomeScreenPage extends ConsumerStatefulWidget {
  const PassengerHomeScreenPage({Key? key}) : super(key: key);

  @override
  ConsumerState<PassengerHomeScreenPage> createState() =>
      _PassengerHomeScreenPageState();
}

class _PassengerHomeScreenPageState
    extends ConsumerState<PassengerHomeScreenPage> {

  @override
  Widget build(BuildContext context) {
    final unreadNotifs = ref.watch(unreadNotificationCountProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      extendBodyBehindAppBar: true,
      appBar: _buildTopBar(unreadNotifs),
      body: Stack(
        children: [
          // ── Full-screen map ──────────────────────────────────────────────
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

          // ── Bottom Panel ─────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(0, 0, 0, bottomPad),
              decoration: const BoxDecoration(
                color: TRYPColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TRYPColors.greyLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── "Where to?" bar ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: () => context.go(Routes.rideRequest),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: TRYPColors.inputFill,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: TRYPColors.secondary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.search_rounded,
                                color: TRYPColors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                'Where to?',
                                style: TRYPTypography.bodyLarge.copyWith(
                                  color: TRYPColors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: TRYPColors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Saved Places chips ─────────────────────────────────
                  SizedBox(
                    height: 68,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _PlaceChip(
                          icon: Icons.home_rounded,
                          label: 'Home',
                          subtitle: 'Sandton City',
                          onTap: () => context.go(Routes.rideRequest),
                        ),
                        _PlaceChip(
                          icon: Icons.work_rounded,
                          label: 'Work',
                          subtitle: 'Melrose Arch',
                          onTap: () => context.go(Routes.rideRequest),
                        ),
                        _PlaceChip(
                          icon: Icons.fitness_center_rounded,
                          label: 'Gym',
                          subtitle: 'Virgin Active',
                          onTap: () => context.go(Routes.rideRequest),
                        ),
                        _PlaceChip(
                          icon: Icons.flight_takeoff_rounded,
                          label: 'Airport',
                          subtitle: 'OR Tambo',
                          onTap: () => context.go(Routes.rideRequest),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Bottom Nav Bar ─────────────────────────────────────
                  const TRYPBottomNavBar(currentIndex: 0),
                ],
              ),
            ),
          ),

          // ── My Location FAB ──────────────────────────────────────────────
          Positioned(
            right: 20,
            bottom: 220 + bottomPad,
            child: _FloatingMapButton(
              icon: Icons.my_location_rounded,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopBar(int unreadNotifs) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Logo mark pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: TRYPColors.primary,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'TRYP',
              style: TRYPTypography.labelLarge.copyWith(
                color: TRYPColors.secondary,
                letterSpacing: 2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Notification button
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: TRYPColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: TRYPColors.secondary,
                ),
                onPressed: () => context.push(Routes.notifications),
              ),
              if (unreadNotifs > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: TRYPColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$unreadNotifs',
                        style: const TextStyle(
                          color: TRYPColors.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Saved Place Chip
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _PlaceChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: TRYPColors.inputFill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: TRYPColors.secondary),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TRYPTypography.labelMedium.copyWith(
                    color: TRYPColors.secondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: TRYPTypography.bodySmall.copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Map Button
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingMapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _FloatingMapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: TRYPColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: TRYPColors.secondary, size: 20),
      ),
    );
  }
}
