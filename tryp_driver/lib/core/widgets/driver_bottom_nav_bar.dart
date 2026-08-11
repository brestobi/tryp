import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp_driver/app/routes.dart';
import 'package:tryp_driver/app/theme.dart';

/// Primary navigation for the driver workspace.
///
/// Active trips and onboarding intentionally stay outside this bar so drivers
/// can focus on the current ride or verification flow without losing context.
/// Wallet is protected separately by its PIN/biometric screen.
class DriverBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const DriverBottomNavBar({super.key, required this.currentIndex});

  static const _items = <_DriverNavItemData>[
    _DriverNavItemData(
      icon: Icons.dashboard_rounded,
      label: 'Home',
      route: Routes.driverHome,
    ),
    _DriverNavItemData(
      icon: Icons.directions_bus_rounded,
      label: 'Long Dist.',
      route: Routes.driverLongDistance,
    ),
    _DriverNavItemData(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Wallet',
      route: Routes.driverWallet,
    ),
    _DriverNavItemData(
      icon: Icons.notifications_none_rounded,
      label: 'Inbox',
      route: Routes.notifications,
    ),
    _DriverNavItemData(
      icon: Icons.person_rounded,
      label: 'Profile',
      route: Routes.driverProfile,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TRYPColors.white,
        border: const Border(top: BorderSide(color: TRYPColors.divider)),
        boxShadow: [
          BoxShadow(
            color: TRYPColors.secondary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            for (var index = 0; index < _items.length; index++)
              Expanded(
                child: _DriverNavItem(
                  data: _items[index],
                  selected: currentIndex == index,
                  onTap: () {
                    if (currentIndex != index) {
                      context.go(_items[index].route);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DriverNavItemData {
  final IconData icon;
  final String label;
  final String route;

  const _DriverNavItemData({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _DriverNavItem extends StatelessWidget {
  final _DriverNavItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _DriverNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? TRYPColors.primary : TRYPColors.grey;

    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: TRYPColors.inputFill,
        highlightColor: TRYPColors.inputFill,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? TRYPColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(data.icon, size: 22, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TRYPTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
