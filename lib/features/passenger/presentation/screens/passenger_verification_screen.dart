import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/features/passenger/presentation/screens/in_app_camera_capture_screen.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/passenger_verification_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class PassengerVerificationScreen extends ConsumerStatefulWidget {
  const PassengerVerificationScreen({super.key});

  @override
  ConsumerState<PassengerVerificationScreen> createState() =>
      _PassengerVerificationScreenState();
}

class _PassengerVerificationScreenState
    extends ConsumerState<PassengerVerificationScreen> {
  XFile? _idDocument;
  XFile? _selfie;
  String _status = 'unverified';
  String? _reviewNotes;
  bool _loadingStatus = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final verification = await ref
          .read(passengerVerificationServiceProvider)
          .getCurrentVerification();
      if (!mounted) return;
      setState(() {
        _status = verification?['status'] as String? ?? 'unverified';
        _reviewNotes = verification?['review_notes'] as String?;
      });
    } catch (_) {
      // Keep the screen usable; the submission path will show a concrete error.
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _captureId() async {
    final file = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const InAppCameraCaptureScreen(
          kind: PassengerCaptureKind.idDocument,
        ),
      ),
    );
    if (file != null && mounted) setState(() => _idDocument = file);
  }

  Future<void> _captureSelfie() async {
    final file = await Navigator.of(context).push<XFile>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            const InAppCameraCaptureScreen(kind: PassengerCaptureKind.selfie),
      ),
    );
    if (file != null && mounted) setState(() => _selfie = file);
  }

  Future<void> _submit() async {
    if (_idDocument == null || _selfie == null) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(passengerVerificationServiceProvider)
          .submitVerification(idDocument: _idDocument!, selfie: _selfie!);
      if (!mounted) return;
      setState(() {
        _status = 'pending';
        _reviewNotes = null;
        _idDocument = null;
        _selfie = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification submitted. Our team will review it shortly.',
          ),
          backgroundColor: TRYPColors.primary,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not submit verification: $error'),
          backgroundColor: TRYPColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _idDocument != null && _selfie != null && !_submitting;
    final isApproved = _status == 'approved';
    final isPending = _status == 'pending' || _status == 'under_review';

    return Scaffold(
      backgroundColor: TRYPColors.surface,
      appBar: AppBar(
        title: const Text('Passenger verification'),
        backgroundColor: TRYPColors.surface,
        actions: [
          TextButton(
            onPressed: () => context.go(Routes.passengerHome),
            child: const Text('Done'),
          ),
        ],
      ),
      body: _loadingStatus
          ? const Center(
              child: CircularProgressIndicator(color: TRYPColors.secondary),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusBanner(status: _status, reviewNotes: _reviewNotes),
                    const SizedBox(height: 20),
                    Text(
                      'Verify your identity',
                      style: TRYPTypography.headingLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isApproved
                          ? 'Your identity is approved. You can request TRYP rides.'
                          : isPending
                          ? 'Your documents are with our review team. You can return here to check the status.'
                          : 'For passenger safety, you must complete identity verification before requesting a ride.',
                      style: TRYPTypography.bodyMedium.copyWith(
                        color: TRYPColors.grey,
                      ),
                    ),
                    if (!isApproved && !isPending) ...[
                      const SizedBox(height: 20),
                      _CaptureCard(
                        title: '1. Capture your ID card',
                        description:
                            'Capture the front of your government-issued ID clearly inside TRYP.',
                        icon: Icons.badge_outlined,
                        file: _idDocument,
                        onCapture: _captureId,
                      ),
                      const SizedBox(height: 12),
                      _CaptureCard(
                        title: '2. Take a live selfie holding your ID',
                        description:
                            'Hold the same ID card beside your face while capturing inside TRYP.',
                        icon: Icons.face_retouching_natural_rounded,
                        file: _selfie,
                        onCapture: _captureSelfie,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: TRYPColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: TRYPColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lock_outline_rounded,
                              color: TRYPColors.secondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your ID and selfie are stored privately and can only be viewed by authorized TRYP reviewers.',
                                style: TRYPTypography.bodySmall.copyWith(
                                  color: TRYPColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        label: 'Submit for admin review',
                        icon: Icons.verified_user_outlined,
                        enabled: canSubmit,
                        isLoading: _submitting,
                        onPressed: _submit,
                      ),
                    ],
                    if (isApproved) ...[
                      const SizedBox(height: 24),
                      SecondaryButton(
                        label: 'Back to TRYP',
                        onPressed: () => context.go(Routes.passengerHome),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, this.reviewNotes});

  final String status;
  final String? reviewNotes;

  @override
  Widget build(BuildContext context) {
    final approved = status == 'approved';
    final rejected = status == 'rejected';
    final pending = status == 'pending' || status == 'under_review';
    final color = approved
        ? TRYPColors.secondary
        : rejected
        ? TRYPColors.error
        : pending
        ? TRYPColors.secondary
        : TRYPColors.grey;
    final title = approved
        ? 'Identity approved'
        : rejected
        ? 'Action needed'
        : pending
        ? 'Review in progress'
        : 'Verification required';
    final message = rejected
        ? (reviewNotes?.isNotEmpty == true
              ? reviewNotes!
              : 'Please capture clearer images and submit again.')
        : approved
        ? 'You are cleared to request rides.'
        : pending
        ? 'An admin is checking that your ID and selfie match.'
        : 'Complete the two camera captures below.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            approved
                ? Icons.verified_rounded
                : pending
                ? Icons.hourglass_top_rounded
                : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TRYPTypography.titleMedium.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TRYPTypography.bodySmall.copyWith(
                    color: TRYPColors.secondary,
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

class _CaptureCard extends StatelessWidget {
  const _CaptureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.file,
    required this.onCapture,
  });

  final String title;
  final String description;
  final IconData icon;
  final XFile? file;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TRYPColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: file == null ? TRYPColors.inputFill : TRYPColors.lightGrey,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              file == null ? icon : Icons.check_rounded,
              color: file == null ? TRYPColors.secondary : TRYPColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TRYPTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TRYPTypography.bodySmall.copyWith(
                    color: TRYPColors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onCapture,
                  icon: Icon(
                    file == null
                        ? Icons.camera_alt_rounded
                        : Icons.refresh_rounded,
                    size: 17,
                  ),
                  label: Text(file == null ? 'Capture in app' : 'Retake'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
