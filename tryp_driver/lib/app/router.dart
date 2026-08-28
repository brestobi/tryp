import 'dart:async';

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
import 'package:tryp_driver/features/authentication/presentation/screens/reset_password_screen.dart';
import 'package:tryp_driver/features/authentication/presentation/screens/suspended_account_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_home_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_trip_history_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_profile_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_account_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_wallet_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_onboarding_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_documents_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/active_trip_screen.dart';
import 'package:tryp_driver/features/driver/presentation/screens/driver_long_distance_screen.dart';
import 'package:tryp_driver/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:tryp_driver/app/routes.dart';

export 'routes.dart';

GoRouter buildRouter(AppVariant variant, {DriverRouteGuard? routeGuard}) {
  final guard =
      routeGuard ?? DriverRouteGuard(expectedRole: variant.expectedRole);
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
      path: Routes.suspendedAccount,
      builder: (context, state) => SuspendedAccountScreen(reason: state.uri.queryParameters['reason']),
    ),
    GoRoute(
      path: Routes.resetPassword,
      builder: (context, state) => ResetPasswordScreenPage(
        onCancel: () {
          guard.clearPasswordRecovery();
          context.go(Routes.login);
        },
      ),
    ),
    GoRoute(
      path: Routes.profileLoadError,
      builder: (context, state) => ProfileLoadErrorScreen(
        onRetry: () {
          guard.retryProfileLoad();
          context.go(Routes.splash);
        },
      ),
    ),
    // Driver-specific routes
    GoRoute(
      path: Routes.driverHome,
      builder: (context, state) => const DriverHomeScreenPage(),
    ),
    GoRoute(
      path: Routes.driverTripHistory,
      builder: (context, state) => const DriverTripHistoryScreen(),
    ),
    GoRoute(
      path: Routes.driverProfile,
      builder: (context, state) => const DriverProfileScreen(),
    ),
    GoRoute(
      path: Routes.driverAccount,
      builder: (context, state) => const DriverAccountScreen(),
    ),
    GoRoute(
      path: Routes.driverWallet,
      builder: (context, state) => const DriverWalletScreen(),
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
    GoRoute(
      path: Routes.driverLongDistance,
      builder: (context, state) => const DriverLongDistanceScreen(),
    ),
  ];

  return GoRouter(
    initialLocation: Routes.splash,
    debugLogDiagnostics: true,
    refreshListenable: guard,
    redirect: (context, state) => guard.redirect(state),
    routes: routes,
    errorBuilder: (context, state) => ErrorScreen(error: state.error),
  );
}

/// Cached auth/profile state used by GoRouter to protect driver routes.
/// Profile loading happens outside the redirect callback so navigation remains
/// synchronous and does not issue a database query on every route evaluation.
class DriverRouteGuard extends ChangeNotifier {
  final String expectedRole;
  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _authSubscription;

  Session? _session;
  String? _role;
  String? _driverStatus;
  String? _accountStatus;
  String? _suspensionReason;
  bool _profileLoaded = false;
  bool _profileLoading = false;
  bool _profileLoadFailed = false;
  bool _passwordRecoveryActive = false;

  DriverRouteGuard({required this.expectedRole, SupabaseClient? client})
    : _client = client ?? Supabase.instance.client {
    _session = _client.auth.currentSession;
    _authSubscription = _client.auth.onAuthStateChange.listen(_handleAuthState);
    if (_session != null) {
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
        location == Routes.forgotPassword ||
        location == Routes.resetPassword ||
        location == Routes.profileLoadError;
  }

  bool get _isApprovedOrUnderReview =>
      _driverStatus == 'approved' || _driverStatus == 'under_review';

  String? redirect(GoRouterState state) {
    final location = state.matchedLocation;
    if (location == Routes.resetPassword) return null;
    if (_passwordRecoveryActive) return Routes.resetPassword;
    if (_isPublicRoute(location)) return null;

    if (!_isAuthenticated) return Routes.onboarding;
    if (!_profileLoaded || _profileLoading) return Routes.splash;
    if (_profileLoadFailed) return Routes.profileLoadError;
    if (_accountStatus == 'suspended') return '${Routes.suspendedAccount}?reason=${Uri.encodeComponent(_suspensionReason ?? '')}';
    if (_role != expectedRole) return Routes.onboarding;

    final requiresApproval =
        location == Routes.driverHome || location == Routes.activeTrip;
    if (requiresApproval && !_isApprovedOrUnderReview) {
      return Routes.driverOnboarding;
    }

    return null;
  }

  /// Leave recovery mode when the user cancels the reset flow.
  void clearPasswordRecovery() {
    if (!_passwordRecoveryActive) return;
    _passwordRecoveryActive = false;
    notifyListeners();
  }

  void retryProfileLoad() {
    final userId = _client.auth.currentUser?.id;
    if (userId != null) unawaited(_loadProfile(userId));
  }

  void _handleAuthState(AuthState authState) {
    if (authState.event == AuthChangeEvent.passwordRecovery) {
      _passwordRecoveryActive = true;
    } else if (authState.event == AuthChangeEvent.signedOut) {
      _passwordRecoveryActive = false;
    }

    _session = authState.session;
    _role = null;
    _driverStatus = null;
    _accountStatus = null;
    _suspensionReason = null;
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
          .select('role, driver_status, account_status, suspension_reason')
          .eq('id', userId)
          .maybeSingle();

      if (_client.auth.currentUser?.id != userId) return;
      _role = profile?['role'] as String?;
      _driverStatus = profile?['driver_status'] as String? ?? 'pending';
      _accountStatus = profile?['account_status'] as String?;
      _suspensionReason = profile?['suspension_reason'] as String?;
    } catch (_) {
      if (_client.auth.currentUser?.id != userId) return;
      _role = null;
      _driverStatus = null;
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

class ProfileLoadErrorScreen extends StatelessWidget {
  final VoidCallback onRetry;

  const ProfileLoadErrorScreen({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 16),
            const Text(
              'We could not verify your driver account.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    ),
  );
}

class ErrorScreen extends StatelessWidget {
  final Exception? error;

  const ErrorScreen({super.key, this.error});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Error: ${error?.toString()}')));
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
