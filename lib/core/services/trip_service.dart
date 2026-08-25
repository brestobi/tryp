import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/core/services/supabase_service.dart';

enum TripStatus { requested, accepted, arrived, inTrip, completed, cancelled }

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

class UserProfileModel {
  final String id;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final String role;
  final String? serviceArea;
  final bool isOnline;
  final double? currentLat;
  final double? currentLng;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehiclePlate;

  const UserProfileModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.avatarUrl,
    required this.role,
    this.serviceArea,
    this.isOnline = false,
    this.currentLat,
    this.currentLng,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.vehiclePlate,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'TRYP User',
      phone: json['phone'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'passenger',
      serviceArea: json['service_area'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble(),
      vehicleMake: json['vehicle_make'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
    );
  }

  String get vehicleDescription {
    final parts = [
      vehicleColor,
      vehicleMake,
      vehicleModel,
    ].where((p) => p != null && p.isNotEmpty).join(' ');
    if (parts.isEmpty) return 'TRYP Vehicle';
    if (vehiclePlate != null && vehiclePlate!.isNotEmpty) {
      return '$parts ($vehiclePlate)';
    }
    return parts;
  }
}

class TripModel {
  final String id;
  final String rideReference;
  final String passengerId;
  final String? passengerName;
  final String? passengerPhone;
  final String? passengerAvatar;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverAvatar;
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehiclePlate;
  final double? driverLat;
  final double? driverLng;
  final String origin;
  final String destination;
  final TripStatus status;
  final double fare;
  final String rideType;
  final String paymentMethod;
  final String paymentStatus;
  final String pinCode;
  final int additionalPassengers;
  final double distanceKm;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;
  final DateTime requestedAt;
  final DateTime? scheduledFor;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final bool driverCompleted;
  final bool passengerCompleted;

