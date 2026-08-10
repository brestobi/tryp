import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/core/services/ride_request_readiness.dart';

void main() {
  group('canRequestTrip', () {
    test('stays disabled while map calculations are incomplete', () {
      expect(
        canRequestTrip(
          mapCalculationComplete: false,
          fare: 85,
          isLoading: false,
        ),
        isFalse,
      );
    });

    test('stays disabled until a valid fare is available', () {
      expect(
        canRequestTrip(
          mapCalculationComplete: true,
          fare: null,
          isLoading: false,
        ),
        isFalse,
      );
      expect(
        canRequestTrip(mapCalculationComplete: true, fare: 0, isLoading: false),
        isFalse,
      );
    });

    test('is enabled only when calculations and fare are ready', () {
      expect(
        canRequestTrip(
          mapCalculationComplete: true,
          fare: 85,
          isLoading: false,
        ),
        isTrue,
      );
      expect(
        canRequestTrip(mapCalculationComplete: true, fare: 85, isLoading: true),
        isFalse,
      );
    });
  });
}
