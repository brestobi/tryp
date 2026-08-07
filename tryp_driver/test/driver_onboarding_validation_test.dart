import 'package:flutter_test/flutter_test.dart';
import 'package:tryp_driver/core/utils/validators.dart';
import 'package:tryp_driver/features/driver/domain/models/driver_onboarding_config.dart';

void main() {
  group('Driver onboarding input validation', () {
    test('accepts valid phone and rejects malformed phone', () {
      expect(Validators.isValidPhone('+27 82 123 4567'), isTrue);
      expect(Validators.isValidPhone('abc 123'), isFalse);
    });

    test('accepts valid South African ID checksum and passport format', () {
      expect(Validators.isValidIdOrPassport('8001015009087'), isTrue);
      expect(Validators.isValidIdOrPassport('A1234567'), isTrue);
      expect(Validators.isValidIdOrPassport('123'), isFalse);
    });

    test('validates vehicle and bank formats', () {
      expect(Validators.isValidVehiclePlate('GP 123 ABC'), isTrue);
      expect(Validators.isValidVehiclePlate('!'), isFalse);
      expect(Validators.isValidVehicleYear('2022'), isTrue);
      expect(Validators.isValidAccountNumber('1234567890'), isTrue);
      expect(Validators.isValidBranchCode('250655'), isTrue);
    });
  });

  test('selfie is a required verification document', () {
    expect(
      DriverOnboardingConfig.requiredDocuments.map((doc) => doc.key),
      contains('selfie'),
    );
    expect(DriverOnboardingConfig.vehicleYears, isNotEmpty);
    expect(DriverOnboardingConfig.vehicleColors, contains('Silver'));
  });
}
