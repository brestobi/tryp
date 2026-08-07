import 'package:flutter/material.dart';
import 'package:tryp_driver/core/utils/validators.dart';

/// Vehicle Category Configuration
class VehicleCategoryInfo {
  final String id;
  final String name;
  final String description;
  final int capacity;
  final IconData icon;

  const VehicleCategoryInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.capacity,
    required this.icon,
  });
}

/// South African Bank Configuration
class BankInfo {
  final String id;
  final String name;
  final String defaultBranchCode;

  const BankInfo({
    required this.id,
    required this.name,
    required this.defaultBranchCode,
  });
}

/// Verification Document Requirement Configuration
class RequiredDocumentType {
  final String key;
  final String title;
  final String description;
  final String requirement;
  final IconData icon;

  const RequiredDocumentType({
    required this.key,
    required this.title,
    required this.description,
    required this.requirement,
    required this.icon,
  });
}

/// Driver Verification Status Enum / Constants
class DriverVerificationStatus {
  static const String pending = 'pending';
  static const String underReview = 'under_review';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// Master Configurations for Driver Verification
class DriverOnboardingConfig {
  static const List<String> operatingCities = [
    'Johannesburg',
    'Pretoria / Tshwane',
    'Cape Town',
    'Durban / eThekwini',
    'Gqeberha (Port Elizabeth)',
    'Bloemfontein',
    'Polokwane',
    'Nelspruit / Mbombela',
  ];

  static const List<VehicleCategoryInfo> vehicleCategories = [
    VehicleCategoryInfo(
      id: 'TRYP Go',
      name: 'TRYP Go',
      description: 'Affordable everyday rides (Compact & Hatchback)',
      capacity: 4,
      icon: Icons.directions_car_rounded,
    ),
    VehicleCategoryInfo(
      id: 'TRYP Comfort',
      name: 'TRYP Comfort',
      description: 'Spacious sedans with top-rated drivers',
      capacity: 4,
      icon: Icons.local_taxi_rounded,
    ),
    VehicleCategoryInfo(
      id: 'TRYP XL',
      name: 'TRYP XL',
      description: 'SUVs & Minivans for groups up to 6 passengers',
      capacity: 6,
      icon: Icons.airport_shuttle_rounded,
    ),
    VehicleCategoryInfo(
      id: 'TRYP Exec',
      name: 'TRYP Exec',
      description: 'Premium luxury vehicles for executive travel',
      capacity: 4,
      icon: Icons.workspace_premium_rounded,
    ),
  ];

  static const List<BankInfo> supportedBanks = [
    BankInfo(
      id: 'fnb',
      name: 'FNB (First National Bank)',
      defaultBranchCode: '250655',
    ),
    BankInfo(id: 'capitec', name: 'Capitec Bank', defaultBranchCode: '470010'),
    BankInfo(
      id: 'standard_bank',
      name: 'Standard Bank',
      defaultBranchCode: '051001',
    ),
    BankInfo(id: 'absa', name: 'Absa Bank', defaultBranchCode: '632005'),
    BankInfo(id: 'nedbank', name: 'Nedbank', defaultBranchCode: '198765'),
    BankInfo(id: 'tymebank', name: 'TymeBank', defaultBranchCode: '678910'),
    BankInfo(
      id: 'discovery',
      name: 'Discovery Bank',
      defaultBranchCode: '679000',
    ),
    BankInfo(id: 'bank_zero', name: 'Bank Zero', defaultBranchCode: '888000'),
  ];

  static const List<String> vehicleColors = [
    'Black',
    'White',
    'Silver',
    'Grey',
    'Blue',
    'Red',
    'Green',
    'Brown',
    'Gold',
    'Other',
  ];

  static List<String> get vehicleYears {
    final currentYear = DateTime.now().year;
    return [for (var year = currentYear; year >= 2000; year--) year.toString()];
  }

