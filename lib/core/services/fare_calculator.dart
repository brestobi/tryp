import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/core/services/supabase_service.dart';

/// Fare calculation schema loaded from the admin-managed `fare_schemas` table.
class FareSchema {
  final String? id;
  final String? tier;
  final double baseFare;
  final double perKmRate;
  final double minFare;
  final double perMinuteRate;
  final double surgeMultiplier;
  final String currencySymbol;

  const FareSchema({
    this.id,
    this.tier,
    this.baseFare = 15.0,
    this.perKmRate = 5.0,
    this.minFare = 20.0,
    this.perMinuteRate = 0.0,
    this.surgeMultiplier = 1.0,
    this.currencySymbol = 'R',
  });

  /// Calculate the passenger fare in Rands using the admin-managed rates.
  double calculateFare({
    required double distanceKm,
    double durationMins = 0,
    double multiplier = 1.0,
  }) {
    final distance = distanceKm < 0 ? 0.0 : distanceKm;
    final duration = durationMins < 0 ? 0.0 : durationMins;
    final surge = surgeMultiplier < 0 ? 0.0 : surgeMultiplier;
    final calculated =
        (baseFare + (distance * perKmRate) + (duration * perMinuteRate)) *
        surge *
        multiplier;
    return calculated < minFare ? minFare : calculated;
  }

  factory FareSchema.fromJson(Map<String, dynamic> json) {
    return FareSchema(
      id: json['id'] as String?,
      tier: json['tier'] as String?,
      baseFare: (json['base_fare'] as num?)?.toDouble() ?? 15.0,
      perKmRate: (json['per_km_rate'] as num?)?.toDouble() ?? 5.0,
      minFare: (json['min_fare'] as num?)?.toDouble() ?? 20.0,
      perMinuteRate: (json['per_minute_rate'] as num?)?.toDouble() ?? 0.0,
      surgeMultiplier: (json['surge_multiplier'] as num?)?.toDouble() ?? 1.0,
      currencySymbol: json['currency_symbol'] as String? ?? 'R',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (tier != null) 'tier': tier,
      'base_fare': baseFare,
      'per_km_rate': perKmRate,
      'min_fare': minFare,
      'per_minute_rate': perMinuteRate,
      'surge_multiplier': surgeMultiplier,
      'currency_symbol': currencySymbol,
    };
  }
}

/// Ride option definition used by the passenger UI and legacy fallback.
class RideOption {
  final String id;
  final String name;
  final String description;
  final double multiplier;
  final IconData icon;
  final int capacity;

  const RideOption({
    required this.id,
    required this.name,
    required this.description,
    required this.multiplier,
    required this.icon,
    required this.capacity,
  });
}

/// Dynamic fare calculation service.
class FareCalculatorService {
  /// Offline fallback only. Normal passenger pricing uses the Supabase schema.
  static const FareSchema defaultSchema = FareSchema();

  static const List<RideOption> availableRideTypes = [
    RideOption(
      id: 'TRYP Go',
      name: 'TRYP Go',
      description: 'Affordable, everyday rides',
      multiplier: 1.0,
      icon: Icons.directions_car_rounded,
      capacity: 4,
    ),
    RideOption(
      id: 'TRYP Comfort',
      name: 'TRYP Comfort',
      description: 'Newer cars with extra legroom',
      multiplier: 1.25,
      icon: Icons.directions_car_filled_rounded,
      capacity: 4,
    ),
    RideOption(
      id: 'TRYP XL',
      name: 'TRYP XL',
      description: 'Spacious rides for groups up to 6',
      multiplier: 1.60,
      icon: Icons.airport_shuttle_rounded,
      capacity: 6,
    ),
    RideOption(
      id: 'TRYP Exec',
      name: 'TRYP Exec',
      description: 'High-end luxury vehicles & top drivers',
      multiplier: 2.00,
      icon: Icons.time_to_leave_rounded,
      capacity: 4,
    ),
  ];

  static double calculateDistanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final distanceInMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    return distanceInMeters / 1000.0;
  }

  /// Calculate a fare with the selected live schema when available.
  ///
  /// When [schema] is supplied, its per-tier rates, per-minute rate, and
  /// surge multiplier are authoritative. Without one, the legacy multiplier
  /// fallback keeps the app usable while the fare table is unavailable.
  static double calculateFare({
    required double distanceKm,
    required String rideTypeId,
    FareSchema? schema,
    double durationMins = 0,
  }) {
    final option = availableRideTypes.firstWhere(
      (opt) => opt.id == rideTypeId,
      orElse: () => availableRideTypes.first,
    );
    final selectedSchema = schema ?? defaultSchema;
    return selectedSchema.calculateFare(
      distanceKm: distanceKm,
      durationMins: durationMins,
      multiplier: schema == null ? option.multiplier : 1.0,
    );
  }

  static int estimateDurationMinutes(double distanceKm) {
    final hours = distanceKm / 35.0;
    final mins = (hours * 60).round();
    return mins < 3 ? 3 : mins;
  }
}

/// Live admin-managed fare schemas keyed by tier name and schema ID.
final fareSchemasProvider = FutureProvider.autoDispose<Map<String, FareSchema>>(
  (ref) async {
    final client = ref.watch(supabaseClientProvider);
    final channel = client.channel('passenger-fare-schemas');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'fare_schemas',
          callback: (_) => ref.invalidateSelf(),
        )
        .subscribe();
    ref.onDispose(() {
      channel.unsubscribe();
    });

    final rows = await client.from('fare_schemas').select('*');
    final schemas = <String, FareSchema>{};
    for (final raw in rows as List<dynamic>) {
      final schema = FareSchema.fromJson(Map<String, dynamic>.from(raw as Map));
      final tier = schema.tier?.trim();
      final id = schema.id?.trim();
      if (tier != null && tier.isNotEmpty) schemas[tier] = schema;
      if (id != null && id.isNotEmpty) schemas[id] = schema;
    }
    return schemas;
  },
);
