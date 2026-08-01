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

class UserProfileModel {
  final String id;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final String role;
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
    final parts = [vehicleColor, vehicleMake, vehicleModel].where((p) => p != null && p.isNotEmpty).join(' ');
    if (parts.isEmpty) return 'TRYP Vehicle';
    if (vehiclePlate != null && vehiclePlate!.isNotEmpty) {
      return '$parts ($vehiclePlate)';
    }
    return parts;
  }
}

class TripModel {
  final String id;
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
    final pickupLat = (json['pickup_lat'] as num?)?.toDouble() ?? 0.0;
    final pickupLng = (json['pickup_lng'] as num?)?.toDouble() ?? 0.0;
    final destLat   = (json['dest_lat']   as num?)?.toDouble() ?? 0.0;
    final destLng   = (json['dest_lng']   as num?)?.toDouble() ?? 0.0;

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
      final d = json['driver'] as Map<String, dynamic>;
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
      final p = json['passenger'] as Map<String, dynamic>;
      passengerName = p['full_name'] as String?;
      passengerPhone = p['phone'] as String?;
      passengerAvatar = p['avatar_url'] as String?;
    }

    return TripModel(
      id: json['id'] as String,
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

  String get vehicleDescription {
    final parts = [vehicleColor, vehicleMake, vehicleModel].where((p) => p != null && p.isNotEmpty).join(' ');
    if (parts.isEmpty) return 'TRYP Vehicle';
    if (vehiclePlate != null && vehiclePlate!.isNotEmpty) {
      return '$parts ($vehiclePlate)';
    }
    return parts;
  }

  TripModel copyWith({
    String? id,
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

  /// Fetch user profile details
  Future<UserProfileModel?> getUserProfile(String userId) async {
    try {
      final res = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
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
      return list.map((item) => TripModel.fromJson(item as Map<String, dynamic>)).toList();
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

    final response = await _supabase.from('rides').insert(payload).select('*, passenger:passenger_id(*)').single();
    return TripModel.fromJson(response);
  }

  /// Fetch open ride requests for online drivers
  Future<List<TripModel>> getOpenRideRequests() async {
    try {
      final response = await _supabase
          .from('rides')
          .select('*, passenger:passenger_id(*)')
          .eq('status', 'requested')
          .isFilter('driver_id', null)
          .order('requested_at', ascending: false);

      final list = response as List<dynamic>;
      return list.map((item) => TripModel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching open ride requests: $e');
      return [];
    }
  }

  /// Driver accepts a ride request
  Future<TripModel?> acceptRide(String rideId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      // Try atomic RPC function first
      try {
        final rpcRes = await _supabase.rpc('accept_ride', params: {'p_ride_id': rideId});
        if (rpcRes != null && rpcRes is Map) {
          final fullRide = await _supabase
              .from('rides')
              .select('*, passenger:passenger_id(*), driver:driver_id(*)')
              .eq('id', rideId)
              .single();
          return TripModel.fromJson(fullRide);
        }
      } catch (e) {
        debugPrint('accept_ride RPC failed, using fallback update: $e');
      }

      // Direct update fallback
      final response = await _supabase
          .from('rides')
          .update({
            'driver_id': user.id,
            'status': TripStatus.accepted.toDbString(),
            'accepted_at': DateTime.now().toIso8601String(),
          })
          .eq('id', rideId)
          .eq('status', 'requested')
          .isFilter('driver_id', null)
          .select('*, passenger:passenger_id(*), driver:driver_id(*)')
          .single();

      return TripModel.fromJson(response);
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
      await _supabase.from('profiles').update({
        'current_lat': lat,
        'current_lng': lng,
        'heading': heading,
        'is_online': isOnline,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      debugPrint('Error updating driver location: $e');
    }
  }

  /// Driver toggles online/offline status
  Future<void> setDriverOnlineStatus(bool isOnline) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('profiles').update({
        'is_online': isOnline,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
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
      final response = await _supabase
          .from('rides')
          .update(updates)
          .eq('id', rideId)
          .select('*, passenger:passenger_id(*), driver:driver_id(*)')
          .single();
      return TripModel.fromJson(response);
    } catch (e) {
      debugPrint('Error updating trip status: $e');
      return null;
    }
  }

  /// Fetch online drivers nearby for map plot
  Future<List<UserProfileModel>> getOnlineDrivers() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'driver')
          .eq('is_online', true);

      final list = response as List<dynamic>;
      return list.map((e) => UserProfileModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching online drivers: $e');
      return [];
    }
  }

  /// Realtime Stream for Active Ride by Ride ID
  RealtimeChannel subscribeToRide({
    required String rideId,
    required void Function(Map<String, dynamic> payload) onUpdate,
  }) {
    final channel = _supabase.channel('public:rides:id=$rideId');
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

  /// Realtime Stream for Open Ride Requests (Driver side)
  RealtimeChannel subscribeToPendingRides({
    required void Function() onRideCreatedOrUpdated,
  }) {
    final channel = _supabase.channel('public:rides:pending');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'rides',
      callback: (payload) {
        onRideCreatedOrUpdated();
      },
    ).subscribe();

    return channel;
  }
}

final tripServiceProvider = Provider<TripService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return TripService(supabase);
});

final passengerTripsProvider = FutureProvider.autoDispose<List<TripModel>>((ref) async {
  final tripService = ref.watch(tripServiceProvider);
  return tripService.getPassengerTrips();
});

class ActiveTripNotifier extends Notifier<TripModel?> {
  @override
  TripModel? build() => null;

  set stateTrip(TripModel? trip) => state = trip;
}

final activeTripStateProvider = NotifierProvider<ActiveTripNotifier, TripModel?>(ActiveTripNotifier.new);
