import 'package:flutter/material.dart';
import 'package:flutter_paystack_plus/flutter_paystack_plus.dart';
import 'package:tryp/config/environment.dart';
import 'package:tryp/core/services/fare_calculator.dart';

/// TRYP Payment Service — wraps flutter_paystack_plus
class PaymentService {
  /// Launch Paystack checkout for a ride payment.
  ///
  /// [context]      — current BuildContext (required by the SDK for WebView)
  /// [email]        — customer's email address
  /// [amountRands]  — amount in Rands (e.g. 60.0 for R60) — converted to kobo internally
  /// [reference]    — unique transaction reference (generate one per transaction)
  /// [onSuccess]    — called when payment is confirmed
  /// [onCancelled]  — called when the user closes the payment sheet
  static Future<void> chargeForRide({
    required BuildContext context,
    required String email,
    required double amountRands,
    required String reference,
    required VoidCallback onSuccess,
    required VoidCallback onCancelled,
    String currency = 'ZAR',
    Map<String, dynamic>? metadata,
  }) async {
    // Paystack amounts are in the smallest currency unit (kobo/cents).
    // For ZAR: 1 Rand = 100 cents, so multiply by 100.
    final amountInCents = (amountRands * 100).round().toString();

    try {
      await FlutterPaystackPlus.openPaystackPopup(
        context: context,
        customerEmail: email,
        amount: amountInCents,
        reference: reference,
        secretKey: Environment.paystackSecretKey,
        callBackUrl: Environment.paystackCallbackUrl,
        currency: currency,
        metadata: metadata,
        onSuccess: onSuccess,
        onClosed: onCancelled,
      );
    } catch (e) {
      debugPrint('PaymentService error: $e');
      rethrow;
    }
  }

  /// Generate a unique transaction reference.
  static String generateReference({String prefix = 'TRYP'}) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$ts';
  }

  /// Map ride type label and distance to dynamic price in Rands.
  static double priceForRideType(String rideType, {double distanceKm = 8.5}) {
    return FareCalculatorService.calculateFare(
      distanceKm: distanceKm,
      rideTypeId: rideType,
    );
  }
}
