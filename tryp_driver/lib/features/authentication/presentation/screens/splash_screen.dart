import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/app/router.dart';

/// Driver startup screen with a white background, green logo, and loading bar.
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
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('Location permission check error: $e');
    }

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
          if (driverStatus == 'approved' || driverStatus == 'under_review') {
            context.go(Routes.driverHome);
          } else {
            context.go(Routes.driverOnboarding);
          }
        } else {
          await client.auth.signOut();
          if (!mounted) return;
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
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Center(
            child: Image.asset(
              'assets/images/tryp-logo-green.png',
              width: 170,
              height: 170,
              fit: BoxFit.contain,
              semanticLabel: 'TRYP Driver logo',
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: Color(0xFFD9F0DF),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF116B2A)),
            ),
          ),
        ],
      ),
    );
  }
}
