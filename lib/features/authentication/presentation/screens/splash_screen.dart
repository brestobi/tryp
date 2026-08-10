import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/constants/app_constants.dart';

/// Splash Screen — Bolt-style: dark bg, centred logo mark + wordmark, subtle spinner
class SplashScreenPage extends StatefulWidget {
  const SplashScreenPage({super.key});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _spinnerController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleIn = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _spinnerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _controller.forward();
    _initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _spinnerController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Request location permissions (non-fatal)
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('Location permission error: $e');
    }

    // Brief splash delay so the logo is visible
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Check for an existing Supabase session
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      // Resolve profile completion for every restored passenger session.
      // Non-Google profiles default to completed, while new Google profiles
      // are explicitly marked incomplete by the auth trigger.
      String? route;
      try {
        route = await googlePostAuthRoute();
      } catch (error) {
        debugPrint('Profile routing error during session restore: $error');
        if (!mounted) return;
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        context.go(Routes.onboarding);
        return;
      }
      if (!mounted) return;

      if (route != null) {
        context.go(route);
      } else {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        context.go(Routes.onboarding);
      }
    } else {
      context.go(Routes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.primaryAlt,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _scaleIn,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Passenger red brand logo.
                Image.asset(
                  'assets/images/tryp-red.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                  semanticLabel: 'TRYP logo',
                ),
                const SizedBox(height: 22),
                Text(
                  AppConstants.appName,
                  style: TRYPTypography.headingXL.copyWith(
                    color: TRYPColors.white,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.appTagline,
                  style: TRYPTypography.bodyMedium.copyWith(
                    color: TRYPColors.secondaryLight,
                  ),
                ),
                const SizedBox(height: 52),
                Semantics(
                  label: 'Loading TRYP',
                  liveRegion: true,
                  child: AnimatedBuilder(
                    animation: _spinnerController,
                    builder: (context, child) => CustomPaint(
                      size: const Size.square(58),
                      painter: _TRYPSpinnerPainter(
                        progress: _spinnerController.value,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TRYPSpinnerPainter extends CustomPainter {
  final double progress;

  const _TRYPSpinnerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 5;
    final rotation = progress * math.pi * 2;

    final trackPaint = Paint()
      ..color = TRYPColors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = TRYPColors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      rotation - math.pi / 2,
      math.pi * 0.85,
      false,
      arcPaint,
    );

    for (var index = 0; index < 3; index++) {
      final angle = rotation - math.pi / 2 + (index * math.pi * 2 / 3);
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final dotPaint = Paint()
        ..color = TRYPColors.white.withValues(alpha: index == 0 ? 1 : 0.34)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, index == 0 ? 4.5 : 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TRYPSpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
