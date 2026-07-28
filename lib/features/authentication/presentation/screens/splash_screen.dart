

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/constants/app_constants.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreenPage extends StatefulWidget {
  const SplashScreenPage({super.key});

  @override
  State<SplashScreenPage> createState() => _SplashScreenPageState();
}

class _SplashScreenPageState extends State<SplashScreenPage> {
  @override
  void initState() {
    super.initState();
    _initialize();
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

    // Check for an existing Supabase session — skip login if already authenticated
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      context.go(Routes.passengerHome);
    } else {
      context.go(Routes.onboarding);
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                const SizedBox(height: 16),

                const SizedBox(height: 12),
                Text(
                  AppConstants.appTagline,
                  style: TRYPTypography.bodyLarge.copyWith(
                    color: TRYPColors.white,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(TRYPColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
