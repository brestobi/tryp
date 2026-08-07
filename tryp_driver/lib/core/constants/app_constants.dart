/// TRYP Application Constants
class AppConstants {
  // App Info
  static const String appName = 'TRYP Driver';
  static const String appTagline = 'Drive Smart. Earn More.';
  static const String appVersion = '1.0.0';

  // Credentials (Google Cloud OAuth Client ID matching Supabase & Google Sign-In)
  static const String googleWebClientId = '756456562820-7934og3tdvng2gh6nihqhm8do9fakj3s.apps.googleusercontent.com';

  // API Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration longTimeout = Duration(seconds: 60);

  // Cache
  static const String cacheKeyUserProfile = 'user_profile';
  static const String cacheKeyUserToken = 'user_token';
  static const String cacheKeyUserRole = 'user_role';
  static const String cacheKeyOnboarded = 'user_onboarded';

  // Location
  static const double defaultMapZoom = 15.0;
  static const double nearbyDriversRadius = 5.0; // km
  static const int locationUpdateInterval = 5000; // milliseconds

  // Ride
  static const List<String> rideTypes = ['Economy', 'Comfort', 'XL'];
  static const double fareCalculationRadius = 100.0; // meters

  // Validation
  static const int minPasswordLength = 8;
  static const int minPhoneLength = 10;
  static const int maxPhoneLength = 15;

  // UI
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  static const Duration animationDuration = Duration(milliseconds: 300);
}

/// User Roles
enum UserRole {
  passenger,
  driver,
}

/// Ride Status
enum RideStatus {
  requested,
  searching,
  driverAssigned,
  driverArriving,
  driverArrived,
  tripStarted,
  completed,
  cancelled,
}

/// Driver Status
enum DriverStatus {
  pending,
  approved,
  rejected,
  suspended,
}

/// Online Status
enum OnlineStatus {
  online,
  offline,
  onTrip,
}
