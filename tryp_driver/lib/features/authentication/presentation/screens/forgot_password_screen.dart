import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/services/supabase_service.dart';
import 'package:tryp_driver/core/widgets/common_widgets.dart';
import 'package:tryp_driver/core/utils/validators.dart';

/// Forgot Password Screen — Bolt-style: white bg, icon badge, flat input, pill CTA
/// Native deep-link target registered by the driver app on Android and iOS.
const String driverPasswordRecoveryRedirect = 'io.tryp.driver://auth-callback';

class ForgotPasswordScreenPage extends ConsumerStatefulWidget {
  const ForgotPasswordScreenPage({super.key});

  @override
  ConsumerState<ForgotPasswordScreenPage> createState() =>
      _ForgotPasswordScreenPageState();
}

class _ForgotPasswordScreenPageState
    extends ConsumerState<ForgotPasswordScreenPage> {
  final _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: driverPasswordRecoveryRedirect,
      );
      if (!mounted) return;
      setState(() => _emailSent = true);
    } catch (error) {
      if (!mounted) return;
      _logger.e('Password reset error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to send reset email. Please check the address and try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: TRYPColors.secondary,
            size: 24,
          ),
          onPressed: () => context.go(Routes.login),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 8, 28, bottomPad + 32),
          child: _emailSent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon badge
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: TRYPColors.inputFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            size: 28,
            color: TRYPColors.secondary,
          ),
        ),
        const SizedBox(height: 24),
        Text('Reset password.', style: TRYPTypography.headingLarge),
        const SizedBox(height: 8),
        Text(
          "Enter your email and we'll send you a link to reset your password.",
          style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
        ),
        const SizedBox(height: 36),

        Form(
          key: _formKey,
          child: CustomTextField(
            hint: 'Email address',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email is required';
              }
              if (!Validators.isValidEmail(value)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 32),

        PrimaryButton(
          label: 'Send reset link',
          onPressed: _submit,
          isLoading: _isLoading,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: () => context.go(Routes.login),
            style: TextButton.styleFrom(
              foregroundColor: TRYPColors.grey,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            ),
            child: Text(
              'Back to Login',
              style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: TRYPColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 42,
            color: TRYPColors.success,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Check your inbox',
          style: TRYPTypography.headingMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'We sent a reset link to\n${_emailController.text.trim()}',
          style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'The link expires in 1 hour.',
          style: TRYPTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 44),
        PrimaryButton(
          label: 'Back to Login',
          onPressed: () => context.go(Routes.login),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () => setState(() {
            _emailSent = false;
            _emailController.clear();
          }),
          style: TextButton.styleFrom(foregroundColor: TRYPColors.grey),
          child: Text(
            'Try a different email',
            style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
          ),
        ),
      ],
    );
  }
}