  static const List<RequiredDocumentType> requiredDocuments = [
    RequiredDocumentType(
      key: 'selfie',
      title: 'Live Selfie Verification',
      description: 'A live face photo captured in the app',
      requirement:
          'Use the front camera. Remove sunglasses and make sure your face is clearly visible.',
      icon: Icons.face_retouching_natural_rounded,
    ),
    RequiredDocumentType(
      key: 'prdp',
      title: 'PrDP Driver\'s License',
      description: 'Professional Driving Permit for South Africa',
      requirement:
          'Front & back clear photo scan. License card must be valid and unexpired.',
      icon: Icons.badge_rounded,
    ),
    RequiredDocumentType(
      key: 'vehicle_registration',
      title: 'Vehicle Registration (RC)',
      description: 'Official vehicle logbook document',
      requirement:
          'Page showing VIN, engine number, and registered owner details.',
      icon: Icons.directions_car_rounded,
    ),
    RequiredDocumentType(
      key: 'insurance',
      title: 'Commercial E-Hailing Insurance',
      description: 'Passenger liability insurance policy cover',
      requirement:
          'Policy schedule showing active coverage for commercial passenger transport.',
      icon: Icons.shield_rounded,
    ),
    RequiredDocumentType(
      key: 'roadworthiness',
      title: 'Certificate of Roadworthiness',
      description: 'DEKRA or approved SABS inspection slip',
      requirement:
          'Must be issued within the last 12 months for safety compliance.',
      icon: Icons.verified_rounded,
    ),
  ];
}

/// Comprehensive Driver Onboarding State Model
class DriverOnboardingData {
  final String id;
  final String fullName;
  final String phone;
  final String idNumber;
  final String licenseNumber;
  final String operatingCity;

  final String vehicleMake;
  final String vehicleModel;
  final String vehicleYear;
  final String vehicleColor;
  final String vehiclePlate;
  final String vehicleCategory;

  final String bankName;
  final String bankAccountNumber;
  final String bankBranchCode;
  final String bankAccountHolder;

  final String driverStatus; // pending, under_review, approved, rejected
  final Map<String, String?> documentUrls; // key -> url
  final Map<String, String> documentStatuses; // key -> status

  final String? updatedAt;

  const DriverOnboardingData({
    required this.id,
    this.fullName = '',
    this.phone = '',
    this.idNumber = '',
    this.licenseNumber = '',
    this.operatingCity = 'Johannesburg',
    this.vehicleMake = '',
    this.vehicleModel = '',
    this.vehicleYear = '',
    this.vehicleColor = '',
    this.vehiclePlate = '',
    this.vehicleCategory = 'TRYP Go',
    this.bankName = 'FNB (First National Bank)',
    this.bankAccountNumber = '',
    this.bankBranchCode = '',
    this.bankAccountHolder = '',
    this.driverStatus = DriverVerificationStatus.pending,
    this.documentUrls = const {},
    this.documentStatuses = const {},
    this.updatedAt,
  });

