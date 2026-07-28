import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class RideRequestScreenPage extends StatefulWidget {
  const RideRequestScreenPage({Key? key}) : super(key: key);

  @override
  State<RideRequestScreenPage> createState() => _RideRequestScreenPageState();
}

class _RideRequestScreenPageState extends State<RideRequestScreenPage> {
  String _selectedRideType = 'Economy';
  String _paymentMethod = 'Cash';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        title: const Text('Choose a ride'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _RideTypeOption(
                title: 'Economy',
                duration: '4 min',
                price: 'R45 - 60',
                selected: _selectedRideType == 'Economy',
                onTap: () {
                  setState(() => _selectedRideType = 'Economy');
                },
              ),
              const SizedBox(height: 16),
              _RideTypeOption(
                title: 'Comfort',
                duration: '6 min',
                price: 'R60 - 80',
                selected: _selectedRideType == 'Comfort',
                onTap: () {
                  setState(() => _selectedRideType = 'Comfort');
                },
              ),
              const SizedBox(height: 16),
              _RideTypeOption(
                title: 'XL',
                duration: '7 min',
                price: 'R80 - 110',
                selected: _selectedRideType == 'XL',
                onTap: () {
                  setState(() => _selectedRideType = 'XL');
                },
              ),
              const SizedBox(height: 16),
              _RideTypeOption(
                title: 'Premium',
                duration: '8 min',
                price: 'R120 - 160',
                selected: _selectedRideType == 'Premium',
                onTap: () {
                  setState(() => _selectedRideType = 'Premium');
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Payment',
                style: TRYPTypography.headingSmall.copyWith(color: TRYPColors.secondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: TRYPColors.lightGrey,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.money, color: TRYPColors.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _paymentMethod,
                        style: TRYPTypography.bodyLarge,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 18, color: TRYPColors.grey),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Confirm',
                onPressed: () => context.go(Routes.rideTracking),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideTypeOption extends StatelessWidget {
  final String title;
  final String duration;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  const _RideTypeOption({
    Key? key,
    required this.title,
    required this.duration,
    required this.price,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? TRYPColors.primary.withOpacity(0.18) : TRYPColors.lightGrey,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? TRYPColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? TRYPColors.primary : TRYPColors.grey,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TRYPTypography.headingSmall.copyWith(color: TRYPColors.secondary)),
                  const SizedBox(height: 4),
                  Text(duration, style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
                ],
              ),
            ),
            Text(price, style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.secondary)),
          ],
        ),
      ),
    );
  }
}
