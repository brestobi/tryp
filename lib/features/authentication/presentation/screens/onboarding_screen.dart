import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/constants/app_constants.dart';

class OnboardingScreenPage extends StatelessWidget {
  const OnboardingScreenPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Row(
                children: [
                  Text(
                    AppConstants.appName,
                    style: TRYPTypography.headingLarge.copyWith(
                      color: TRYPColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 56),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/tryp_logo_dark.jpg',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(height: 40),
                    Text(
                      'Ride anywhere, anytime',
                      style: TRYPTypography.headingLarge.copyWith(
                        color: TRYPColors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Book a ride in seconds and get to your destination safely.',
                      style: TRYPTypography.bodyLarge.copyWith(
                        color: TRYPColors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      context.go(Routes.login);
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: TRYPColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.arrow_forward, color: TRYPColors.secondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