  const TripModel({
    required this.id,
    required this.rideReference,
    required this.passengerId,
    this.passengerName,
    this.passengerPhone,
    this.passengerAvatar,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverAvatar,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleColor,
    this.vehiclePlate,
    this.driverLat,
    this.driverLng,
    required this.origin,
    required this.destination,
    required this.status,
    required this.fare,
    required this.rideType,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.pinCode,
    this.additionalPassengers = 0,
    required this.distanceKm,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
    required this.requestedAt,
    this.scheduledFor,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.driverCompleted = false,
    this.passengerCompleted = false,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    final pickupLat = (json['pickup_lat'] as num?)?.toDouble() ?? 0.0;
    final pickupLng = (json['pickup_lng'] as num?)?.toDouble() ?? 0.0;
    final destLat = (json['dest_lat'] as num?)?.toDouble() ?? 0.0;
    final destLng = (json['dest_lng'] as num?)?.toDouble() ?? 0.0;

    String? driverName;
    String? driverPhone;
    String? driverAvatar;
    String? vehicleMake;
    String? vehicleModel;
    String? vehicleColor;
    String? vehiclePlate;
    double? driverLat;
    double? driverLng;

    if (json['driver'] != null && json['driver'] is Map) {
      final d = Map<String, dynamic>.from(json['driver'] as Map);
      driverName = d['full_name'] as String?;
      driverPhone = d['phone'] as String?;
      driverAvatar = d['avatar_url'] as String?;
      vehicleMake = d['vehicle_make'] as String?;
      vehicleModel = d['vehicle_model'] as String?;
      vehicleColor = d['vehicle_color'] as String?;
      vehiclePlate = d['vehicle_plate'] as String?;
      driverLat = (d['current_lat'] as num?)?.toDouble();
      driverLng = (d['current_lng'] as num?)?.toDouble();
    } else if (json['driver_name'] != null) {
      driverName = json['driver_name'] as String?;
    }

    String? passengerName;
    String? passengerPhone;
    String? passengerAvatar;
    if (json['passenger'] != null && json['passenger'] is Map) {
      final p = Map<String, dynamic>.from(json['passenger'] as Map);
      passengerName = p['full_name'] as String?;
      passengerPhone = p['phone'] as String?;
      passengerAvatar = p['avatar_url'] as String?;
    } else if (json['passenger_name'] != null) {
      passengerName = json['passenger_name'] as String?;
      passengerPhone = json['passenger_phone'] as String?;
      passengerAvatar = json['passenger_avatar'] as String?;
    }

    final metadata = json['metadata'];

    return TripModel(
      id: json['id'] as String,
      rideReference: json['ride_reference'] as String? ?? '',
      passengerId: json['passenger_id'] as String,
      passengerName: passengerName,
      passengerPhone: passengerPhone,
      passengerAvatar: passengerAvatar,
      driverId: json['driver_id'] as String?,
      driverName: driverName,
      driverPhone: driverPhone,
      driverAvatar: driverAvatar,
      vehicleMake: vehicleMake,
      vehicleModel: vehicleModel,
      vehicleColor: vehicleColor,
      vehiclePlate: vehiclePlate,
      driverLat: driverLat,
      driverLng: driverLng,
      origin: json['origin'] as String? ?? 'Pickup Location',
      destination: json['destination'] as String? ?? 'Destination',
      status: TripStatusX.fromDbString(
        json['status'] as String? ?? 'requested',
      ),
      fare: (json['fare'] as num?)?.toDouble() ?? 0.0,
      rideType: json['ride_type'] as String? ?? 'TRYP Go',
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      pinCode: metadata is Map ? metadata['pin_code']?.toString() ?? '' : '',
      additionalPassengers:
          (json['additional_passengers'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      requestedAt:
          DateTime.tryParse(json['requested_at'] as String? ?? '') ??
          DateTime.now(),
      scheduledFor: json['scheduled_for'] != null
          ? DateTime.tryParse(json['scheduled_for'] as String)
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
      driverCompleted: json['driver_completed'] as bool? ?? false,
      passengerCompleted: json['passenger_completed'] as bool? ?? false,
    );
  }

  String get vehicleDescription {
    final parts = [
      vehicleColor,
      vehicleMake,
      vehicleModel,
    ].where((p) => p != null && p.isNotEmpty).join(' ');
    if (parts.isEmpty) return 'TRYP Vehicle';
    if (vehiclePlate != null && vehiclePlate!.isNotEmpty) {
      return '$parts ($vehiclePlate)';
    }
    return parts;
  }

  bool get canPassengerCancel =>
      status == TripStatus.requested || status == TripStatus.accepted;

  int get totalPassengers => additionalPassengers + 1;

  TripModel copyWith({
    String? id,
    String? rideReference,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    String? passengerAvatar,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverAvatar,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleColor,
    String? vehiclePlate,
    double? driverLat,
    double? driverLng,
    String? origin,
    String? destination,
    TripStatus? status,
    double? fare,
    String? rideType,
    String? paymentMethod,
    String? paymentStatus,
    String? pinCode,
    int? additionalPassengers,
    double? distanceKm,
    double? pickupLat,
    double? pickupLng,
    double? destLat,
    double? destLng,
    DateTime? requestedAt,
    DateTime? scheduledFor,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    bool? driverCompleted,
    bool? passengerCompleted,
  }) {
    return TripModel(
      id: id ?? this.id,
      rideReference: rideReference ?? this.rideReference,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      passengerAvatar: passengerAvatar ?? this.passengerAvatar,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverAvatar: driverAvatar ?? this.driverAvatar,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      status: status ?? this.status,
      fare: fare ?? this.fare,
      rideType: rideType ?? this.rideType,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      pinCode: pinCode ?? this.pinCode,
      additionalPassengers: additionalPassengers ?? this.additionalPassengers,
      distanceKm: distanceKm ?? this.distanceKm,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
      requestedAt: requestedAt ?? this.requestedAt,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      driverCompleted: driverCompleted ?? this.driverCompleted,
      passengerCompleted: passengerCompleted ?? this.passengerCompleted,
    );
  }
}

class RideChatMessage {
  final String id;
  final String rideId;
  final String senderId;
  final String body;
  final DateTime createdAt;

  const RideChatMessage({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory RideChatMessage.fromJson(Map<String, dynamic> json) {
    return RideChatMessage(
      id: json['id'] as String,
      rideId: json['ride_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['message'] as String,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
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

  /// Fetch user profile details
  Future<UserProfileModel?> getUserProfile(String userId) async {
    try {
      final res = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (res == null) return null;
      return UserProfileModel.fromJson(res);
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  /// Fetch all trips for the currently authenticated passenger
  Future<List<TripModel>> getPassengerTrips() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _supabase
          .from('rides')
          .select('*, driver:driver_id(*)')
          .eq('passenger_id', user.id)
          .order('requested_at', ascending: false);

      final list = response as List<dynamic>;
      return list
          .map((item) => TripModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching passenger trips: $e');
      rethrow;
    }
  }

  /// Create a new ride request in Supabase
  Future<TripModel> requestRide({
    required String origin,
    required String destination,
    required double fare,
    required String rideType,
    required String paymentMethod,
    required double distanceKm,
    double durationMins = 0,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
    DateTime? scheduledFor,
    int additionalPassengers = 0,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('requestRide called without an authenticated user.');
    }
    final pinCode = _generatePinCode();
    final rideId = await _supabase.rpc(
      'dispatch_ride',
      params: {
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'p_passenger_id': user.id,
        'p_origin': origin,
        'p_destination': destination,
        'dest_lat': destLat,
        'dest_lng': destLng,
        'p_ride_type': rideType,
        'p_fare': fare,
        'p_payment_method': paymentMethod,
        'p_distance_km': distanceKm,
        'p_duration_mins': durationMins,
        'p_metadata': {'pin_code': pinCode},
        'p_scheduled_for': scheduledFor?.toUtc().toIso8601String(),
        'p_additional_passengers': additionalPassengers,
      },
    );

    final trip = await getTripById(rideId as String);
    if (trip == null) {
      throw StateError('Ride was created but could not be loaded.');
    }
    return trip;
  }

  /// Fetch open ride requests that this driver has not declined.
  Future<List<TripModel>> getOpenRideRequests() async {
    try {
      final response = await _supabase
          .from('available_rides_for_driver')
          .select()
          .order('requested_at', ascending: false);

      final rides = response as List<dynamic>;
      return rides
          .map(
            (item) =>
                TripModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching open ride requests: $e');
      return [];
    }
  }

  /// Persist a driver's decline so the request is not shown to that driver again.
  Future<bool> declineRide(String rideId) async {
    try {
      await _supabase.rpc('decline_ride', params: {'p_ride_id': rideId});
      return true;
    } catch (e) {
      debugPrint('Error declining ride: $e');
      return false;
    }
  }

  /// Driver accepts a ride request
  Future<TripModel?> acceptRide(String rideId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      // Acceptance must stay inside the database RPC. It locks the ride row,
      // validates the driver's eligibility, and prevents two drivers from
      // claiming the same request concurrently.
      await _supabase.rpc('accept_ride', params: {'p_ride_id': rideId});

      return getTripById(rideId);
    } catch (e) {
      debugPrint('Error accepting ride: $e');
      return null;
    }
  }

  /// Driver updates availability and location in Supabase
  Future<void> updateDriverLocation({
    required double lat,
    required double lng,
    double heading = 0.0,
    bool isOnline = true,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({
            'current_lat': lat,
            'current_lng': lng,
            'heading': heading,
            'is_online': isOnline,
            'last_location_update': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Error updating driver location: $e');
    }
  }

  /// Driver toggles online/offline status
  Future<void> setDriverOnlineStatus(bool isOnline) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({
            'is_online': isOnline,
            if (isOnline)
              'last_location_update': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (e) {
      debugPrint('Error toggling online status: $e');
    }
  }

  /// Fetch active trip for current driver
  Future<TripModel?> getDriverActiveTrip() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('rides')
          .select('*, passenger:passenger_id(*), driver:driver_id(*)')
          .eq('driver_id', user.id)
          .inFilter('status', ['accepted', 'arrived', 'in_trip'])
          .order('requested_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return TripModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching driver active trip: $e');
      return null;
    }
  }

  /// Fetch a ride by ID, including participant/profile data when permitted.
  ///
  /// Completed rides may no longer permit reading the counterparty profile
  /// under the privacy policies. The ride itself is still readable by its
  /// participants, so fall back to the base ride row for completion screens.
  Future<TripModel?> getTripById(String rideId) async {
    try {
      final response = await _supabase
          .from('rides')
          .select('*, passenger:passenger_id(*), driver:driver_id(*)')
          .eq('id', rideId)
          .maybeSingle();
      if (response != null) return TripModel.fromJson(response);
    } catch (e) {
      debugPrint('Profile join unavailable for ride $rideId: $e');
    }

    try {
      final response = await _supabase
          .from('rides')
          .select()
          .eq('id', rideId)
          .maybeSingle();
      if (response == null) return null;
      return TripModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching ride $rideId: $e');
      return null;
    }
  }

  /// Fetch active trip for current passenger
  Future<TripModel?> getPassengerActiveTrip() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('rides')
          .select('*, passenger:passenger_id(*), driver:driver_id(*)')
          .eq('passenger_id', user.id)
          .inFilter('status', ['requested', 'accepted', 'arrived', 'in_trip'])
          .order('requested_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return TripModel.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching passenger active trip: $e');
      return null;
    }
  }

  /// Load the temporary conversation for an active ride.
  Future<List<RideChatMessage>> getRideMessages(String rideId) async {
    try {
      final response = await _supabase
          .from('ride_messages')
          .select('id, ride_id, sender_id, message, created_at')
          .eq('ride_id', rideId)
          .order('created_at', ascending: true);
      return (response as List<dynamic>)
          .map(
            (item) => RideChatMessage.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('Error loading ride chat: $e');
      return [];
    }
  }

  /// Send a message as the currently authenticated ride participant.
  Future<RideChatMessage?> sendRideMessage({
    required String rideId,
    required String message,
  }) async {
    final user = _supabase.auth.currentUser;
    final body = message.trim();
    if (user == null || body.isEmpty) return null;

    try {
      final response = await _supabase
          .from('ride_messages')
          .insert({'ride_id': rideId, 'sender_id': user.id, 'message': body})
          .select('id, ride_id, sender_id, message, created_at')
          .single();
      return RideChatMessage.fromJson(response);
    } catch (e) {
      debugPrint('Error sending ride chat message: $e');
      return null;
    }
  }

  /// Realtime stream for temporary messages in an active ride.
  RealtimeChannel subscribeToRideMessages({
    required String rideId,
    required void Function(RideChatMessage message) onMessage,
  }) {
    final channel = _supabase.channel('public:ride_messages:ride_id=$rideId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'ride_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_id',
            value: rideId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onMessage(RideChatMessage.fromJson(payload.newRecord));
            }
          },
        )
        .subscribe();
    return channel;
  }

  /// Atomically cancel a passenger ride whose online payment is not settled.
  /// The server locks the ride and refuses to cancel a paid transaction.
  Future<String?> cancelUnpaidRidePayment(String rideId) async {
    try {
      final result = await _supabase.rpc(
        'cancel_unpaid_ride_payment',
        params: {'p_ride_id': rideId},
      );
      return result as String?;
    } catch (e) {
      debugPrint('Error cancelling unpaid ride payment: $e');
      return null;
    }
  }

  /// Update a ride through the backend-enforced status transition rules.
  Future<TripModel?> updateTripStatus({
    required String rideId,
    required TripStatus status,
    String? driverId,
  }) async {
    try {
      await _supabase.rpc(
        'transition_ride_status',
        params: {'p_ride_id': rideId, 'p_next_status': status.toDbString()},
      );
      return getTripById(rideId);
    } catch (e) {
      debugPrint('Error updating trip status: $e');
      return null;
    }
  }

  Future<TripModel> _getCompletedTrip(String rideId) async {
    Object? lastError;

    // The status update and the follow-up read can complete on different
    // realtime/database paths. Retry the read briefly before reporting failure.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final trip = await getTripById(rideId);
        if (trip == null) {
          throw StateError('Completed ride details were not found.');
        }
        if (trip.status != TripStatus.completed) {
          throw StateError(
            'The ride status is still ${trip.status.toDbString()}.',
          );
        }
        return trip;
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }

    throw StateError(
      'Ride completion was submitted, but the completed ride details could not be loaded: $lastError',
    );
  }

  /// Complete an in-progress ride from the assigned driver's account.
  /// The server rejects passenger completion attempts.
  Future<TripModel?> completeRide({
    required String rideId,
    String actor = 'driver',
  }) async {
    try {
      await _supabase.rpc(
        'complete_ride',
        params: {'p_ride_id': rideId, 'p_actor': actor},
      );
      return await _getCompletedTrip(rideId);
    } catch (e) {
      debugPrint('Error completing ride: $e');
      rethrow;
    }
  }

  /// Submit or update the current user's rating for a completed ride.
  Future<bool> submitRating({
    required String rideId,
    required int rating,
    String? review,
  }) async {
    try {
      await _supabase.rpc(
        'submit_ride_rating',
        params: {'p_ride_id': rideId, 'p_rating': rating, 'p_review': review},
      );
      return true;
    } catch (e) {
      debugPrint('Error submitting ride rating: $e');
      return false;
    }
  }

  /// Update the payment state for a ride through the backend payment guard.
  Future<bool> setPaymentStatus({
    required String rideId,
    required String status,
    String? reference,
  }) async {
    try {
      await _supabase.rpc(
        'set_ride_payment_status',
        params: {
          'p_ride_id': rideId,
          'p_status': status,
          'p_reference': reference,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error updating ride payment status: $e');
      return false;
    }
  }

  /// Report a safety incident for the current ride/user.
  Future<bool> createSafetyIncident({
    String? rideId,
    String incidentType = 'emergency',
    String? message,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _supabase.rpc(
        'create_safety_incident',
        params: {
          'p_ride_id': rideId,
          'p_incident_type': incidentType,
          'p_message': message,
          'p_latitude': latitude,
          'p_longitude': longitude,
        },
      );
      return true;
    } catch (e) {
      debugPrint('Error creating safety incident: $e');
      return false;
    }
  }

  /// Fetch online drivers in the passenger's service area and nearby radius.
  Future<List<UserProfileModel>> getOnlineDrivers({
    double? pickupLat,
    double? pickupLng,
    double radiusKm = 5,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final passengerProfile = await _supabase
          .from('profiles')
          .select('service_area')
          .eq('id', user.id)
          .maybeSingle();
      final serviceArea = passengerProfile?['service_area'] as String?;
      if (serviceArea == null || serviceArea.isEmpty) return [];

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'driver')
          .eq('is_online', true)
          .eq('service_area', serviceArea);

      final drivers = (response as List<dynamic>)
          .map((e) => UserProfileModel.fromJson(e as Map<String, dynamic>))
          .where(
            (driver) => driver.currentLat != null && driver.currentLng != null,
          )
          .toList();

      if (pickupLat == null || pickupLng == null) return drivers;

      return drivers.where((driver) {
        final latDelta = (driver.currentLat! - pickupLat) * pi / 180;
        final lngDelta = (driver.currentLng! - pickupLng) * pi / 180;
        final lat1 = pickupLat * pi / 180;
        final lat2 = driver.currentLat! * pi / 180;
        final haversine =
            pow(sin(latDelta / 2), 2) +
            cos(lat1) * cos(lat2) * pow(sin(lngDelta / 2), 2);
        final distanceKm =
            6371 * 2 * atan2(sqrt(haversine), sqrt(1 - haversine));
        return distanceKm <= radiusKm;
      }).toList();
    } catch (e) {
      debugPrint('Error fetching nearby service-area drivers: $e');
      return [];
    }
  }

  /// Realtime Stream for Active Ride by Ride ID
  RealtimeChannel subscribeToRide({
    required String rideId,
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    final channel = _supabase.channel('public:rides:id=$rideId');
    channel
        .onPostgresChanges(
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
        )
        .subscribe();

    return channel;
  }

  /// Realtime stream for the assigned driver's profile/location.
  RealtimeChannel subscribeToDriverLocation({
    required String driverId,
    required void Function(Map<String, dynamic> profile) onUpdate,
  }) {
    final channel = _supabase.channel('public:profiles:id=$driverId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: driverId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) onUpdate(payload.newRecord);
          },
        )
        .subscribe();
    return channel;
  }

  /// Realtime Stream for Open Ride Requests (Driver side)
  RealtimeChannel subscribeToPendingRides({
    required void Function() onRideCreatedOrUpdated,
  }) {
    final channel = _supabase.channel('public:rides:pending');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rides',
          callback: (payload) {
            onRideCreatedOrUpdated();
          },
        )
        .subscribe();

    return channel;
  }
}

final tripServiceProvider = Provider<TripService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return TripService(supabase);
});

final passengerTripsProvider = FutureProvider.autoDispose<List<TripModel>>((
  ref,
) async {
  final tripService = ref.watch(tripServiceProvider);
  return tripService.getPassengerTrips();
});

class ActiveTripNotifier extends Notifier<TripModel?> {
  @override
  TripModel? build() => null;

  set stateTrip(TripModel? trip) => state = trip;
}

final activeTripStateProvider =
    NotifierProvider<ActiveTripNotifier, TripModel?>(ActiveTripNotifier.new);
