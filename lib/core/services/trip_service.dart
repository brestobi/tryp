import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/core/services/supabase_service.dart';

enum TripStatus {
  requested,
  accepted,
  arrived,
  inTrip,
  completed,
  cancelled,
}

extension TripStatusX on TripStatus {
  String toDbString() {
    switch (this) {
      case TripStatus.requested:
        return 'requested';
      case TripStatus.accepted:
        return 'accepted';
      case TripStatus.arrived:
        return 'arrived';
      case TripStatus.inTrip:
        return 'in_trip';
      case TripStatus.completed:
        return 'completed';
      case TripStatus.cancelled:
        return 'cancelled';
    }
  }

  static TripStatus fromDbString(String val) {
    switch (val) {
      case 'accepted':
        return TripStatus.accepted;
      case 'arrived':
        return TripStatus.arrived;
      case 'in_trip':
        return TripStatus.inTrip;
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      case 'requested':
      default:
        return TripStatus.requested;
    }
  }
}

class TripModel {
  final String id;
  final String passengerId;
  final String? driverId;
  final String origin;
  final String destination;
  final TripStatus status;
  final double fare;
  final String rideType;
  final String paymentMethod;
  final String paymentStatus;
  final String pinCode;
  final double distanceKm;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const TripModel({
    required this.id,
    required this.passengerId,
    this.driverId,
    required this.origin,
    required this.destination,
    required this.status,
    required this.fare,
    required this.rideType,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.pinCode,
    required this.distanceKm,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.requestedAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    // Coordinates must be present — null defaults would silently mask bad data.
    final pickupLat = (json['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (json['pickup_lng'] as num?)?.toDouble();
    final destLat   = (json['dest_lat']   as num?)?.toDouble();
    final destLng   = (json['dest_lng']   as num?)?.toDouble();

    if (pickupLat == null || pickupLng == null || destLat == null || destLng == null) {
      throw FormatException(
        'TripModel.fromJson: missing coordinates in ride record (id=${json['id']}). '
        'pickup_lat=$pickupLat pickup_lng=$pickupLng dest_lat=$destLat dest_lng=$destLng',
      );
    }

    return TripModel(
      id: json['id'] as String,
      passengerId: json['passenger_id'] as String,
      driverId: json['driver_id'] as String?,
      origin: json['origin'] as String? ?? 'Pickup Location',
      destination: json['destination'] as String? ?? 'Destination',
      status: TripStatusX.fromDbString(json['status'] as String? ?? 'requested'),
      fare: (json['fare'] as num?)?.toDouble() ?? 0.0,
      rideType: json['ride_type'] as String? ?? 'TRYP Go',
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      pinCode: (json['metadata'] as Map<String, dynamic>?)?['pin_code'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      requestedAt: DateTime.tryParse(json['requested_at'] as String? ?? '') ?? DateTime.now(),
      acceptedAt: json['accepted_at'] != null ? DateTime.tryParse(json['accepted_at'] as String) : null,
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'] as String) : null,
    );
  }

  TripModel copyWith({
    String? id,
    String? passengerId,
    String? driverId,
    String? origin,
    String? destination,
    TripStatus? status,
    double? fare,
    String? rideType,
    String? paymentMethod,
    String? paymentStatus,
    String? pinCode,
    double? distanceKm,
    double? pickupLat,
    double? pickupLng,
    double? destLat,
    double? destLng,
    DateTime? requestedAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return TripModel(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      driverId: driverId ?? this.driverId,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      status: status ?? this.status,
      fare: fare ?? this.fare,
      rideType: rideType ?? this.rideType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      pinCode: pinCode ?? this.pinCode,
      distanceKm: distanceKm ?? this.distanceKm,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      requestedAt: requestedAt ?? this.requestedAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class TripService {
  final SupabaseClient _supabase;

  TripService(this._supabase);

  String _generatePinCode() {
    final rng = Random();
    return (1000 + rng.nextInt(9000)).toString();
  }

  /// Create a new ride request in Supabase
  Future<TripModel> requestRide({
    required String origin,
    required String destination,
    required double fare,
    required String rideType,
    required String paymentMethod,
    required double distanceKm,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('requestRide called without an authenticated user.');
    }

    final pinCode = _generatePinCode();
    final payload = {
      'passenger_id': user.id,
      'origin': origin,
      'destination': destination,
      'status': TripStatus.requested.toDbString(),
      'fare': fare,
      'ride_type': rideType,
      'payment_method': paymentMethod,
      'payment_status': 'pending',
      'distance_km': distanceKm,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'metadata': {'pin_code': pinCode},
      'requested_at': DateTime.now().toIso8601String(),
    };

    // Do NOT catch here — let the error propagate so the UI can surface it.
    final response = await _supabase.from('rides').insert(payload).select().single();
    return TripModel.fromJson(response);
  }

  /// Update trip status (accept, arrived, in_trip, completed, cancelled)
  Future<TripModel?> updateTripStatus({
    required String rideId,
    required TripStatus status,
    String? driverId,
  }) async {
    final updates = <String, dynamic>{
      'status': status.toDbString(),
    };

    if (driverId != null) updates['driver_id'] = driverId;
    if (status == TripStatus.accepted) updates['accepted_at'] = DateTime.now().toIso8601String();
    if (status == TripStatus.inTrip) updates['started_at'] = DateTime.now().toIso8601String();
    if (status == TripStatus.completed) {
      updates['completed_at'] = DateTime.now().toIso8601String();
      updates['payment_status'] = 'paid';
    }

    try {
      final response = await _supabase.from('rides').update(updates).eq('id', rideId).select().single();
      return TripModel.fromJson(response);
    } catch (e) {
      debugPrint('Error updating trip status: $e');
      return null;
    }
  }

  /// Realtime Stream for Active Ride
  RealtimeChannel subscribeToRide({
    required String rideId,
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    final channel = _supabase.channel('public:rides:id=eq.$rideId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'rides',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: rideId,
      ),
      callback: (payload) {
        if (payload.newRecord.isNotEmpty) {
          onUpdate(payload.newRecord);
        }
      },
    ).subscribe();

    return channel;
  }
}

final tripServiceProvider = Provider<TripService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return TripService(supabase);
});

class ActiveTripNotifier extends Notifier<TripModel?> {
  @override
  TripModel? build() => null;

  set stateTrip(TripModel? trip) => state = trip;
}

final activeTripStateProvider = NotifierProvider<ActiveTripNotifier, TripModel?>(ActiveTripNotifier.new);
