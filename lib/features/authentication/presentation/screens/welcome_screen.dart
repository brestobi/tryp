import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

/// Welcome Screen — Bolt-style: white bg, logo mark, bold headline, pill CTAs
class WelcomeScreenPage extends StatelessWidget {
  const WelcomeScreenPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: TRYPColors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top brand area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo mark
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: TRYPColors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'T',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: TRYPColors.secondary,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Welcome to\nTRYP.',
                      style: TRYPTypography.headingXL.copyWith(height: 1.1),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Move Smart. Move Safe.',
                      style: TRYPTypography.bodyLarge.copyWith(
                        color: TRYPColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom CTA panel
            Container(
              padding: EdgeInsets.fromLTRB(28, 28, 28, bottomPad + 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: 'Log in',
                    onPressed: () => context.go(Routes.login),
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    label: 'Create account',
                    onPressed: () => context.go(Routes.register),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
