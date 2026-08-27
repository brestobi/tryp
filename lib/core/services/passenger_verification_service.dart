import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/core/services/camera_permission_service.dart';
import 'package:tryp/core/services/supabase_service.dart';

class PassengerVerificationService {
  PassengerVerificationService(this._supabase);

  final SupabaseClient _supabase;
  final ImagePicker _picker = ImagePicker();

  static const bucketName = 'passenger-verification';

  Future<XFile?> capturePhoto() async {
    try {
      if (!await CameraPermissionService.ensureCameraPermission()) {
        return null;
      }
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
    final bytes = await file.readAsBytes();
    final contentType = safeExtension == 'png' ? 'image/png' : 'image/jpeg';

    final uploadResponse = await _supabase.functions.invoke(
      'create-r2-upload',
      body: {
        'kind': kind,
        'fileName': file.name,
        'contentType': contentType,
        'folder': 'passengers',
      },
    );
    final uploadData = Map<String, dynamic>.from(uploadResponse.data as Map);
    final uploadUrl = uploadData['uploadUrl'] as String;
    final objectKey = uploadData['objectKey'] as String;
    final client = HttpClient();
    try {
      final request = await client.putUrl(Uri.parse(uploadUrl));
      request.headers.contentType = ContentType.parse(contentType);
      request.add(bytes);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('R2 upload failed with status ${response.statusCode}');
      }
    } finally {
      client.close();
    }
    return objectKey;
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

  Future<String?> createDocumentDownloadUrl(String objectKey) async {
    if (objectKey.startsWith('http://') || objectKey.startsWith('https://')) {
      return objectKey;
    }
    try {
      final response = await _supabase.functions.invoke(
        'create-r2-download',
        body: {'objectKey': objectKey},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      return data['downloadUrl'] as String?;
    } catch (error) {
      debugPrint('Failed to create R2 download URL: $error');
      return null;
    }
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
