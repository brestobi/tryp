/// Centralized application route paths.
class Routes {
  // Common & Notifications
  static const String notifications = '/notifications';

  // Splash & Onboarding
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  // Authentication
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String phoneVerification = '/phone-verification';
  static const String emailVerification = '/email-verification';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // Passenger
  static const String passengerHome = '/passenger/home';
  static const String passengerProfile = '/passenger/profile';
  static const String profileSetup = '/passenger/setup-profile';
  static const String passengerVerification = '/passenger/verification';
  static const String rideRequest = '/passenger/ride-request';
  static const String rideTracking = '/passenger/ride-tracking';
  static const String passengerActivity = '/passenger/activity';
  static const String rideCompletion = '/passenger/ride-completion';
  static const String tripHistory = '/passenger/trips';
  static const String longDistanceRides = '/passenger/long-distance';
}
