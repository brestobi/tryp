import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/core/services/document_storage_service.dart';
import 'package:tryp_driver/core/services/supabase_service.dart';
import 'package:tryp_driver/features/driver/domain/models/driver_onboarding_config.dart';

class DriverOnboardingRepository {
  final SupabaseClient _supabase;
  final DocumentStorageService _storageService;

  DriverOnboardingRepository(this._supabase, this._storageService);

  /// Searchable vehicle makes seeded in the driver lookup catalog.
  Future<List<String>> fetchVehicleMakes() async {
    final response = await _supabase.rpc(
      'search_driver_vehicle_makes',
      params: {'p_query': '', 'p_limit': 500},
    );
    return (response as List<dynamic>)
        .map((row) => (row as Map)['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Searchable vehicle colors seeded in the driver lookup catalog.
  Future<List<String>> fetchVehicleColors() async {
    final response = await _supabase.rpc(
      'search_driver_vehicle_colors',
      params: {'p_query': '', 'p_limit': 100},
    );
    return (response as List<dynamic>)
        .map((row) => (row as Map)['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Operating areas seeded for the Tzaneen–The Oaks corridor.
  Future<List<String>> fetchOperatingAreas() async {
    final response = await _supabase.rpc(
      'search_driver_operating_areas',
      params: {'p_query': '', 'p_limit': 100},
    );
    return (response as List<dynamic>)
        .map((row) => (row as Map)['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  /// Fetch full driver onboarding state from Supabase
  Future<DriverOnboardingData> fetchOnboardingData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return const DriverOnboardingData(id: '');
    }

    try {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      final docs = await _supabase
          .from('driver_documents')
          .select()
          .eq('driver_id', user.id);

      final docsList =
          (docs as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

      if (profile != null) {
        final resolvedProfile = Map<String, dynamic>.from(profile);
        final resolvedDocs = <Map<String, dynamic>>[];
        final storage = _storageService;

        for (final docType in DriverOnboardingConfig.requiredDocuments) {
          final key = docType.key;
          final rawPath = resolvedProfile['doc_$key'] as String?;
          final resolvedUrl = await storage.resolveDocumentUrl(rawPath);
          if (resolvedUrl != null) resolvedProfile['doc_$key'] = resolvedUrl;
        }
        for (final doc in docsList) {
          final resolvedDoc = Map<String, dynamic>.from(doc);
          final rawDocumentPath = doc['document_url'] as String?;
          final resolvedDocumentUrl = await storage.resolveDocumentUrl(
            rawDocumentPath,
          );
          resolvedDoc['document_url'] = resolvedDocumentUrl ?? rawDocumentPath;
          resolvedDocs.add(resolvedDoc);
        }

        return DriverOnboardingData.fromProfile(
          resolvedProfile,
          docs: resolvedDocs,
        );
      } else {
        // Create initial default data with user metadata prefilled
        final metaName = user.userMetadata?['full_name'] as String? ?? '';
        final metaPhone = user.phone ?? '';
        return DriverOnboardingData(
          id: user.id,
          fullName: metaName,
          phone: metaPhone,
        );
      }
    } catch (e) {
      debugPrint('Error fetching onboarding data: $e');
      final user = _supabase.auth.currentUser;
      return DriverOnboardingData(id: user?.id ?? '');
    }
  }

  /// Save step profile updates to Supabase
  Future<void> saveProfileData(DriverOnboardingData data) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final payload = data.toProfileJson();
    await _supabase.from('profiles').upsert(payload);
  }

  /// Upload document and update state
  Future<String?> uploadDocument({
    required String docKey,
    required XFile file,
  }) async {
    return await _storageService.uploadDriverDocument(
      docKey: docKey,
      file: file,
    );
  }

  /// Submit driver onboarding application for verification review
  Future<void> submitApplication(DriverOnboardingData data) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final updatedData = data.copyWith(
      driverStatus: DriverVerificationStatus.underReview,
    );

    // Save profile with under_review status
    await _supabase.from('profiles').upsert(updatedData.toProfileJson());
  }
}

/// Provider for repository
final driverOnboardingRepositoryProvider = Provider<DriverOnboardingRepository>(
  (ref) {
    final supabase = ref.watch(supabaseClientProvider);
    final storageService = ref.watch(documentStorageServiceProvider);
    return DriverOnboardingRepository(supabase, storageService);
  },
);

/// Riverpod AsyncNotifier for Driver Onboarding Flow
class DriverOnboardingNotifier extends AsyncNotifier<DriverOnboardingData> {
  @override
  Future<DriverOnboardingData> build() async {
    final repo = ref.watch(driverOnboardingRepositoryProvider);
    return await repo.fetchOnboardingData();
  }

  Future<void> loadData() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(driverOnboardingRepositoryProvider);
      return await repo.fetchOnboardingData();
    });
  }

  Future<void> updatePersonalDetails({
    required String fullName,
    required String phone,
    required String idNumber,
    required String licenseNumber,
    required String operatingCity,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updated = current.copyWith(
      fullName: fullName,
      phone: phone,
      idNumber: idNumber,
      licenseNumber: licenseNumber,
      operatingCity: operatingCity,
    );

    state = AsyncValue.data(updated);
    try {
      final repo = ref.read(driverOnboardingRepositoryProvider);
      await repo.saveProfileData(updated);
    } catch (e) {
      debugPrint('Error saving personal details: $e');
    }
  }

  Future<void> updateVehicleDetails({
    required String make,
    required String model,
    required String year,
    required String color,
    required String plate,
    required String category,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updated = current.copyWith(
      vehicleMake: make,
      vehicleModel: model,
      vehicleYear: year,
      vehicleColor: color,
      vehiclePlate: plate,
      vehicleCategory: category,
    );

    state = AsyncValue.data(updated);
    try {
      final repo = ref.read(driverOnboardingRepositoryProvider);
      await repo.saveProfileData(updated);
    } catch (e) {
      debugPrint('Error saving vehicle details: $e');
    }
  }

  Future<void> updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String branchCode,
    required String accountHolder,
  }) async {
    final current = state.value;
    if (current == null) return;

    final updated = current.copyWith(
      bankName: bankName,
      bankAccountNumber: accountNumber,
      bankBranchCode: branchCode,
      bankAccountHolder: accountHolder,
    );

    state = AsyncValue.data(updated);
    try {
      final repo = ref.read(driverOnboardingRepositoryProvider);
      await repo.saveProfileData(updated);
    } catch (e) {
      debugPrint('Error saving bank details: $e');
    }
  }

  Future<bool> uploadDocument(String docKey, XFile file) async {
    final repo = ref.read(driverOnboardingRepositoryProvider);
    final url = await repo.uploadDocument(docKey: docKey, file: file);
    if (url != null) {
      await loadData();
      return true;
    }
    return false;
  }

  Future<bool> submitApplication() async {
    final current = state.value;
    if (current == null) return false;

    try {
      final repo = ref.read(driverOnboardingRepositoryProvider);
      await repo.submitApplication(current);
      await loadData();
      return true;
    } catch (e) {
      debugPrint('Error submitting application: $e');
      return false;
    }
  }
}

/// Provider for Driver Onboarding State
final driverOnboardingStateProvider =
    AsyncNotifierProvider<DriverOnboardingNotifier, DriverOnboardingData>(
      DriverOnboardingNotifier.new,
    );
