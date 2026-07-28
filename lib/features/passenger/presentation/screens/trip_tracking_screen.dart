import 'package:flutter/material.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class TripTrackingScreenPage extends StatelessWidget {
  const TripTrackingScreenPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        title: const Text('Searching Driver'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: TRYPColors.lightGrey,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(child: Text('Map placeholder')),
              ),
              const SizedBox(height: 24),
              Text(
                'Finding you a driver',
                style: TRYPTypography.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This may take a few seconds.',
                style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              const LoadingIndicator(message: 'Searching for nearby drivers...'),
            ],
          ),
        ),
      ),
    );
  }
}
