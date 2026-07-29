class VehicleModel {
  final String id;
  final String driverId;
  final String make;
  final String model;
  final int year;
  final String color;
  final String licensePlate;
  final String tier; // 'TRYP Go', 'TRYP Comfort', 'TRYP XL', 'TRYP Exec'
  final bool isVerified;
  final DateTime? insuranceExpiryDate;
  final DateTime? roadworthinessExpiryDate;

  const VehicleModel({
    required this.id,
    required this.driverId,
    required this.make,
    required this.model,
    required this.year,
    required this.color,
    required this.licensePlate,
    this.tier = 'TRYP Go',
    this.isVerified = false,
    this.insuranceExpiryDate,
    this.roadworthinessExpiryDate,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      make: json['make'] as String? ?? 'Toyota',
      model: json['model'] as String? ?? 'Corolla Quest',
      year: (json['year'] as num?)?.toInt() ?? 2022,
      color: json['color'] as String? ?? 'Silver',
      licensePlate: json['license_plate'] as String? ?? 'ND 123-456',
      tier: json['tier'] as String? ?? 'TRYP Go',
      isVerified: json['is_verified'] as bool? ?? false,
      insuranceExpiryDate: json['insurance_expiry'] != null
          ? DateTime.tryParse(json['insurance_expiry'] as String)
          : null,
      roadworthinessExpiryDate: json['roadworthiness_expiry'] != null
          ? DateTime.tryParse(json['roadworthiness_expiry'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'make': make,
      'model': model,
      'year': year,
      'color': color,
      'license_plate': licensePlate,
      'tier': tier,
      'is_verified': isVerified,
      'insurance_expiry': insuranceExpiryDate?.toIso8601String(),
      'roadworthiness_expiry': roadworthinessExpiryDate?.toIso8601String(),
    };
  }
}
