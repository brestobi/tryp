import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';

/// Driver Welcome Screen — Premium driver portal entry point
class WelcomeScreenPage extends StatelessWidget {
  const WelcomeScreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo Header
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: TRYPColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: TRYPColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/tryp_logo_light.png',
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Title Section
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: TRYPColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'DRIVER PARTNER PORTAL',
                        style: TRYPTypography.labelSmall.copyWith(
                          color: TRYPColors.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome to\nTRYP Driver.',
                      style: TRYPTypography.headingXL.copyWith(
                        color: TRYPColors.white,
                        height: 1.1,
                        fontSize: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Earn on your schedule, track live ride requests, and receive automated daily payouts.',
                      style: TRYPTypography.bodyLarge.copyWith(
                        color: TRYPColors.grey,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(0, 20, 0, bottomPad + 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () => context.go(Routes.login),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TRYPColors.primary,
                          foregroundColor: TRYPColors.secondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Driver Log In',
                          style: TRYPTypography.buttonText.copyWith(
                            color: TRYPColors.secondary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () => context.go(Routes.register),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TRYPColors.white,
                          side: BorderSide(
                            color: TRYPColors.white.withValues(alpha: 0.3),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Create Driver Account',
                          style: TRYPTypography.buttonText.copyWith(
                            color: TRYPColors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
