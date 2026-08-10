class DriverWalletModel {
  final String driverId;
  final double cashCollected;
  final double onlineHeld;
  final double cashPlatformFeeOwed;
  final double platformFeesTotal;
  final DateTime updatedAt;

  const DriverWalletModel({
    required this.driverId,
    required this.cashCollected,
    required this.onlineHeld,
    required this.cashPlatformFeeOwed,
    required this.platformFeesTotal,
    required this.updatedAt,
  });

  /// Gross cash plus online funds held by TRYP, less all recorded platform fees.
  double get netPosition => cashCollected + onlineHeld - platformFeesTotal;

  factory DriverWalletModel.fromJson(Map<String, dynamic> json) {
    return DriverWalletModel(
      driverId: json['driver_id'] as String,
      cashCollected: _number(json['cash_collected']),
      onlineHeld: _number(json['online_held']),
      cashPlatformFeeOwed: _number(json['cash_platform_fee_owed']),
      platformFeesTotal: _number(json['platform_fees_total']),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  static double _number(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class DriverWalletTransactionModel {
  final String id;
  final String rideId;
  final String paymentMethod;
  final double grossAmount;
  final double platformFee;
  final double driverNetAmount;
  final DateTime createdAt;

  const DriverWalletTransactionModel({
    required this.id,
    required this.rideId,
    required this.paymentMethod,
    required this.grossAmount,
    required this.platformFee,
    required this.driverNetAmount,
    required this.createdAt,
  });

  factory DriverWalletTransactionModel.fromJson(Map<String, dynamic> json) {
    double number(Object? value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

    return DriverWalletTransactionModel(
      id: json['id'] as String,
      rideId: json['ride_id'] as String,
      paymentMethod: json['payment_method'] as String? ?? 'Cash',
      grossAmount: number(json['gross_amount']),
      platformFee: number(json['platform_fee']),
      driverNetAmount: number(json['driver_net_amount']),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
