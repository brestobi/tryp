import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/core/services/trip_service.dart';

void main() {
  group('TripStatus lifecycle contract', () {
    test('maps every app status to the backend value', () {
      expect(TripStatus.requested.toDbString(), 'requested');
      expect(TripStatus.accepted.toDbString(), 'accepted');
      expect(TripStatus.arrived.toDbString(), 'arrived');
      expect(TripStatus.inTrip.toDbString(), 'in_trip');
      expect(TripStatus.completed.toDbString(), 'completed');
      expect(TripStatus.cancelled.toDbString(), 'cancelled');
    });

    test('unknown backend values fail safe to requested', () {
      expect(TripStatusX.fromDbString('unexpected'), TripStatus.requested);
    });
  });

  group('TripModel lifecycle contract', () {
    test('parses participant details, safety PIN, and completion flags', () {
      final trip = TripModel.fromJson(_rideJson(status: 'in_trip'));

      expect(trip.id, 'ride-1');
      expect(trip.rideReference, 'T-00001');
      expect(trip.passengerId, 'passenger-1');
      expect(trip.passengerName, 'Passenger One');
      expect(trip.driverId, 'driver-1');
      expect(trip.driverName, 'Driver One');
      expect(trip.vehicleDescription, 'Blue Toyota Corolla (ABC 123)');
      expect(trip.pinCode, '4821');
      expect(trip.status, TripStatus.inTrip);
      expect(trip.driverCompleted, isFalse);
      expect(trip.passengerCompleted, isFalse);
    });

    test('parses an optional scheduled pickup timestamp', () {
      final trip = TripModel.fromJson(
        _rideJson(
          status: 'requested',
          scheduledFor: '2026-08-12T09:30:00.000Z',
        ),
      );

      expect(trip.scheduledFor, DateTime.parse('2026-08-12T09:30:00.000Z'));
    });

    test('preserves completion metadata when status changes locally', () {
      final completed = TripModel.fromJson(
        _rideJson(
          status: 'completed',
          driverCompleted: true,
          passengerCompleted: true,
        ),
      );

      final updated = completed.copyWith(status: TripStatus.completed);

      expect(updated.status, TripStatus.completed);
      expect(updated.driverCompleted, isTrue);
      expect(updated.passengerCompleted, isTrue);
      expect(updated.completedAt, isNotNull);
    });

    test('parses a cancelled ride as terminal and keeps its identity', () {
      final cancelled = TripModel.fromJson(_rideJson(status: 'cancelled'));

      expect(cancelled.status, TripStatus.cancelled);
      expect(cancelled.id, 'ride-1');
      expect(cancelled.passengerId, 'passenger-1');
    });
  });
}

Map<String, dynamic> _rideJson({
  required String status,
  bool driverCompleted = false,
  bool passengerCompleted = false,
  String? scheduledFor,
}) {
  return {
    'id': 'ride-1',
    'ride_reference': 'T-00001',
    'passenger_id': 'passenger-1',
    'driver_id': 'driver-1',
    'origin': 'Pickup Point',
    'destination': 'Destination Point',
    'status': status,
    'fare': 85.50,
    'ride_type': 'TRYP Go',
    'payment_method': 'Cash',
    'payment_status': 'pending',
    'distance_km': 12.5,
    'pickup_lat': -26.1,
    'pickup_lng': 28.0,
    'dest_lat': -26.2,
    'dest_lng': 28.1,
    'requested_at': '2026-08-07T12:00:00.000Z',
    'scheduled_for': scheduledFor,
    'accepted_at': '2026-08-07T12:02:00.000Z',
    'started_at': '2026-08-07T12:15:00.000Z',
    'completed_at': '2026-08-07T12:40:00.000Z',
    'driver_completed': driverCompleted,
    'passenger_completed': passengerCompleted,
    'metadata': {'pin_code': '4821'},
    'passenger': {
      'full_name': 'Passenger One',
      'phone': '+27000000000',
      'avatar_url': null,
    },
    'driver': {
      'full_name': 'Driver One',
      'phone': '+27111111111',
      'avatar_url': null,
      'vehicle_make': 'Toyota',
      'vehicle_model': 'Corolla',
      'vehicle_color': 'Blue',
      'vehicle_plate': 'ABC 123',
      'current_lat': -26.11,
      'current_lng': 28.01,
    },
  };
}
