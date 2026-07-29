import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/document_storage_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class DriverDocumentItem {
  final String key;
  final String title;
  final String subtitle;
  final String status; // 'approved', 'pending', 'action_required'
  final IconData icon;

  const DriverDocumentItem({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
  });

  DriverDocumentItem copyWith({
    String? key,
    String? title,
    String? subtitle,
    String? status,
    IconData? icon,
  }) {
    return DriverDocumentItem(
      key: key ?? this.key,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      icon: icon ?? this.icon,
    );
  }
}

class DriverDocumentsScreen extends ConsumerStatefulWidget {
  const DriverDocumentsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends ConsumerState<DriverDocumentsScreen> {
  bool _isLoading = false;
  List<DriverDocumentItem> _documents = [
    const DriverDocumentItem(
      key: 'prdp',
      title: 'PrDP Professional Driving Permit',
      subtitle: 'Expires: 14 Oct 2027',
      status: 'approved',
      icon: Icons.badge_rounded,
    ),
    const DriverDocumentItem(
      key: 'vehicle_registration',
      title: 'Vehicle Registration (RC Certificate)',
      subtitle: 'Toyota Corolla Quest • ND 123-456',
      status: 'approved',
      icon: Icons.directions_car_rounded,
    ),
    const DriverDocumentItem(
      key: 'insurance',
      title: 'Commercial Insurance Cover Policy',
      subtitle: 'Under Review by TRYP Team',
      status: 'pending',
      icon: Icons.shield_rounded,
    ),
    const DriverDocumentItem(
      key: 'roadworthiness',
      title: 'Roadworthiness Certificate',
      subtitle: 'Action Required: Re-upload clear scan',
      status: 'action_required',
      icon: Icons.verified_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadDocumentStatuses();
  }

  Future<void> _loadDocumentStatuses() async {
    final storageService = ref.read(documentStorageServiceProvider);
    final data = await storageService.fetchDriverDocumentStatuses();
    if (data.isNotEmpty) {
      setState(() {
        _documents = _documents.map((doc) {
          final statusKey = 'doc_${doc.key}_status';
          final urlKey = 'doc_${doc.key}';
          final status = (data[statusKey] as String?) ?? doc.status;
          final hasUrl = (data[urlKey] as String?)?.isNotEmpty == true;
          return doc.copyWith(
            status: hasUrl ? (status == 'approved' ? 'approved' : 'pending') : doc.status,
            subtitle: hasUrl ? 'Uploaded • $status' : doc.subtitle,
          );
        }).toList();
      });
    }
  }

  Future<void> _reuploadDocument(DriverDocumentItem doc) async {
    final storageService = ref.read(documentStorageServiceProvider);
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Re-upload ${doc.title}', style: TRYPTypography.headingSmall),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: TRYPColors.primary),
              title: const Text('Take Photo with Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: TRYPColors.secondary),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final image = await storageService.pickDocumentImage(source: source);
    if (image == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Uploading ${doc.title} to Supabase...'),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    final url = await storageService.uploadDriverDocument(
      docKey: doc.key,
      file: image,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (url != null) {
      _loadDocumentStatuses();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${doc.title} uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed for ${doc.title}. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(Routes.driverHome),
        ),
        title: Text('Driver Verification Documents', style: TRYPTypography.headingSmall.copyWith(fontSize: 18)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Status Header Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: TRYPColors.secondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TRYPColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.hourglass_top_rounded, color: TRYPColors.secondary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Verification Status', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
                        const SizedBox(height: 2),
                        Text(
                          '3 of 4 Documents Verified',
                          style: TRYPTypography.headingSmall.copyWith(color: TRYPColors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text('Uploaded Documents', style: TRYPTypography.headingSmall.copyWith(fontSize: 16)),
            const SizedBox(height: 14),

            ..._documents.map((doc) => _DocumentCard(
                  document: doc,
                  onUpload: () => _reuploadDocument(doc),
                )).toList(),

            const SizedBox(height: 24),

            PrimaryButton(
              label: 'Re-upload Flagged Documents',
              onPressed: () => context.go(Routes.driverOnboarding),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DriverDocumentItem document;
  final VoidCallback? onUpload;

  const _DocumentCard({required this.document, this.onUpload});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (document.status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Verified';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'action_required':
        statusColor = Colors.red;
        statusText = 'Action Needed';
        statusIcon = Icons.error_rounded;
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusText = 'Under Review';
        statusIcon = Icons.access_time_filled_rounded;
        break;
    }

    return GestureDetector(
      onTap: onUpload,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TRYPColors.lightGrey,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(document.icon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(document.title, style: TRYPTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(document.subtitle, style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 12, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  statusText,
                  style: TRYPTypography.bodySmall.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}
