import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/core/services/supabase_service.dart';

class PassengerVerificationService {
  PassengerVerificationService(this._supabase);

  final SupabaseClient _supabase;
  final ImagePicker _picker = ImagePicker();

  static const bucketName = 'passenger-verification';

  Future<XFile?> capturePhoto() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 88,
      );
    } catch (error) {
      debugPrint('Passenger verification camera error: $error');
      return null;
    }
  }

  Future<String> _upload({
    required String userId,
    required String kind,
    required XFile file,
  }) async {
    final extension = file.name.split('.').last.toLowerCase();
    final safeExtension = ['jpg', 'jpeg', 'png', 'webp'].contains(extension)
        ? extension
        : 'jpg';
    final path =
        'passengers/$userId/${kind}_${DateTime.now().microsecondsSinceEpoch}.$safeExtension';
    final bytes = await file.readAsBytes();
    final contentType = safeExtension == 'png' ? 'image/png' : 'image/jpeg';

    await _supabase.storage.from(bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            cacheControl: '3600',
            upsert: false,
          ),
        );
    return path;
  }

  Future<String> submitVerification({
    required XFile idDocument,
    required XFile selfie,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('You must be signed in to verify identity.');

    final idPath = await _upload(
      userId: user.id,
      kind: 'id_card',
      file: idDocument,
    );
    final selfiePath = await _upload(
      userId: user.id,
      kind: 'live_selfie',
      file: selfie,
    );

    final verificationId = await _supabase.rpc(
      'submit_passenger_verification',
      params: {
        'p_id_document_path': idPath,
        'p_selfie_path': selfiePath,
      },
    );
    return verificationId as String;
  }

  Future<bool> isApproved() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    final profile = await _supabase
        .from('profiles')
        .select('passenger_verification_status')
        .eq('id', user.id)
        .maybeSingle();
    return profile?['passenger_verification_status'] == 'approved';
  }

  Future<Map<String, dynamic>?> getCurrentVerification() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final response = await _supabase
        .from('passenger_verifications')
        .select('id, status, review_notes, submitted_at, reviewed_at')
        .eq('passenger_id', user.id)
        .maybeSingle();
    return response;
  }
}

final passengerVerificationServiceProvider =
    Provider<PassengerVerificationService>((ref) {
  return PassengerVerificationService(ref.watch(supabaseClientProvider));
});
