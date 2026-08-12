import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Fare Calculation Schema Configuration
class FareSchema {
  final String? id;
  final String? tier;

  /// Base fare charged at the start of any trip (R15)
  final double baseFare;

  /// Rate per kilometer traveled (R5/km)
  final double perKmRate;

  /// Minimum fare for any ride (R20)
  final double minFare;

  /// Additional fee for each companion beyond the booking passenger.
  final double extraPersonRate;

  /// Currency symbol/code
  final String currencySymbol;

  const FareSchema({
    this.id,
    this.tier,
    this.baseFare = 15.0,
    this.perKmRate = 5.0,
    this.minFare = 20.0,
    this.extraPersonRate = 0.0,
    this.currencySymbol = 'R',
  });

  /// Calculate exact fare in Rands given distance in km and vehicle multiplier
  double calculateFare({
    required double distanceKm,
    int additionalPassengers = 0,
    double multiplier = 1.0,
  }) {
    final calculated = (baseFare + (distanceKm * perKmRate)) * multiplier;
    final baseTripFare = calculated < minFare ? minFare : calculated;
    final companions = additionalPassengers < 0 ? 0 : additionalPassengers;
    return baseTripFare + (companions * extraPersonRate);
  }

  /// Create schema from JSON map (e.g. from Supabase `fare_schemas` table)
  factory FareSchema.fromJson(Map<String, dynamic> json) {
    return FareSchema(
      id: json['id'] as String?,
      tier: json['tier'] as String?,
      baseFare: (json['base_fare'] as num?)?.toDouble() ?? 15.0,
      perKmRate: (json['per_km_rate'] as num?)?.toDouble() ?? 5.0,
      minFare: (json['min_fare'] as num?)?.toDouble() ?? 20.0,
      extraPersonRate: (json['extra_person_rate'] as num?)?.toDouble() ?? 0.0,
      currencySymbol: json['currency_symbol'] as String? ?? 'R',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'base_fare': baseFare,
      'per_km_rate': perKmRate,
      'min_fare': minFare,
      'extra_person_rate': extraPersonRate,
      'currency_symbol': currencySymbol,
    };
  }
}

/// Ride Option Definition
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

/// Dynamic Fare Calculation Service
class FareCalculatorService {
  static const FareSchema defaultSchema = FareSchema();

  static const List<RideOption> availableRideTypes = [
    RideOption(
      id: 'Economy',
      name: 'TRYP Go',
      description: 'Affordable, everyday rides',
      multiplier: 1.0,
      icon: Icons.directions_car_rounded,
      capacity: 4,
    ),
    RideOption(
      id: 'Comfort',
      name: 'TRYP Comfort',
      description: 'Newer cars with extra legroom',
      multiplier: 1.25,
      icon: Icons.directions_car_filled_rounded,
      capacity: 4,
    ),
    RideOption(
      id: 'XL',
      name: 'TRYP XL',
      description: 'Spacious rides for groups up to 6',
      multiplier: 1.60,
      icon: Icons.airport_shuttle_rounded,
      capacity: 6,
    ),
    RideOption(
      id: 'Premium',
      name: 'TRYP Exec',
      description: 'High-end luxury vehicles & top drivers',
      multiplier: 2.00,
      icon: Icons.time_to_leave_rounded,
      capacity: 4,
    ),
  ];

  /// Calculate distance in kilometers between two lat/lng coordinates
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

  /// Calculate dynamic fare for a given ride type and distance
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
      multiplier: schema == null ? option.multiplier : 1.0,
    );
  }

  /// Calculate estimated duration in minutes based on distance (assuming average speed ~35 km/h in city traffic)
  static int estimateDurationMinutes(double distanceKm) {
    final hours = distanceKm / 35.0;
    final mins = (hours * 60).round();
    return mins < 3 ? 3 : mins;
  }
}
