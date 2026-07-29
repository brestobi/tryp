import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/core/services/supabase_service.dart';

class DocumentStorageService {
  final SupabaseClient _supabase;
  final ImagePicker _picker = ImagePicker();

  static const String bucketName = 'driver-documents';

  DocumentStorageService(this._supabase);

  /// Ensure the 'driver-documents' bucket exists in Supabase Storage
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
      debugPrint('ℹ️ Supabase bucket check/creation note: $e');
    }
  }

  /// Pick document image from Camera or Gallery
  Future<XFile?> pickDocumentImage({ImageSource source = ImageSource.gallery}) async {
    try {
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

  /// Upload document to Supabase Storage and update profiles table
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
      final fileExt = file.name.split('.').last.toLowerCase();
      final path = 'drivers/${user.id}/${docKey}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      debugPrint('📤 Uploading document to Supabase Storage: $path');

      await _supabase.storage.from(bucketName).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: 'image/${fileExt == "png" ? "png" : "jpeg"}',
            ),
          );

      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(path);
      debugPrint('✅ Document uploaded successfully. Public URL: $publicUrl');

      // Update document metadata in user's profile table
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'doc_$docKey': publicUrl,
        'doc_${docKey}_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      });

      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error uploading document to Supabase Storage: $e');
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
