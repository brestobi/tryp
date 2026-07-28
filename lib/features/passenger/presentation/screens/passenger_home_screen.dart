import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';

class PassengerHomeScreenPage extends StatelessWidget {
  const PassengerHomeScreenPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        leading: const Icon(Icons.menu),
        title: const Text('TRYP'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              backgroundColor: TRYPColors.primary,
              child: Icon(Icons.person, color: TRYPColors.secondary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: TRYPColors.lightGrey,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: const GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(-26.2041, 28.0473), // Default: Johannesburg
                      zoom: 14,
                    ),
                    myLocationEnabled: true,
                    zoomControlsEnabled: false,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Where to?',
                style: TRYPTypography.headingLarge.copyWith(
                  color: TRYPColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => context.go(Routes.rideRequest),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: TRYPColors.lightGrey,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: TRYPColors.grey),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Choose your destination',
                          style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 18, color: TRYPColors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Saved Places',
                    style: TRYPTypography.headingSmall.copyWith(
                      color: TRYPColors.secondary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'See all',
                      style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _SavedPlaceCard(
                    title: 'Home',
                    subtitle: '123 Main Street',
                    icon: Icons.home,
                  ),
                  const SizedBox(width: 12),
                  _SavedPlaceCard(
                    title: 'Work',
                    subtitle: '456 Office Road',
                    icon: Icons.work,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedPlaceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SavedPlaceCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TRYPColors.lightGrey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: TRYPColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: TRYPColors.secondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TRYPTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
