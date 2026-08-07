import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/app/app_variant.dart';
import 'package:tryp_driver/features/authentication/presentation/screens/splash_screen.dart';
import 'package:tryp_driver/features/authentication/presentation/screens/onboarding_screen.dart';
import 'package:tryp_driver/features/authentication/presentation/screens/welcome_screen.dart';
import 'package:tryp_driver/features/authentication/presentation/screens/login_screen.dart';
import 'package:tryp_driver/features/authentication/presentation/screens/register_screen.dart';
import 'package:tryp_driver/features/authentication/presentation/screens/phone_verification_screen.dart';
import 'package:tryp_driver/features/authentication/presentation/screens/email_verification_screen.dart';
import 'package:tryp_driver/features/authentication/presentation/screens/forgot_password_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_home_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_profile_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_onboarding_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_documents_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/active_trip_screen.dart';
import 'package:tryp_driver/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:tryp_driver/app/routes.dart';

export 'routes.dart';

GoRouter buildRouter(AppVariant variant) {
  final routes = <RouteBase>[
    GoRoute(
      path: Routes.notifications,
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: Routes.splash,
      builder: (context, state) => const SplashScreenPage(),
    ),
    GoRoute(
      path: Routes.onboarding,
      builder: (context, state) => const OnboardingScreenPage(),
    ),
    GoRoute(
      path: Routes.welcome,
      builder: (context, state) => const WelcomeScreenPage(),
    ),
    GoRoute(
      path: Routes.login,
      builder: (context, state) => const LoginScreenPage(),
    ),
    GoRoute(
      path: Routes.register,
      builder: (context, state) => const RegisterScreenPage(),
    ),
    GoRoute(
      path: Routes.phoneVerification,
      builder: (context, state) =>
          PhoneVerificationScreenPage(phone: state.extra as String? ?? ''),
    ),
    GoRoute(
      path: Routes.emailVerification,
      builder: (context, state) =>
          EmailVerificationScreenPage(email: state.extra as String? ?? ''),
    ),
    GoRoute(
      path: Routes.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreenPage(),
    ),
    // Driver-specific routes
    GoRoute(
      path: Routes.driverHome,
      builder: (context, state) => const DriverHomeScreenPage(),
    ),
    GoRoute(
      path: Routes.driverProfile,
      builder: (context, state) => const DriverProfileScreen(),
    ),
    GoRoute(
      path: Routes.driverOnboarding,
      builder: (context, state) => const DriverOnboardingScreen(),
    ),
    GoRoute(
      path: Routes.driverDocuments,
      builder: (context, state) => const DriverDocumentsScreen(),
    ),
    GoRoute(
      path: Routes.activeTrip,
      builder: (context, state) => const ActiveTripScreen(),
    ),
  ];

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    routes: routes,
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
}

class ErrorScreen extends StatelessWidget {
  final Exception? error;

  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text('Error: ${error?.toString()}')),
      );
}

/// Validates that a signed-in driver account has the correct role.
Future<String?> expectedHomeForCurrentVariant() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;

  final data = await client
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .maybeSingle();
  final role = data?['role'] as String?;
  if (role == currentAppVariant.expectedRole) {
    return Routes.driverHome;
  }
  return null;
}

String postVerificationRoute() => Routes.driverHome;
