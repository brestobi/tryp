import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp_driver/app/routes.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/widgets/driver_bottom_nav_bar.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.surface,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        title: Text(
          'Profile',
          style: TRYPTypography.headingSmall.copyWith(fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TRYPColors.secondary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: TRYPColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Image.asset(
                      'assets/images/tryp-logo-green.png',
                      width: 52,
                      height: 52,
                      fit: BoxFit.contain,
                      semanticLabel: 'TRYP Driver logo',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver account',
                          style: TRYPTypography.titleLarge.copyWith(
                            color: TRYPColors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your account and vehicle details',
                          style: TRYPTypography.bodySmall.copyWith(
                            color: TRYPColors.secondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: TRYPColors.secondaryLight,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Account',
              style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 10),
            _ProfileActionTile(
              icon: Icons.badge_outlined,
              title: 'Driver details',
              subtitle: 'Personal and vehicle information',
              onTap: () {},
            ),
            _ProfileActionTile(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Driver wallet',
              subtitle: 'View cash collected and online payments held by TRYP',
              onTap: () => context.go(Routes.driverWallet),
            ),
            _ProfileActionTile(
              icon: Icons.account_balance_outlined,
              title: 'Payout details',
              subtitle: 'Manage your bank account information',
              onTap: () {},
            ),
            _ProfileActionTile(
              icon: Icons.help_outline_rounded,
              title: 'Driver support',
              subtitle: 'Get help with rides or your account',
              onTap: () {},
            ),
            const SizedBox(height: 4),
            const Divider(),
            const SizedBox(height: 4),
            Text(
              'Verification',
              style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 10),
            _ProfileActionTile(
              icon: Icons.verified_user_rounded,
              title: 'My Documents',
              subtitle: 'View and manage your PrDP & vehicle documents',
              onTap: () => context.go(Routes.driverDocuments),
            ),
            _ProfileActionTile(
              icon: Icons.directions_bus_rounded,
              title: 'Long Distance Trips',
              subtitle: 'Post and manage intercity trip listings',
              onTap: () => context.go(Routes.driverLongDistance),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/tryp-logo-green.png',
                    width: 96,
                    height: 74,
                    fit: BoxFit.contain,
                    semanticLabel: 'TRYP Driver logo',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by hungry developers',
                    style: TRYPTypography.bodySmall.copyWith(
                      color: TRYPColors.grey,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DriverBottomNavBar(currentIndex: 4),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TRYPColors.divider),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: TRYPColors.inputFill,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: TRYPColors.secondary),
        ),
        title: Text(title, style: TRYPTypography.titleMedium),
        subtitle: Text(subtitle, style: TRYPTypography.bodySmall),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: TRYPColors.grey,
        ),
      ),
    );
  }
}
