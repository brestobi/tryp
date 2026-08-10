import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';

/// Driver Onboarding Initial Screen — Bolt/Uber Driver style with rich interactive slides
class OnboardingScreenPage extends StatefulWidget {
  const OnboardingScreenPage({super.key});

  @override
  State<OnboardingScreenPage> createState() => _OnboardingScreenPageState();
}

class _OnboardingScreenPageState extends State<OnboardingScreenPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_DriverSlideData> _slides = const [
    _DriverSlideData(
      title: 'Drive & Earn\non Your Terms',
      subtitle:
          'Flexible hours, high passenger demand, and transparent earnings delivered straight to your bank account.',
      badgeLabel: 'DAILY PAYOUTS',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: TRYPColors.white,
    ),
    _DriverSlideData(
      title: 'Instant Dispatch &\nSmart Navigation',
      subtitle:
          'Receive real-time ride requests nearby with live turn-by-turn navigation and trip distance previews.',
      badgeLabel: 'REAL-TIME DISPATCH',
      icon: Icons.navigation_rounded,
      accentColor: Colors.blueAccent,
    ),
    _DriverSlideData(
      title: 'Keep 100% of Tips &\nSafety First',
      subtitle:
          '0% commission on passenger tips, verified rider profiles, and dedicated 24/7 South African support.',
      badgeLabel: 'VERIFIED DRIVERS & RIDERS',
      icon: Icons.shield_rounded,
      accentColor: TRYPColors.primary,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: TRYPColors.primaryAlt,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Driver Header & Step indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: TRYPColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          'assets/images/tryp-logo-green.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                          semanticLabel: 'TRYP Driver logo',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TRYP',
                            style: TRYPTypography.headingSmall.copyWith(
                              color: TRYPColors.white,
                              letterSpacing: 2.0,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'DRIVER PORTAL',
                            style: TRYPTypography.labelSmall.copyWith(
                              color: TRYPColors.white,
                              letterSpacing: 1.2,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Slide indicators
                  Row(
                    children: List.generate(
                      _slides.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(left: 6),
                        width: _currentPage == index ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? TRYPColors.primary
                              : TRYPColors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Middle Carousel Slides
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Feature Card Illustration Graphic
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: TRYPColors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: TRYPColors.white.withValues(alpha: 0.12),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Decorative Background Circles
                              Positioned(
                                top: -20,
                                right: -20,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: slide.accentColor.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -30,
                                left: -30,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: slide.accentColor.withValues(
                                      alpha: 0.08,
                                    ),
                                  ),
                                ),
                              ),

                              // Central Icon Badge
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: slide.accentColor.withValues(
                                        alpha: 0.18,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: slide.accentColor.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      slide.icon,
                                      size: 48,
                                      color: slide.accentColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: slide.accentColor,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      slide.badgeLabel,
                                      style: TRYPTypography.labelSmall.copyWith(
                                        color:
                                            slide.accentColor ==
                                                TRYPColors.white
                                            ? TRYPColors.dark
                                            : TRYPColors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Title
                        Text(
                          slide.title,
                          style: TRYPTypography.headingXL.copyWith(
                            color: TRYPColors.white,
                            fontSize: 30,
                            height: 1.15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle
                        Text(
                          slide.subtitle,
                          style: TRYPTypography.bodyLarge.copyWith(
                            color: TRYPColors.secondaryLight,
                            height: 1.5,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Buttons Container
            Container(
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad + 16),
              decoration: BoxDecoration(
                color: TRYPColors.secondary,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => context.go(Routes.register),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TRYPColors.primary,
                        foregroundColor: TRYPColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Register as Driver',
                            style: TRYPTypography.buttonText.copyWith(
                              color: TRYPColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                            color: TRYPColors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      onPressed: () => context.go(Routes.login),
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
                        'Driver Log In',
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
    );
  }
}

class _DriverSlideData {
  final String title;
  final String subtitle;
  final String badgeLabel;
  final IconData icon;
  final Color accentColor;

  const _DriverSlideData({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.icon,
    required this.accentColor,
  });
}
