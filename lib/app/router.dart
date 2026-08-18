import 'dart:async';

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
import 'package:tryp/features/authentication/presentation/screens/reset_password_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_home_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_profile_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_profile_setup_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_verification_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_activity_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/ride_request_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/trip_tracking_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/ride_completion_screen.dart';
import 'package:tryp/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/long_distance_rides_screen.dart';
import 'package:tryp/app/routes.dart';
import 'package:tryp/core/constants/service_areas.dart';
import 'package:tryp/core/services/trip_service.dart';

export 'routes.dart';

GoRouter buildRouter({PassengerRouteGuard? routeGuard}) {
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
    GoRoute(
      path: Routes.resetPassword,
      builder: (context, state) => ResetPasswordScreenPage(
        onCancel: () {
          routeGuard?.clearPasswordRecovery();
          context.go(Routes.login);
        },
      ),
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
    GoRoute(
      path: Routes.longDistanceRides,
      builder: (context, state) => const LongDistanceRidesScreen(),
    ),
  ]);

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    refreshListenable: routeGuard,
    redirect: routeGuard?.redirect,
    routes: routes,
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
}

/// Keeps passenger routes behind Supabase authentication and handles recovery.
/// Profile loading is cached so GoRouter redirects remain synchronous.
class PassengerRouteGuard extends ChangeNotifier {
  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _authSubscription;

  Session? _session;
  String? _role;
  bool _profileLoaded = false;
  bool _profileLoading = false;
  bool _profileLoadFailed = false;
  bool _passwordRecoveryActive = false;

  PassengerRouteGuard({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client {
    _session = _client.auth.currentSession;
    _authSubscription = _client.auth.onAuthStateChange.listen(_handleAuthState);
    if (_session == null) {
      _profileLoaded = true;
    } else {
      unawaited(_loadProfile(_session!.user.id));
    }
  }

  bool get _isAuthenticated => _session != null;

  static bool _isPublicRoute(String location) {
    return location == Routes.splash ||
        location == Routes.onboarding ||
        location == Routes.welcome ||
        location == Routes.login ||
        location == Routes.register ||
        location == Routes.phoneVerification ||
        location == Routes.emailVerification ||
        location == Routes.forgotPassword;
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    if (location == Routes.resetPassword) {
      return _passwordRecoveryActive ? null : Routes.login;
    }
    if (_passwordRecoveryActive) return Routes.resetPassword;
    if (_isPublicRoute(location)) return null;
    if (!_isAuthenticated) return Routes.onboarding;

    // A new Google account may not have a profile row until the trigger
    // completes. Allow the setup route once auth is established.
    if (location == Routes.profileSetup &&
        _profileLoaded &&
        !_profileLoadFailed &&
        (_role == null || _role == 'passenger')) {
      return null;
    }

    if (!_profileLoaded || _profileLoading) return Routes.splash;
    if (_profileLoadFailed || _role != 'passenger') return Routes.onboarding;
    return null;
  }

  void clearPasswordRecovery() {
    if (!_passwordRecoveryActive) return;
    _passwordRecoveryActive = false;
    notifyListeners();
  }

  void _handleAuthState(AuthState authState) {
    if (authState.event == AuthChangeEvent.passwordRecovery) {
      _passwordRecoveryActive = true;
    } else if (authState.event == AuthChangeEvent.signedOut) {
      _passwordRecoveryActive = false;
    }

    _session = authState.session;
    _role = null;
    _profileLoaded = _session == null;
    _profileLoading = false;
    _profileLoadFailed = false;
    notifyListeners();

    final userId = _session?.user.id;
    if (userId != null) unawaited(_loadProfile(userId));
  }

  Future<void> _loadProfile(String userId) async {
    if (_profileLoading) return;
    _profileLoading = true;
    _profileLoaded = false;
    _profileLoadFailed = false;
    notifyListeners();

    try {
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (_client.auth.currentUser?.id != userId) return;
      _role = profile?['role'] as String?;
    } catch (_) {
      if (_client.auth.currentUser?.id != userId) return;
      _role = null;
      _profileLoadFailed = true;
    } finally {
      if (_client.auth.currentUser?.id == userId) {
        _profileLoading = false;
        _profileLoaded = true;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription.cancel());
    super.dispose();
  }
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

  Map<String, dynamic>? data;
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      data = await client
          .from('profiles')
          .select('role, onboarding_completed, service_area')
          .eq('id', user.id)
          .maybeSingle();
    } on PostgrestException {
      // Older production schemas may not have the optional onboarding fields
      // yet. The role-only fallback still lets an authenticated passenger
      // reach profile setup instead of showing a false login failure.
      final fallback = await client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final fallbackRole = fallback?['role'] as String?;
      if (fallbackRole == 'passenger') return Routes.profileSetup;
      return null;
    }
    if (data != null) break;
    if (attempt < 4) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  // The auth trigger can commit the profile just after sign-in completes.
  // Treat a still-missing row as a new passenger profile instead of signing
  // the user out and incorrectly reporting a driver-account login failure.
  if (data == null) return Routes.profileSetup;

  final role = data['role'] as String?;
  if (role != 'passenger') return null;

  final hasServiceArea =
      TRYPServiceAreas.byId(data['service_area'] as String?) != null;
  return data['onboarding_completed'] == true && hasServiceArea
      ? Routes.passengerHome
      : Routes.profileSetup;
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
  final hasServiceArea =
      TRYPServiceAreas.byId(profile['service_area'] as String?) != null;
  return onboardingCompleted == true && hasServiceArea
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
        .select('role, onboarding_completed, service_area')
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
