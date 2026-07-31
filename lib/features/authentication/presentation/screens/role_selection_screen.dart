import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';

/// Role Selection Screen — Bolt-style: white bg, bold headline, clean icon card choices
class RoleSelectionScreenPage extends StatelessWidget {
  const RoleSelectionScreenPage({super.key});

  void _navigateToHome(BuildContext context, String role) {
    if (role == 'passenger') {
      context.go(Routes.profileSetup);
    } else {
      context.go(Routes.driverHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: TRYPColors.white,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 0, 28, bottomPad + 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),

              // Logo mark (small)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TRYPColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'T',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: TRYPColors.secondary,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'How will you\nuse TRYP?',
                style: TRYPTypography.headingLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose your role to continue',
                style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
              ),
              const SizedBox(height: 40),

              // Passenger card — Clean Flutter Icon
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'Passenger',
                subtitle: 'Book rides and travel anywhere',
                onTap: () => _navigateToHome(context, 'passenger'),
              ),
              const SizedBox(height: 16),

              // Driver card — Clean Flutter Icon
              _RoleCard(
                icon: Icons.directions_car_rounded,
                title: 'Driver',
                subtitle: 'Manage rides and earn every day',
                onTap: () => _navigateToHome(context, 'driver'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _pressed ? TRYPColors.inputFill : TRYPColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _pressed ? TRYPColors.secondary : TRYPColors.divider,
            width: _pressed ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon inside a rounded square
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: TRYPColors.inputFill,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: 26,
                  color: TRYPColors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TRYPTypography.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: TRYPTypography.bodyMedium.copyWith(
                      color: TRYPColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: TRYPColors.grey,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
