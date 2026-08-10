import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/core/models/driver_wallet_model.dart';

class DriverWalletService {
  static const _pinHashKey = 'driver_wallet_pin_hash_v2';
  static const _pinSaltKey = 'driver_wallet_pin_salt_v2';
  static const _biometricKey = 'driver_wallet_biometrics_enabled_v1';
  static const _failedAttemptsKey = 'driver_wallet_pin_failed_attempts_v1';
  static const _lockedUntilKey = 'driver_wallet_pin_locked_until_v1';
  static const _maxPinAttempts = 5;
  static const _lockoutDuration = Duration(seconds: 30);

  final SupabaseClient _client;
  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  DriverWalletService(
    this._client, {
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  }) : _storage = storage ?? const FlutterSecureStorage(),

       _localAuth = localAuth ?? LocalAuthentication();

  Future<bool> hasPin() async =>
      (await _storage.read(key: _pinHashKey))?.isNotEmpty == true;

  Future<void> setPin(String pin) async {
    _validatePin(pin);
    final salt = base64UrlEncode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: _hashPin(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    _validatePin(pin);
    if (await pinLockoutRemaining() != null) return false;

    final expected = await _storage.read(key: _pinHashKey);
    final salt = await _storage.read(key: _pinSaltKey);
    final valid =
        expected != null &&
        salt != null &&
        _constantTimeEquals(expected, _hashPin(pin, salt));
    if (valid) {
      await _storage.delete(key: _failedAttemptsKey);
      await _storage.delete(key: _lockedUntilKey);
      return true;
    }

    final attempts =
        (int.tryParse(await _storage.read(key: _failedAttemptsKey) ?? '') ??
            0) +
        1;
    if (attempts >= _maxPinAttempts) {
      await _storage.write(
        key: _lockedUntilKey,
        value: DateTime.now()
            .add(_lockoutDuration)
            .millisecondsSinceEpoch
            .toString(),
      );
      await _storage.delete(key: _failedAttemptsKey);
    } else {
      await _storage.write(key: _failedAttemptsKey, value: attempts.toString());
    }
    return false;
  }

  Future<Duration?> pinLockoutRemaining() async {
    final lockedUntil = int.tryParse(
      await _storage.read(key: _lockedUntilKey) ?? '',
    );
    if (lockedUntil == null) return null;
    final remaining = lockedUntil - DateTime.now().millisecondsSinceEpoch;
    if (remaining <= 0) {
      await _storage.delete(key: _lockedUntilKey);
      return null;
    }
    return Duration(milliseconds: remaining);
  }

  Future<bool> biometricsAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    if (!await biometricsAvailable()) return false;
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to open your TRYP wallet',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (authenticated) {
        await _storage.write(key: _biometricKey, value: 'true');
      }
      return authenticated;
    } catch (_) {
      return false;
    }
  }

  Future<bool> biometricsEnabled() async =>
      (await _storage.read(key: _biometricKey)) == 'true';

  Future<DriverWalletModel> fetchWallet() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AuthException('Please sign in again.');

    final row = await _client
        .from('driver_wallets')
        .select()
        .eq('driver_id', userId)
        .maybeSingle();
    if (row == null) {
      return DriverWalletModel(
        driverId: userId,
        cashCollected: 0,
        onlineHeld: 0,
        cashPlatformFeeOwed: 0,
        platformFeesTotal: 0,
        updatedAt: DateTime.now().toUtc(),
      );
    }
    return DriverWalletModel.fromJson(row);
  }

  Future<List<DriverWalletTransactionModel>> fetchTransactions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw AuthException('Please sign in again.');

    final rows = await _client
        .from('driver_wallet_transactions')
        .select()
        .eq('driver_id', userId)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(DriverWalletTransactionModel.fromJson)
        .toList();
  }

  RealtimeChannel subscribeToWallet({
    required String driverId,
    required void Function(Map<String, dynamic>) onChanged,
  }) {
    return _client
        .channel('driver-wallet-$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'driver_wallets',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) => onChanged(payload.newRecord),
        )
      ..subscribe();
  }

  String _hashPin(String pin, String salt) {
    final digest = sha256.convert(utf8.encode('tryp-wallet-v2:$salt:$pin'));
    return digest.toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  void _validatePin(String pin) {
    final isValid =
        pin.length >= 4 &&
        pin.length <= 6 &&
        pin.codeUnits.every((unit) => unit >= 48 && unit <= 57);
    if (!isValid) {
      throw ArgumentError('Wallet PIN must contain 4 to 6 digits.');
    }
  }
}
