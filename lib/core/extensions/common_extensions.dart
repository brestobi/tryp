/// String extensions
extension StringExtensions on String {
  /// Check if string is empty or null
  bool get isEmpty => this.isEmpty;

  /// Check if string is not empty
  bool get isNotEmpty => this.isNotEmpty;

  /// Capitalize first letter
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Convert to title case
  String toTitleCase() {
    if (isEmpty) return this;
    return split(' ')
        .map((str) => str.capitalize())
        .join(' ');
  }

  /// Remove all whitespace
  String removeWhitespace() {
    return replaceAll(RegExp(r'\s+'), '');
  }

  /// Check if string contains only digits
  bool get isNumeric {
    final regex = RegExp(r'^[0-9]+$');
    return regex.hasMatch(this);
  }

  /// Check if string contains only letters
  bool get isAlpha {
    final regex = RegExp(r'^[a-zA-Z]+$');
    return regex.hasMatch(this);
  }

  /// Truncate string to max length with ellipsis
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }

  /// Format phone number (basic)
  String formatPhone() {
    final digitsOnly = removeWhitespace();
    if (digitsOnly.length < 10) return digitsOnly;
    if (digitsOnly.length <= 11) {
      return '+${digitsOnly.substring(0, 2)} ${digitsOnly.substring(2, 5)} ${digitsOnly.substring(5, 8)} ${digitsOnly.substring(8)}';
    }
    return this;
  }

  /// Mask sensitive data (show last 4 characters)
  String maskSensitive({int visibleChars = 4}) {
    if (length <= visibleChars) return '*' * length;
    final masked = '*' * (length - visibleChars);
    return '$masked${substring(length - visibleChars)}';
  }
}

/// DateTime extensions
extension DateTimeExtensions on DateTime {
  /// Format as "Jan 15, 2024"
  String toFormattedDate() {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[month - 1]} $day, $year';
  }

  /// Format as "2:30 PM"
  String toFormattedTime() {
    final hour = this.hour > 12 ? this.hour - 12 : this.hour;
    final period = this.hour >= 12 ? 'PM' : 'AM';
    final minute = this.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Get days difference from today
  int daysFromNow() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(year, month, day);
    return date.difference(today).inDays;
  }
}

/// Duration extensions
extension DurationExtensions on Duration {
  /// Format as "2h 30m"
  String toFormattedString() {
    final hours = inHours;
    final minutes = inMinutes.remainder(60);
    if (hours == 0) {
      return '${minutes}m';
    }
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }

  /// Format as "1:30:45" (HH:MM:SS)
  String toTimerFormat() {
    final hours = inHours.toString().padLeft(2, '0');
    final minutes = inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

/// Number extensions
extension NumExtensions on num {
  /// Format as currency
  String toCurrency({String symbol = 'R'}) {
    return '$symbol ${toStringAsFixed(2)}';
  }

  /// Format as percentage
  String toPercentage() {
    return '${(this * 100).toStringAsFixed(2)}%';
  }

  /// Round to decimal places
  num roundToDecimal(int decimal) {
    final fac = pow(10, decimal).toInt();
    return (this * fac).round() / fac;
  }
}

/// Perform pow operation
num pow(num base, num exponent) {
  num result = 1;
  for (int i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
