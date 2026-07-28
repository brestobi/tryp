import 'package:flutter/material.dart';
import 'package:tryp/app/theme.dart';

class DriverOnboardingScreen extends StatelessWidget {
  const DriverOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      appBar: AppBar(
        backgroundColor: TRYPColors.secondary,
        foregroundColor: TRYPColors.white,
        elevation: 0,
        title: const Text('Driver Onboarding'),
      ),
      body: const Center(
        child: Text('Driver onboarding content goes here'),
      ),
    );
  }
}
