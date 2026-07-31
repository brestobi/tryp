import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/document_storage_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class DriverDocumentModel {
  final String key;
  final String title;
  final String description;
  final String requirement;
  final String status; // 'approved', 'pending', 'action_required', 'not_uploaded'
  final String? url;
  final IconData icon;

  const DriverDocumentModel({
    required this.key,
    required this.title,
    required this.description,
    required this.requirement,
    required this.status,
    this.url,
    required this.icon,
  });

  DriverDocumentModel copyWith({
    String? status,
    String? url,
  }) {
    return DriverDocumentModel(
      key: key,
      title: title,
      description: description,
      requirement: requirement,
      status: status ?? this.status,
      url: url ?? this.url,
      icon: icon,
    );
  }
}

class DriverDocumentsScreen extends ConsumerStatefulWidget {
  const DriverDocumentsScreen({super.key});

  @override
  ConsumerState<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends ConsumerState<DriverDocumentsScreen> {
  bool _isLoading = true;
  String? _uploadingDocKey;

  List<DriverDocumentModel> _documents = [
    const DriverDocumentModel(
      key: 'prdp',
      title: 'PrDP Driver\'s License',
      description: 'Professional Driving Permit for South Africa',
      requirement: 'Front & back scan. License card must be valid and unexpired.',
      status: 'not_uploaded',
      icon: Icons.badge_rounded,
    ),
    const DriverDocumentModel(
      key: 'vehicle_registration',
      title: 'Vehicle Registration (RC)',
      description: 'Official vehicle logbook document',
      requirement: 'Page 1 & 2 showing VIN, engine number, and registered owner name.',
      status: 'not_uploaded',
      icon: Icons.directions_car_rounded,
    ),
    const DriverDocumentModel(
      key: 'insurance',
      title: 'Commercial E-Hailing Insurance',
      description: 'Passenger liability insurance policy cover',
      requirement: 'Policy schedule showing active coverage for passenger transport.',
      status: 'not_uploaded',
      icon: Icons.shield_rounded,
    ),
    const DriverDocumentModel(
      key: 'roadworthiness',
      title: 'Certificate of Roadworthiness',
      description: 'DEKRA or approved SABS inspection slip',
      requirement: 'Must be issued within the last 12 months for safety compliance.',
      status: 'not_uploaded',
      icon: Icons.verified_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDriverDocuments();
  }

  Future<void> _loadDriverDocuments() async {
    setState(() => _isLoading = true);
    try {
      final storageService = ref.read(documentStorageServiceProvider);
      final profileData = await storageService.fetchDriverDocumentStatuses();

      if (profileData.isNotEmpty) {
        setState(() {
          _documents = _documents.map((doc) {
            final urlKey = 'doc_${doc.key}';
            final statusKey = 'doc_${doc.key}_status';
            final url = profileData[urlKey] as String?;
            final status = (profileData[statusKey] as String?) ?? (url != null ? 'pending' : 'not_uploaded');

            return doc.copyWith(
              url: url,
              status: url != null ? (status.isEmpty ? 'pending' : status) : 'not_uploaded',
            );
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading documents: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadDocument(DriverDocumentModel doc) async {
    final storageService = ref.read(documentStorageServiceProvider);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TRYPColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TRYPColors.divider,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Upload ${doc.title}',
              style: TRYPTypography.headingMedium.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              doc.requirement,
              style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
            ),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: TRYPColors.inputFill,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TRYPColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: TRYPColors.secondary, size: 20),
              ),
              title: Text('Take Photo with Camera', style: TRYPTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              subtitle: Text('Ensure good lighting and full document frame', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: TRYPColors.inputFill,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TRYPColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: TRYPColors.white, size: 20),
              ),
              title: Text('Choose from Photo Gallery', style: TRYPTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              subtitle: Text('Select saved clear photo or scanned document', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source == null) return;

    final image = await storageService.pickDocumentImage(source: source);
    if (image == null) return;

    setState(() => _uploadingDocKey = doc.key);

    try {
      final url = await storageService.uploadDriverDocument(
        docKey: doc.key,
        file: image,
      );

      if (!mounted) return;

      if (url != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Text('${doc.title} uploaded successfully!'),
              ],
            ),
            backgroundColor: TRYPColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
        await _loadDriverDocuments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed for ${doc.title}. Please check network connection.'),
            backgroundColor: TRYPColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingDocKey = null);
    }
  }

  void _viewDocumentImage(DriverDocumentModel doc) {
    if (doc.url == null || doc.url!.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TRYPColors.secondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(doc.icon, color: TRYPColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      doc.title,
                      style: TRYPTypography.titleLarge.copyWith(color: TRYPColors.white),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: TRYPColors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                doc.url!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 260,
                    color: TRYPColors.inputFill,
                    child: const Center(
                      child: CircularProgressIndicator(color: TRYPColors.primary),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  width: double.infinity,
                  color: TRYPColors.inputFill,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.broken_image_rounded, size: 48, color: TRYPColors.grey),
                      const SizedBox(height: 12),
                      Text('Image preview unavailable', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Re-upload / Replace Scan',
              icon: Icons.refresh_rounded,
              onPressed: () {
                Navigator.pop(context);
                _pickAndUploadDocument(doc);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uploadedCount = _documents.where((d) => d.status != 'not_uploaded').length;
    final verifiedCount = _documents.where((d) => d.status == 'approved').length;
    final progressPercent = uploadedCount / _documents.length;

    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(Routes.driverHome),
        ),
        title: Text(
          'Driver Verification Documents',
          style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDriverDocuments,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: TRYPColors.primary))
            : RefreshIndicator(
                color: TRYPColors.secondary,
                onRefresh: _loadDriverDocuments,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  children: [
                    // ── Status Overview Header Banner ─────────────────
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: TRYPColors.secondary,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: TRYPColors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(
                                  Icons.verified_user_rounded,
                                  color: TRYPColors.secondary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Verification Progress',
                                      style: TRYPTypography.bodySmall.copyWith(
                                        color: TRYPColors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$verifiedCount of ${_documents.length} Approved • $uploadedCount Uploaded',
                                      style: TRYPTypography.titleLarge.copyWith(
                                        color: TRYPColors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: progressPercent,
                              minHeight: 8,
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(TRYPColors.primary),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Verification response within 24 hours',
                                style: TRYPTypography.bodySmall.copyWith(
                                  color: TRYPColors.grey,
                                  fontSize: 11,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: TRYPColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  'TRYP Safety Standard',
                                  style: TRYPTypography.labelSmall.copyWith(
                                    color: TRYPColors.primary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    Text(
                      'Required Documents',
                      style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Upload legibly scanned or captured photo documents for admin review.',
                      style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
                    ),
                    const SizedBox(height: 16),

                    // ── Document Cards List ───────────────────────────
                    ..._documents.map((doc) => _DocumentUploadCard(
                          doc: doc,
                          isUploading: _uploadingDocKey == doc.key,
                          onUpload: () => _pickAndUploadDocument(doc),
                          onView: () => _viewDocumentImage(doc),
                        )),

                    const SizedBox(height: 24),

                    // ── Help Banner ────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TRYPColors.inputFill,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.help_outline_rounded, color: TRYPColors.secondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Need document assistance?',
                                  style: TRYPTypography.titleMedium.copyWith(fontSize: 14),
                                ),
                                Text(
                                  'Contact TRYP Driver Support 24/7 for verification help.',
                                  style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DocumentUploadCard extends StatelessWidget {
  final DriverDocumentModel doc;
  final bool isUploading;
  final VoidCallback onUpload;
  final VoidCallback onView;

  const _DocumentUploadCard({
    required this.doc,
    required this.isUploading,
    required this.onUpload,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeFg;
    String badgeLabel;
    IconData badgeIcon;

    switch (doc.status) {
      case 'approved':
        badgeBg = Colors.green.withValues(alpha: 0.12);
        badgeFg = Colors.green;
        badgeLabel = 'Verified';
        badgeIcon = Icons.check_circle_rounded;
        break;
      case 'action_required':
        badgeBg = TRYPColors.error.withValues(alpha: 0.12);
        badgeFg = TRYPColors.error;
        badgeLabel = 'Action Needed';
        badgeIcon = Icons.error_rounded;
        break;
      case 'pending':
        badgeBg = Colors.orange.withValues(alpha: 0.12);
        badgeFg = Colors.orange;
        badgeLabel = 'Under Review';
        badgeIcon = Icons.access_time_filled_rounded;
        break;
      case 'not_uploaded':
      default:
        badgeBg = TRYPColors.grey.withValues(alpha: 0.12);
        badgeFg = TRYPColors.grey;
        badgeLabel = 'Not Uploaded';
        badgeIcon = Icons.cloud_upload_outlined;
        break;
    }

    final hasFile = doc.url != null && doc.url!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: doc.status == 'approved'
              ? Colors.green.withValues(alpha: 0.4)
              : (doc.status == 'action_required' ? TRYPColors.error : TRYPColors.divider),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: doc.status == 'approved'
                      ? Colors.green.withValues(alpha: 0.1)
                      : TRYPColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  doc.icon,
                  color: doc.status == 'approved' ? Colors.green : TRYPColors.secondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: TRYPTypography.titleLarge.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doc.description,
                      style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeFg),
                    const SizedBox(width: 4),
                    Text(
                      badgeLabel,
                      style: TRYPTypography.labelSmall.copyWith(
                        color: badgeFg,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            doc.requirement,
            style: TRYPTypography.bodySmall.copyWith(
              color: TRYPColors.secondary.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // ── Action Row: Thumbnail or Upload Trigger ──────────────────
          if (isUploading)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: TRYPColors.secondary),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Uploading scan to Supabase Storage...',
                    style: TRYPTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: TRYPColors.secondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                if (hasFile) ...[
                  GestureDetector(
                    onTap: onView,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: TRYPColors.inputFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.remove_red_eye_rounded, size: 16, color: TRYPColors.secondary),
                          const SizedBox(width: 6),
                          Text(
                            'View Scan',
                            style: TRYPTypography.labelMedium.copyWith(
                              color: TRYPColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onUpload,
                    icon: Icon(
                      hasFile ? Icons.file_upload_outlined : Icons.add_a_photo_rounded,
                      size: 16,
                    ),
                    label: Text(hasFile ? 'Replace Photo' : 'Upload Scan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasFile ? TRYPColors.inputFill : TRYPColors.secondary,
                      foregroundColor: hasFile ? TRYPColors.secondary : TRYPColors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: TRYPTypography.labelMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
