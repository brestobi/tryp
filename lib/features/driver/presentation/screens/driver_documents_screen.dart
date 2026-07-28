import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class DriverDocumentItem {
  final String title;
  final String subtitle;
  final String status; // 'approved', 'pending', 'action_required'
  final IconData icon;

  const DriverDocumentItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.icon,
  });
}

class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({Key? key}) : super(key: key);

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  final List<DriverDocumentItem> _documents = const [
    DriverDocumentItem(
      title: 'PrDP Professional Driving Permit',
      subtitle: 'Expires: 14 Oct 2027',
      status: 'approved',
      icon: Icons.badge_rounded,
    ),
    DriverDocumentItem(
      title: 'Vehicle Registration (RC Certificate)',
      subtitle: 'Toyota Corolla Quest • ND 123-456',
      status: 'approved',
      icon: Icons.directions_car_rounded,
    ),
    DriverDocumentItem(
      title: 'Commercial Insurance Cover Policy',
      subtitle: 'Under Review by TRYP Team',
      status: 'pending',
      icon: Icons.shield_rounded,
    ),
    DriverDocumentItem(
      title: 'Roadworthiness Certificate',
      subtitle: 'Action Required: Re-upload clear scan',
      status: 'action_required',
      icon: Icons.verified_rounded,
    ),
  ];

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

            ..._documents.map((doc) => _DocumentCard(document: doc)).toList(),

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

  const _DocumentCard({required this.document});

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

    return Container(
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
    );
  }
}
