import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/features/authentication/presentation/screens/splash_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/onboarding_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/welcome_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/login_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/register_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/phone_verification_screen.dart';
import 'package:tryp/features/authentication/presentation/screens/role_selection_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_home_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_profile_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_profile_setup_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_activity_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/ride_request_screen.dart';
import 'package:tryp/features/passenger/presentation/screens/trip_tracking_screen.dart';
import 'package:tryp/features/driver/presentation/screens/driver_home_screen.dart';
import 'package:tryp/features/driver/presentation/screens/driver_profile_screen.dart';
import 'package:tryp/features/driver/presentation/screens/driver_onboarding_screen.dart';
import 'package:tryp/features/driver/presentation/screens/driver_documents_screen.dart';
import 'package:tryp/features/driver/presentation/screens/active_trip_screen.dart';

/// TRYP Navigation Routes
class Routes {
  // Splash & Onboarding
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  // Authentication
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String phoneVerification = '/phone-verification';
  static const String roleSelection = '/role-selection';

  // Passenger
  static const String passengerHome = '/passenger/home';
  static const String passengerProfile = '/passenger/profile';
  static const String profileSetup = '/passenger/setup-profile';
  static const String rideRequest = '/passenger/ride-request';
  static const String rideTracking = '/passenger/ride-tracking';
  static const String passengerActivity = '/passenger/activity';
  static const String tripHistory = '/passenger/trips';

  // Driver
  static const String driverHome = '/driver/home';
  static const String driverProfile = '/driver/profile';
  static const String driverOnboarding = '/driver/onboarding';
  static const String driverDocuments = '/driver/documents';
  static const String activeTrip = '/driver/active-trip';
}

/// GoRouter Configuration
final goRouter = GoRouter(
  initialLocation: Routes.splash,
  debugLogDiagnostics: true,
  routes: [
    // Splash
    GoRoute(
      path: Routes.splash,
      builder: (context, state) => const SplashScreenPage(),
    ),

    // Onboarding
    GoRoute(
      path: Routes.onboarding,
      builder: (context, state) => const OnboardingScreenPage(),
    ),

    // Welcome
    GoRoute(
      path: Routes.welcome,
      builder: (context, state) => const WelcomeScreenPage(),
    ),

    // Authentication
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
      builder: (context, state) => const PhoneVerificationScreenPage(),
    ),

    GoRoute(
      path: Routes.roleSelection,
      builder: (context, state) => const RoleSelectionScreenPage(),
    ),

    // Passenger Routes
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
      path: Routes.tripHistory,
      builder: (context, state) => const PassengerActivityScreen(),
    ),


    // Driver Routes
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
  ],
  errorBuilder: (context, state) => ErrorScreen(error: state.error),
);

class ErrorScreen extends StatelessWidget {
  final Exception? error;
  const ErrorScreen({Key? key, this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text('Error: ${error?.toString()}'),
        ),
      );
}
