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
  static const String suspendedAccount = '/account-suspended';
  static const String profileLoadError = '/profile-load-error';

  // Passenger
  static const String passengerHome = '/passenger/home';
  static const String passengerProfile = '/passenger/profile';
  static const String profileSetup = '/passenger/setup-profile';
  static const String rideRequest = '/passenger/ride-request';
  static const String rideTracking = '/passenger/ride-tracking';
  static const String passengerActivity = '/passenger/activity';
  static const String rideCompletion = '/passenger/ride-completion';
  static const String tripHistory = '/passenger/trips';

  // Driver
  static const String driverHome = '/driver/home';
  static const String driverTripHistory = '/driver/trip-history';
  static const String driverProfile = '/driver/profile';
  static const String driverAccount = '/driver/account';
  static const String driverWallet = '/driver/wallet';
  static const String driverOnboarding = '/driver/onboarding';
  static const String driverDocuments = '/driver/documents';
  static const String activeTrip = '/driver/active-trip';
  static const String driverLongDistance = '/driver/long-distance';
}
