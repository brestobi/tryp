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
      final bytes = await file.readAsBytes();
      final rawExt = file.name.split('.').last.toLowerCase();
      final fileExt = (rawExt == 'png' || rawExt == 'jpg' || rawExt == 'jpeg' || rawExt == 'webp' || rawExt == 'pdf') ? rawExt : 'jpg';
      final path = 'drivers/${user.id}/${docKey}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      debugPrint('📤 Requesting Cloudflare R2 upload URL: $path');

      final mimeType = fileExt == 'pdf'
          ? 'application/pdf'
          : fileExt == 'png'
              ? 'image/png'
              : 'image/jpeg';

      final uploadResponse = await _supabase.functions.invoke(
        'create-r2-upload',
        body: {
          'kind': docKey,
          'fileName': file.name,
          'contentType': mimeType,
          'folder': 'drivers',
        },
      );
      final uploadData = Map<String, dynamic>.from(uploadResponse.data as Map);
      final uploadUrl = uploadData['uploadUrl'] as String;
      final objectKey = uploadData['objectKey'] as String;
      final client = HttpClient();
      try {
        final request = await client.putUrl(Uri.parse(uploadUrl));
        request.headers.contentType = ContentType.parse(mimeType);
        request.headers.contentLength = bytes.length;
        request.add(bytes);
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception('R2 upload failed with status ${response.statusCode}');
        }
      } finally {
        client.close();
      }

      final publicUrl = objectKey;
      debugPrint('✅ Document uploaded successfully to R2: $objectKey');

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

  /// Creates a short-lived signed URL for an R2 object key.
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
    } catch (e) {
      debugPrint('❌ Failed to create R2 download URL: $e');
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
