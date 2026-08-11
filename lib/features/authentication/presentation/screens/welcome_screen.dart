import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';

/// Welcome screen with a calm premium welcome flow matching the premium ride brand.
class WelcomeScreenPage extends StatelessWidget {
  const WelcomeScreenPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: TRYPColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: TRYPColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: TRYPColors.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/tryp-logo-red.png',
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to',
                        style: TRYPTypography.bodyLarge.copyWith(
                          color: TRYPColors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'TRYP.',
                        style: TRYPTypography.headingXL.copyWith(height: 1.0),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Move smart, stay safe, and arrive in style.',
                        style: TRYPTypography.bodyLarge.copyWith(
                          color: TRYPColors.grey,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(0, 20, 0, bottomPad + 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.go(Routes.login),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TRYPColors.primary,
                          foregroundColor: TRYPColors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text('Log in', style: TRYPTypography.buttonText),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => context.go(Routes.register),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TRYPColors.primary,
                          side: const BorderSide(
                            color: TRYPColors.primary,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: Text(
                          'Create account',
                          style: TRYPTypography.buttonText.copyWith(
                            color: TRYPColors.primary,
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
