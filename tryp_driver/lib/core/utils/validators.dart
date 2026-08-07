/// Input validation utilities
class Validators {
  /// Validate email format
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate phone number, accepting local and international formats.
  static bool isValidPhone(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^\+?[0-9]+$').hasMatch(normalized)) return false;
    final digitsOnly = normalized.replaceFirst(RegExp(r'^\+'), '');
    return digitsOnly.length >= 10 && digitsOnly.length <= 15;
  }

  /// Validate a South African ID number or an alphanumeric passport number.
  static bool isValidIdOrPassport(String value) {
    final normalized = value.trim().toUpperCase();
    if (RegExp(r'^\d{13}$').hasMatch(normalized)) {
      return _hasValidSaIdChecksum(normalized);
    }
    return RegExp(r'^[A-Z0-9]{6,20}$').hasMatch(normalized);
  }

  /// Validate a professional driving permit/license identifier.
  static bool isValidLicenseNumber(String value) {
    return RegExp(
      r'^[A-Z0-9][A-Z0-9\-/]{4,19}$',
    ).hasMatch(value.trim().toUpperCase());
  }

  /// Validate a vehicle registration/number plate identifier.
  static bool isValidVehiclePlate(String value) {
    return RegExp(
      r'^[A-Z0-9][A-Z0-9\s-]{2,11}$',
    ).hasMatch(value.trim().toUpperCase());
  }

  /// Validate a four-digit model year within the supported vehicle range.
  static bool isValidVehicleYear(String value) {
    final year = int.tryParse(value.trim());
    final currentYear = DateTime.now().year;
    return year != null && year >= 2000 && year <= currentYear;
  }

  /// Validate a South African bank account number.
  static bool isValidAccountNumber(String value) {
    return RegExp(r'^\d{6,14}$').hasMatch(value.trim());
  }

  /// Validate a six-digit branch code.
  static bool isValidBranchCode(String value) {
    return RegExp(r'^\d{6}$').hasMatch(value.trim());
  }

  static bool _hasValidSaIdChecksum(String idNumber) {
    // South African IDs sum digits in odd positions, then double the
    // concatenated even-position digits and sum the resulting digits.
    var oddPositionSum = 0;
    final evenPositionDigits = StringBuffer();
    for (var i = 0; i < 12; i++) {
      final digit = idNumber.codeUnitAt(i) - 48;
      if (i.isEven) {
        oddPositionSum += digit;
      } else {
        evenPositionDigits.write(digit);
      }
    }

    final doubledEven = int.parse(evenPositionDigits.toString()) * 2;
    final doubledDigitSum = doubledEven
        .toString()
        .split('')
        .fold<int>(0, (sum, digit) => sum + int.parse(digit));
    final checkDigit = (10 - ((oddPositionSum + doubledDigitSum) % 10)) % 10;
    return checkDigit == int.parse(idNumber[12]);
  }

  /// Validate password strength
  static bool isStrongPassword(String password) {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 digit
    final regex = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d@$!%*?&]{8,}$',
    );
    return regex.hasMatch(password);
  }

  /// Validate password minimum length
  static bool isValidPasswordLength(String password) {
    return password.length >= 8;
  }

  /// Validate that two passwords match
  static bool passwordsMatch(String password, String confirmPassword) {
    return password == confirmPassword;
  }

  /// Validate required field
  static bool isNotEmpty(String? value) {
    return value != null && value.isNotEmpty;
  }

  /// Get password strength indicator (0-4)
  static int getPasswordStrength(String password) {
    int strength = 0;

    if (password.isEmpty) return 0;
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[A-Z]').hasMatch(password))
      strength++;
    if (RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password))
      strength++;

    return strength;
  }
}
