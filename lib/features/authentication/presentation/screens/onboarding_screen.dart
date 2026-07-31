import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';

/// Onboarding Screen — Bolt-style: dark bg, hero image, bold text, bottom CTA
class OnboardingScreenPage extends StatelessWidget {
  const OnboardingScreenPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      body: Stack(
        children: [
          // Background image fills top 65% of screen
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.65,
            child: ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  TRYPColors.secondary.withValues(alpha: 0),
                  TRYPColors.secondary.withValues(alpha: 0.6),
                  TRYPColors.secondary,
                ],
                stops: const [0.0, 0.7, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.srcOver,
              child: Image.asset(
                'assets/images/tryp_logo_dark.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: TRYPColors.secondaryLight,
                  child: const Center(
                    child: Icon(Icons.local_taxi_rounded,
                        color: TRYPColors.primary, size: 80),
                  ),
                ),
              ),
            ),
          ),

          // Content panel at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 28,
                right: 28,
                top: 36,
                bottom: MediaQuery.of(context).padding.bottom + 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo mark + wordmark inline
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: TRYPColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text(
                            'T',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: TRYPColors.secondary,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'TRYP',
                        style: TRYPTypography.headingSmall.copyWith(
                          color: TRYPColors.white,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Hero headline
                  Text(
                    'Ride anywhere,\nanytime.',
                    style: TRYPTypography.headingXL.copyWith(
                      color: TRYPColors.white,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Book a ride in seconds and get to your\ndestination safely.',
                    style: TRYPTypography.bodyLarge.copyWith(
                      color: TRYPColors.grey,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Primary CTA — yellow pill
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () => context.go(Routes.login),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TRYPColors.primary,
                        foregroundColor: TRYPColors.secondary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                        textStyle: TRYPTypography.buttonText.copyWith(
                          color: TRYPColors.secondary,
                        ),
                      ),
                      child: Text(
                        'Get started',
                        style: TRYPTypography.buttonText.copyWith(
                          color: TRYPColors.secondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Secondary: already have an account
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go(Routes.login),
                      child: Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TRYPTypography.bodyMedium.copyWith(
                            color: TRYPColors.grey,
                          ),
                          children: [
                            TextSpan(
                              text: 'Log in',
                              style: TRYPTypography.bodyMedium.copyWith(
                                color: TRYPColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
