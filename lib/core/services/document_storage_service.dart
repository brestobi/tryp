import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/core/services/camera_permission_service.dart';
import 'package:tryp/core/services/supabase_service.dart';

class DocumentStorageService {
  final SupabaseClient _supabase;
  final ImagePicker _picker = ImagePicker();

  static const String bucketName = 'driver-documents';

  DocumentStorageService(this._supabase);

  /// Safe bucket check — catches non-admin permissions silently
  Future<void> ensureBucketExists() async {
    try {
      final buckets = await _supabase.storage.listBuckets();
      final exists = buckets.any((b) => b.name == bucketName);
      if (!exists) {
        debugPrint('📦 Creating Supabase Storage Bucket: $bucketName');
        await _supabase.storage.createBucket(
          bucketName,
          const BucketOptions(public: true),
        );
      }
    } catch (e) {
      // listBuckets may throw 403 for non-admin users, which is expected
      debugPrint('ℹ️ Supabase bucket check note: $e');
    }
  }

  /// Pick document image from Camera or Gallery
  Future<XFile?> pickDocumentImage({ImageSource source = ImageSource.gallery}) async {
    try {
      if (source == ImageSource.camera &&
          !await CameraPermissionService.ensureCameraPermission()) {
        return null;
      }
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      return image;
    } catch (e) {
      debugPrint('❌ Error picking document image: $e');
      return null;
    }
  }

  /// Map friendly doc keys to official document_type DB names
  String _mapDocKeyToDocType(String docKey) {
    switch (docKey) {
      case 'prdp':
        return 'prdp_license';
      case 'vehicle_registration':
        return 'vehicle_registration';
      case 'insurance':
        return 'insurance';
      case 'roadworthiness':
        return 'roadworthiness';
      default:
        return docKey;
    }
  }

  /// Upload document to Supabase Storage and update profiles & driver_documents tables
  Future<String?> uploadDriverDocument({
    required String docKey, // e.g. 'prdp', 'vehicle_registration', 'insurance', 'roadworthiness'
    required XFile file,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      debugPrint('⚠️ Cannot upload document — user not logged in.');
      return null;
    }

    try {
      await ensureBucketExists();

      final bytes = await file.readAsBytes();
      final rawExt = file.name.split('.').last.toLowerCase();
      final fileExt = (rawExt == 'png' || rawExt == 'jpg' || rawExt == 'jpeg' || rawExt == 'webp' || rawExt == 'pdf') ? rawExt : 'jpg';
      final path = 'drivers/${user.id}/${docKey}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      debugPrint('📤 Uploading document to Supabase Storage: $path');

      final mimeType = fileExt == 'pdf'
          ? 'application/pdf'
          : fileExt == 'png'
              ? 'image/png'
              : 'image/jpeg';

      await _supabase.storage.from(bucketName).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: mimeType,
            ),
          );

      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(path);
      debugPrint('✅ Document uploaded successfully. Public URL: $publicUrl');

      // 1. Update document metadata in user's profile table
      try {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'doc_$docKey': publicUrl,
          'doc_${docKey}_status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Profile table updated successfully.');
      } catch (e) {
        debugPrint('❌ Error updating profiles table: $e');
        rethrow;
      }

      // 2. Insert into driver_documents table for admin inspector view
      final docType = _mapDocKeyToDocType(docKey);
      try {
        await _supabase.from('driver_documents').upsert(
          {
            'driver_id': user.id,
            'document_type': docType,
            'document_url': publicUrl,
            'status': 'pending',
            'submitted_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'driver_id, document_type',
        );
        debugPrint('✅ Driver documents table updated/inserted successfully.');
      } catch (e) {
        debugPrint('❌ Error updating/inserting into driver_documents table: $e');
        rethrow;
      }

      return publicUrl;
    } catch (e, stackTrace) {
      debugPrint('❌ Error uploading document: $e');
      debugPrint('🔍 StackTrace: $stackTrace');
      return null;
    }
  }

  /// Fetch document URLs and verification status for current driver
  Future<Map<String, dynamic>> fetchDriverDocumentStatuses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        return response;
      }
    } catch (e) {
      debugPrint('Error fetching driver document statuses: $e');
    }
    return {};
  }
}

final documentStorageServiceProvider = Provider<DocumentStorageService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return DocumentStorageService(supabase);
});
