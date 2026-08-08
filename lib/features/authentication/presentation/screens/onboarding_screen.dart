import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';

/// Simple monochrome onboarding flow.
class OnboardingScreenPage extends StatelessWidget {
  const OnboardingScreenPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: TRYPColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.asset(
                      'assets/images/tryp_logo_light.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'TRYP',
                    style: TRYPTypography.headingSmall.copyWith(
                      color: TRYPColors.primary,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/splash-screen.png',
                        width: double.infinity,
                        height: 260,
                        fit: BoxFit.contain,
                        semanticLabel: 'TRYP passenger ride illustration',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your ride,\nsimplified.',
                      style: TRYPTypography.headingXL.copyWith(height: 1.05),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Book a ride, follow your driver, and get where you need to go safely.',
                      style: TRYPTypography.bodyLarge.copyWith(
                        color: TRYPColors.grey,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go(Routes.login),
                  child: const Text('Get started'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go(Routes.register),
                  child: const Text('Create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