  factory DriverOnboardingData.fromProfile(
    Map<String, dynamic> json, {
    List<Map<String, dynamic>>? docs,
  }) {
    final docUrlsMap = <String, String?>{};
    final docStatusMap = <String, String>{};

    for (final docType in DriverOnboardingConfig.requiredDocuments) {
      final key = docType.key;
      docUrlsMap[key] = json['doc_$key'] as String?;
      docStatusMap[key] =
          (json['doc_${key}_status'] as String?) ??
          (docUrlsMap[key] != null ? 'pending' : 'not_uploaded');
    }

    if (docs != null && docs.isNotEmpty) {
      for (final doc in docs) {
        final rawType = doc['document_type'] as String?;
        final url = doc['document_url'] as String?;
        final status = doc['status'] as String? ?? 'pending';

        if (rawType != null) {
          String key = rawType;
          if (rawType == 'prdp_license') key = 'prdp';

          docUrlsMap[key] = url;
          docStatusMap[key] = status;
        }
      }
    }

    return DriverOnboardingData(
      id: (json['id'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      phone:
          (json['phone_number'] as String?) ?? (json['phone'] as String?) ?? '',
      idNumber: (json['id_number'] as String?) ?? '',
      licenseNumber: (json['license_number'] as String?) ?? '',
      operatingCity: (json['operating_city'] as String?) ?? 'Johannesburg',
      vehicleMake: (json['vehicle_make'] as String?) ?? '',
      vehicleModel: (json['vehicle_model'] as String?) ?? '',
      vehicleYear: (json['vehicle_year'] as String?) ?? '',
      vehicleColor: (json['vehicle_color'] as String?) ?? '',
      vehiclePlate: (json['vehicle_plate'] as String?) ?? '',
      vehicleCategory: (json['vehicle_category'] as String?) ?? 'TRYP Go',
      bankName: (json['bank_name'] as String?) ?? 'FNB (First National Bank)',
      bankAccountNumber: (json['bank_account_number'] as String?) ?? '',
      bankBranchCode: (json['bank_branch_code'] as String?) ?? '',
      bankAccountHolder: (json['bank_account_holder'] as String?) ?? '',
      driverStatus:
          (json['driver_status'] as String?) ??
          DriverVerificationStatus.pending,
      documentUrls: docUrlsMap,
      documentStatuses: docStatusMap,
      updatedAt: json['updated_at'] as String?,
    );
  }

  Map<String, dynamic> toProfileJson() {
    return {
      'id': id,
      'role': 'driver',
      'full_name': fullName,
      'phone_number': phone,
      'id_number': idNumber,
      'license_number': licenseNumber,
      'operating_city': operatingCity,
      'vehicle_make': vehicleMake,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
      'vehicle_plate': vehiclePlate,
      'vehicle_category': vehicleCategory,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_branch_code': bankBranchCode,
      'bank_account_holder': bankAccountHolder,
      'driver_status': driverStatus,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  DriverOnboardingData copyWith({
    String? fullName,
    String? phone,
    String? idNumber,
    String? licenseNumber,
    String? operatingCity,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleYear,
    String? vehicleColor,
    String? vehiclePlate,
    String? vehicleCategory,
    String? bankName,
    String? bankAccountNumber,
    String? bankBranchCode,
    String? bankAccountHolder,
    String? driverStatus,
    Map<String, String?>? documentUrls,
    Map<String, String>? documentStatuses,
  }) {
    return DriverOnboardingData(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      idNumber: idNumber ?? this.idNumber,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      operatingCity: operatingCity ?? this.operatingCity,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleCategory: vehicleCategory ?? this.vehicleCategory,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankBranchCode: bankBranchCode ?? this.bankBranchCode,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      driverStatus: driverStatus ?? this.driverStatus,
      documentUrls: documentUrls ?? Map.from(this.documentUrls),
      documentStatuses: documentStatuses ?? Map.from(this.documentStatuses),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  bool get isPersonalDetailsComplete =>
      fullName.trim().length >= 3 &&
      Validators.isValidPhone(phone) &&
      Validators.isValidIdOrPassport(idNumber) &&
      Validators.isValidLicenseNumber(licenseNumber) &&
      operatingCity.trim().isNotEmpty;

  bool get isVehicleDetailsComplete =>
      vehicleMake.trim().length >= 2 &&
      vehicleModel.trim().length >= 2 &&
      Validators.isValidVehicleYear(vehicleYear) &&
      DriverOnboardingConfig.vehicleColors.contains(vehicleColor) &&
      Validators.isValidVehiclePlate(vehiclePlate) &&
      DriverOnboardingConfig.vehicleCategories.any(
        (category) => category.id == vehicleCategory,
      );

  bool get isBankDetailsComplete =>
      DriverOnboardingConfig.supportedBanks.any(
        (bank) => bank.name == bankName,
      ) &&
      Validators.isValidAccountNumber(bankAccountNumber) &&
      Validators.isValidBranchCode(bankBranchCode) &&
      bankAccountHolder.trim().length >= 3;

  bool get areAllDocumentsUploaded {
    for (final doc in DriverOnboardingConfig.requiredDocuments) {
      final url = documentUrls[doc.key];
      if (url == null || url.isEmpty) return false;
    }
    return true;
  }
}
