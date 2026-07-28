import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase service provider
final supabaseProvider = riverpod.Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Supabase client direct access
final supabaseClientProvider = riverpod.Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth service provider
final authServiceProvider = riverpod.Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthService(client);
});

/// Authentication Service
class AuthService {
  final SupabaseClient _supabase;
  final _logger = Logger();

  AuthService(this._supabase);

  /// Get current user
  User? get currentUser => _supabase.auth.currentUser;

  /// Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      _logger.i('Signing in with Google');
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
      );
    } catch (e) {
      _logger.e('Google sign in error: $e');
      rethrow;
    }
  }

  /// Sign up with email and password.
  Future<AuthResponse> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
  }) async {
    try {
      _logger.i('Signing up with email: $email');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
      );

      final user = response.user ?? response.session?.user;
      if (user == null) {
        throw AuthException('Sign up failed: missing user session or user data');
      }

      await _supabase.from('profiles').insert({
        'id': user.id,
        'full_name': fullName,
        'email': email,
      });

      return response;
    } on AuthException catch (error) {
      _logger.e('Sign up auth error: ${error.message}');
      rethrow;
    } catch (error) {
      _logger.e('Sign up error: $error');
      rethrow;
    }
  }

  /// Sign in with email and password.
  Future<AuthResponse> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      _logger.i('Signing in with email: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session == null && response.user == null) {
        throw AuthException('Sign in failed: missing session or user data');
      }

      return response;
    } on AuthException catch (error) {
      _logger.e('Sign in auth error: ${error.message}');
      rethrow;
    } catch (error) {
      _logger.e('Sign in error: $error');
      rethrow;
    }
  }

  /// Sign up with phone and password.
  Future<AuthResponse> signUpWithPhone(
    String phone,
    String password, {
    String? fullName,
  }) async {
    try {
      _logger.i('Signing up with phone: $phone');
      final response = await _supabase.auth.signUp(
        phone: phone,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
      );

      final user = response.user ?? response.session?.user;
      if (user == null) {
        throw AuthException('Sign up failed: missing user session or user data');
      }

      await _supabase.from('profiles').insert({
        'id': user.id,
        'full_name': fullName,
        'phone': phone,
      });

      return response;
    } on AuthException catch (error) {
      _logger.e('Sign up auth error: ${error.message}');
      rethrow;
    } catch (error) {
      _logger.e('Sign up error: $error');
      rethrow;
    }
  }

  /// Sign in with phone and password.
  Future<AuthResponse> signInWithPhone(
    String phone,
    String password,
  ) async {
    try {
      _logger.i('Signing in with phone: $phone');
      final response = await _supabase.auth.signInWithPassword(
        phone: phone,
        password: password,
      );

      if (response.session == null && response.user == null) {
        throw AuthException('Sign in failed: missing session or user data');
      }

      return response;
    } on AuthException catch (error) {
      _logger.e('Sign in auth error: ${error.message}');
      rethrow;
    } catch (error) {
      _logger.e('Sign in error: $error');
      rethrow;
    }
  }

  /// Verify OTP for phone-based auth flows.
  Future<AuthResponse> verifyOTP(
    String phone,
    String otp,
  ) async {
    try {
      _logger.i('Verifying OTP for phone: $phone');
      final response = await _supabase.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.session == null && response.user == null) {
        throw AuthException('OTP verification failed: missing session or user data');
      }

      return response;
    } on AuthException catch (error) {
      _logger.e('OTP verification auth error: ${error.message}');
      rethrow;
    } catch (e) {
      _logger.e('OTP verification error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      _logger.i('Signing out');
      await _supabase.auth.signOut();
      _logger.i('Sign out successful');
    } catch (e) {
      _logger.e('Sign out error: $e');
      rethrow;
    }
  }
}
