import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/core/services/fare_calculator.dart';
import 'package:tryp/core/services/payment_checkout_result.dart';
import 'package:tryp/features/passenger/presentation/screens/paystack_checkout_screen.dart';

/// TRYP Payment Service — initializes Paystack hosted checkout server-side.
class PaymentService {
  /// Initialize a ride payment on the server and open Paystack's hosted
  /// checkout. The amount, reference, and subaccount are never client-authored.
  static Future<PaymentCheckoutResult> chargeForRide({
    required NavigatorState navigator,
    required String rideId,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'paystack-initialize',
      body: {'ride_id': rideId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final checkoutUrl = data['authorization_url'] as String?;
    final reference = data['reference'] as String?;
    if (checkoutUrl == null || reference == null) {
      throw StateError('Paystack did not return a checkout URL.');
    }

    final callbackUrl =
        data['callback_url'] as String? ?? 'https://standard.paystack.co/close';

    final result = await navigator.push<PaymentCheckoutResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PaystackCheckoutScreen(
          checkoutUrl: checkoutUrl,
          callbackUrl: callbackUrl,
          verifyPayment: () => verifyRidePayment(rideId: rideId),
        ),
      ),
    );
    // An unexpected checkout dismissal is unresolved, not proof of cancellation.
    return result ?? PaymentCheckoutResult.pending;
  }

  /// Ask the server to verify a payment after returning from hosted checkout
  /// or when a webhook may have been delayed.
  static Future<String> verifyRidePayment({required String rideId}) async {
    final response = await Supabase.instance.client.functions.invoke(
      'paystack-verify',
      body: {'ride_id': rideId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['status'] as String? ?? 'unverified';
  }

  /// Map ride type label and distance to dynamic price in Rands.
  static double priceForRideType(String rideType, {double distanceKm = 8.5}) {
    return FareCalculatorService.calculateFare(
      distanceKm: distanceKm,
      rideTypeId: rideType,
    );
  }
}
