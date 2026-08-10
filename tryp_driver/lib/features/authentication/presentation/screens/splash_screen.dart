import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/app/app_variant.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/constants/app_constants.dart';

/// Driver Splash Screen — Premium Dark Aesthetic, Glowing Radar Ring, TRYP Driver Badge
class SplashScreenPage extends StatefulWidget {
  const SplashScreenPage({super.key});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _radarController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleIn = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _controller.forward();
    _initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Request location permissions (non-blocking)
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('Location permission check error: $e');
    }

    // Brief splash delay for smooth visual transition
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session != null) {
      try {
        final profile = await client
            .from('profiles')
            .select('role, driver_status')
            .eq('id', session.user.id)
            .maybeSingle();

        if (!mounted) return;

        final role = profile?['role'] as String?;
        final driverStatus = profile?['driver_status'] as String? ?? 'pending';

        if (role == 'driver') {
          // If driver account is approved or under review, go to driver home
          if (driverStatus == 'approved' || driverStatus == 'under_review') {
            context.go(Routes.driverHome);
          } else {
            context.go(Routes.driverOnboarding);
          }
        } else {
          // User has a passenger account - sign out and redirect to driver onboarding
          await client.auth.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This account is registered as a passenger. Please sign up or log in with a Driver account.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.go(Routes.onboarding);
        }
      } catch (e) {
        debugPrint('Error verifying driver session: $e');
        if (mounted) context.go(Routes.onboarding);
      }
    } else {
      context.go(Routes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      body: Stack(
        children: [
          // Subtle background grid glow pattern
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.85,
                  colors: [
                    TRYPColors.primary.withValues(alpha: 0.12),
                    TRYPColors.secondary,
                  ],
                ),
              ),
            ),
          ),

          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scaleIn,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Radar Ring around Driver Logo Icon
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _radarController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: const Size(128, 128),
                              painter: _DriverRadarPulsePainter(
                                progress: _radarController.value,
                              ),
                            );
                          },
                        ),

                        // Gold Logo Container
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: TRYPColors.primary,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: TRYPColors.primary.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 28,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/tryp_logo_light.png',
                              width: 56,
                              height: 56,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // TRYP Title
                    Text(
                      'TRYP',
                      style: TRYPTypography.headingXL.copyWith(
                        color: TRYPColors.white,
                        fontSize: 34,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // DRIVER Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: TRYPColors.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: TRYPColors.primary.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: TRYPColors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'DRIVER CONSOLE',
                            style: TRYPTypography.labelLarge.copyWith(
                              color: TRYPColors.white,
                              letterSpacing: 2.0,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      AppConstants.appTagline,
                      style: TRYPTypography.bodyMedium.copyWith(
                        color: TRYPColors.secondaryLight,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Loading indicator
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          TRYPColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Version Footer
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Text(
              'v${AppConstants.appVersion}',
              textAlign: TextAlign.center,
              style: TRYPTypography.bodySmall.copyWith(
                color: TRYPColors.secondaryLight.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverRadarPulsePainter extends CustomPainter {
  final double progress;

  const _DriverRadarPulsePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    for (var i = 0; i < 2; i++) {
      final p = (progress + (i * 0.5)) % 1.0;
      final radius = 44 + (p * 22);
      final opacity = (1.0 - p) * 0.35;

      final paint = Paint()
        ..color = TRYPColors.white.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DriverRadarPulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
