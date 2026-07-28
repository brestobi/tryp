import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';

class RoleSelectionScreenPage extends StatelessWidget {
  const RoleSelectionScreenPage({Key? key}) : super(key: key);

  void _navigateToHome(BuildContext context, String role) {
    if (role == 'passenger') {
      context.go(Routes.passengerHome);
    } else {
      context.go(Routes.driverHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        title: const Text('Choose Your Role'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Continue as',
                style: TRYPTypography.headingLarge.copyWith(
                  color: TRYPColors.secondary,
                ),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                title: 'Passenger',
                subtitle: 'Ride with comfort and safety',
                icon: Icons.person,
                onTap: () => _navigateToHome(context, 'passenger'),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                title: 'Driver',
                subtitle: 'Manage rides and earn daily',
                icon: Icons.drive_eta,
                onTap: () => _navigateToHome(context, 'driver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: TRYPColors.lightGrey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: TRYPColors.primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: TRYPColors.secondary, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TRYPTypography.headingSmall.copyWith(
                      color: TRYPColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TRYPTypography.bodyMedium.copyWith(
                      color: TRYPColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }
}
