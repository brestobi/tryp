import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/core/services/fare_calculator.dart';
import 'package:url_launcher/url_launcher.dart';

/// TRYP Payment Service — initializes Paystack hosted checkout server-side.
class PaymentService {
  /// Initialize a ride payment on the server and open Paystack's hosted
  /// checkout. The amount, reference, and subaccount are never client-authored.
  static Future<String> chargeForRide({
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

    final launched = await launchUrl(
      Uri.parse(checkoutUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) throw StateError('Could not open Paystack checkout.');
    return reference;
  }

  /// Ask the server to verify a payment after returning from hosted checkout
  /// or when a webhook may have been delayed.
  static Future<String> verifyRidePayment({
    required String rideId,
  }) async {
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
