import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/features/authentication/presentation/screens/splash_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/onboarding_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/welcome_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/login_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/register_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/phone_verification_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/email_verification_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/forgot_password_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_home_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_profile_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_profile_setup_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_verification_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_activity_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/ride_request_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/trip_tracking_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/ride_completion_screen.dart';
import 'package:tryp/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:tryp/app/routes.dart';
import 'package:tryp/core/services/trip_service.dart';

export 'routes.dart';

GoRouter buildRouter() {
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
  ];

  routes.addAll([
    GoRoute(
      path: Routes.passengerHome,
      builder: (context, state) => const PassengerHomeScreenPage(),
    ),
    GoRoute(
      path: Routes.passengerProfile,
      builder: (context, state) => const PassengerProfileScreen(),
    ),
    GoRoute(
      path: Routes.profileSetup,
      builder: (context, state) => const PassengerProfileSetupScreen(),
    ),
    GoRoute(
      path: Routes.passengerVerification,
      builder: (context, state) => const PassengerVerificationScreen(),
    ),
    GoRoute(
      path: Routes.rideRequest,
      builder: (context, state) => const RideRequestScreenPage(),
    ),
    GoRoute(
      path: Routes.rideTracking,
      builder: (context, state) => const TripTrackingScreenPage(),
    ),
    GoRoute(
      path: Routes.passengerActivity,
      builder: (context, state) => const PassengerActivityScreen(),
    ),
    GoRoute(
      path: Routes.rideCompletion,
      builder: (context, state) {
        final trip = state.extra;
        if (trip is! TripModel) {
          return const ErrorScreen(
            error: FormatException('Completed ride details are missing.'),
          );
        }
        return RideCompletionScreen(trip: trip);
      },
    ),
    GoRoute(
      path: Routes.tripHistory,
      builder: (context, state) => const PassengerActivityScreen(),
    ),
  ]);

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
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Error: ${error?.toString()}')));
}

/// Validates that a signed-in account belongs to the current app variant.
Future<String?> expectedHomeForCurrentVariant() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;

  final data = await client
      .from('profiles')
      .select('role, passenger_verification_status')
      .eq('id', user.id)
      .maybeSingle();
  final role = data?['role'] as String?;
  return role == 'passenger' ? Routes.passengerHome : null;
}

/// Decides where a Google-authenticated passenger should continue.
///
/// Google accounts receive a profile from the database trigger immediately,
/// so profile existence alone cannot identify a new account. The passenger
/// completion is recorded explicitly by the setup flow and is not inferred
/// from optional profile fields.
String? passengerRouteForGoogleProfile(Map<String, dynamic>? profile) {
  if (profile == null || profile['role'] != 'passenger') return null;

  final onboardingCompleted = profile['onboarding_completed'];
  return onboardingCompleted == true
      ? Routes.passengerHome
      : Routes.profileSetup;
}

/// Resolves a passenger's destination after authentication.
/// A short retry window avoids routing a new account before its profile exists.
/// The explicit completion flag makes this safe for restored sessions too.
Future<String?> googlePostAuthRoute() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return null;

  Map<String, dynamic>? profile;
  for (var attempt = 0; attempt < 5; attempt++) {
    profile = await client
        .from('profiles')
        .select('role, onboarding_completed')
        .eq('id', user.id)
        .maybeSingle();
    if (profile != null) break;
    if (attempt < 4) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  // A missing profile after the retry window is safest treated as a new
  // account: the setup screen can upsert the trigger-created row once the
  // connection recovers. A wrong-app role still returns null.
  return profile == null
      ? Routes.profileSetup
      : passengerRouteForGoogleProfile(profile);
}

String postVerificationRoute() => Routes.profileSetup;
