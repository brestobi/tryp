import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/routes.dart';

void main() {
  group('Google passenger onboarding routing', () {
    test('new passenger profile without phone goes to profile setup', () {
      expect(
        passengerRouteForGoogleProfile({
          'role': 'passenger',
          'onboarding_completed': false,
        }),
        Routes.profileSetup,
      );
    });

    test('missing completion flag safely goes to profile setup', () {
      expect(
        passengerRouteForGoogleProfile({'role': 'passenger'}),
        Routes.profileSetup,
      );
    });

    test('completed passenger profile goes to passenger home', () {
      expect(
        passengerRouteForGoogleProfile({
          'role': 'passenger',
          'onboarding_completed': true,
        }),
        Routes.passengerHome,
      );
    });

    test('driver profile is not accepted by passenger routing', () {
      expect(
        passengerRouteForGoogleProfile({
          'role': 'driver',
          'onboarding_completed': true,
        }),
        isNull,
      );
    });
  });
}
