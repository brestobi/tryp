import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/core/services/camera_permission_service.dart';
import 'package:tryp_driver/core/services/supabase_service.dart';

class DocumentStorageService {
  final SupabaseClient _supabase;
  final ImagePicker _picker = ImagePicker();

  static const String bucketName = 'driver-documents';

  DocumentStorageService(this._supabase);

  Future<XFile?> pickDocumentImage({ImageSource source = ImageSource.gallery}) async {
    try {
      if (source == ImageSource.camera && !await CameraPermissionService.ensureCameraPermission()) return null;
      return await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600, maxHeight: 1600);
    } catch (e) {
      debugPrint('❌ Error picking document image: $e');
      return null;
    }
  }

  String _mapDocKeyToDocType(String docKey) {
    switch (docKey) {
      case 'prdp': return 'prdp_license';
      case 'vehicle_registration': return 'vehicle_registration';
      case 'insurance': return 'insurance';
      case 'roadworthiness': return 'roadworthiness';
      case 'selfie': return 'selfie';
      default: return docKey;
    }
  }

  Future<String?> uploadDriverDocument({required String docKey, required XFile file}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    try {
      final bytes = await file.readAsBytes();
      final rawExt = file.name.split('.').last.toLowerCase();
      final fileExt = ['png', 'jpg', 'jpeg', 'webp', 'pdf'].contains(rawExt) ? rawExt : 'jpg';
      final mimeType = fileExt == 'pdf' ? 'application/pdf' : fileExt == 'png' ? 'image/png' : 'image/jpeg';
      final response = await _supabase.functions.invoke('create-r2-upload', body: {
        'kind': docKey,
        'fileName': file.name,
        'contentType': mimeType,
        'folder': 'drivers',
      });
      final data = Map<String, dynamic>.from(response.data as Map);
      final objectKey = data['objectKey'] as String;
      final client = HttpClient();
      try {
        final request = await client.putUrl(Uri.parse(data['uploadUrl'] as String));
        request.headers.contentType = ContentType.parse(mimeType);
        request.headers.contentLength = bytes.length;
        request.add(bytes);
        final result = await request.close();
        if (result.statusCode < 200 || result.statusCode >= 300) throw Exception('R2 upload failed: ${result.statusCode}');
      } finally {
        client.close();
      }

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'doc_$docKey': objectKey,
        'doc_${docKey}_status': 'pending',
        'updated_at': DateTime.now().toIso8601String(),
      });
      await _supabase.from('driver_documents').upsert({
        'driver_id': user.id,
        'document_type': _mapDocKeyToDocType(docKey),
        'document_url': objectKey,
        'storage_provider': 'r2',
        'object_key': objectKey,
        'content_type': mimeType,
        'file_size': bytes.length,
        'status': 'pending',
        'submitted_at': DateTime.now().toIso8601String(),
      }, onConflict: 'driver_id, document_type');
      return objectKey;
    } catch (e, stackTrace) {
      debugPrint('❌ Error uploading document: $e\n$stackTrace');
      return null;
    }
  }

  Future<String?> resolveDocumentUrl(String? objectKey) async {
    if (objectKey == null || objectKey.isEmpty) return null;
    if (objectKey.startsWith('http://') || objectKey.startsWith('https://')) return objectKey;
    try {
      final response = await _supabase.functions.invoke('create-r2-download', body: {'objectKey': objectKey});
      return (response.data as Map)['downloadUrl'] as String?;
    } catch (e) {
      debugPrint('Error creating signed document URL: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchDriverDocumentStatuses() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};
    try {
      final response = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();
      return response ?? {};
    } catch (e) {
      debugPrint('Error fetching driver document statuses: $e');
      return {};
    }
  }
}

final documentStorageServiceProvider = Provider<DocumentStorageService>((ref) => DocumentStorageService(ref.watch(supabaseClientProvider)));
