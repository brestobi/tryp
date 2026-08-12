import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/core/services/fare_calculator.dart';

void main() {
  group('FareSchema', () {
    test('uses live distance, duration, minimum, and surge rates', () {
      const schema = FareSchema(
        baseFare: 18,
        perKmRate: 6.5,
        minFare: 25,
        perMinuteRate: 1.2,
        extraPersonRate: 10,
        surgeMultiplier: 1.5,
      );

      expect(
        schema.calculateFare(distanceKm: 10, durationMins: 20),
        closeTo((18 + 65 + 24) * 1.5, 0.0001),
      );
      expect(schema.calculateFare(distanceKm: 0, durationMins: 0), 27.0);
      expect(
        schema.calculateFare(
          distanceKm: 10,
          durationMins: 20,
          additionalPassengers: 2,
        ),
        closeTo((18 + 65 + 24) * 1.5 + 20, 0.0001),
      );
    });

    test('maps admin fare schema columns from Supabase JSON', () {
      final schema = FareSchema.fromJson({
        'id': 'schema-comfort',
        'tier': 'TRYP Comfort',
        'base_fare': 28,
        'per_km_rate': 9,
        'min_fare': 40,
        'per_minute_rate': 1.8,
        'extra_person_rate': 12.5,
        'surge_multiplier': 1.25,
        'currency_symbol': 'R',
      });

      expect(schema.id, 'schema-comfort');
      expect(schema.tier, 'TRYP Comfort');
      expect(schema.baseFare, 28);
      expect(schema.perKmRate, 9);
      expect(schema.minFare, 40);
      expect(schema.perMinuteRate, 1.8);
      expect(schema.extraPersonRate, 12.5);
      expect(schema.surgeMultiplier, 1.25);
      expect(schema.currencySymbol, 'R');
    });
  });
}
