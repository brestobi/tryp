import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_profile_screen.dart';

void main() {
  group('passenger profile verification badge', () {
    test('is enabled only for approved verification status', () {
      expect(
        passengerProfileIsApproved({
          'passenger_verification_status': 'approved',
        }),
        isTrue,
      );
    });

    test('is disabled for pending, rejected, and missing status', () {
      expect(
        passengerProfileIsApproved({
          'passenger_verification_status': 'pending',
        }),
        isFalse,
      );
      expect(
        passengerProfileIsApproved({
          'passenger_verification_status': 'rejected',
        }),
        isFalse,
      );
      expect(passengerProfileIsApproved(null), isFalse);
    });
  });
}
