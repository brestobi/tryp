import 'package:flutter/material.dart';
import 'package:tryp/app/theme.dart';

class DriverHomeScreenPage extends StatelessWidget {
  const DriverHomeScreenPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      appBar: AppBar(
        backgroundColor: TRYPColors.secondary,
        foregroundColor: TRYPColors.white,
        elevation: 0,
        title: const Text('TRYP'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning, John',
                style: TRYPTypography.headingLarge.copyWith(color: TRYPColors.white),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: TRYPColors.black,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('You are offline', style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey)),
                    const SizedBox(height: 12),
                    Text('Today’s Earnings', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
                    const SizedBox(height: 8),
                    Text('R450.00', style: TRYPTypography.headingLarge.copyWith(color: TRYPColors.primary)),
                    const SizedBox(height: 12),
                    Text('0 trips', style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TRYPColors.primary,
                        foregroundColor: TRYPColors.secondary,
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {},
                      child: const Text('Go Online'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DriverInfoCard(title: 'Trips', value: '0'),
                  _DriverInfoCard(title: 'Rating', value: '4.8'),
                  _DriverInfoCard(title: 'Online', value: 'Offline'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverInfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _DriverInfoCard({Key? key, required this.title, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TRYPColors.lightGrey,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(title, style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
            const SizedBox(height: 8),
            Text(value, style: TRYPTypography.headingSmall.copyWith(color: TRYPColors.secondary)),
          ],
        ),
      ),
    );
  }
}
