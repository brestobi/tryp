import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';
import 'package:tryp/core/utils/validators.dart';

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
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TRYPColors.secondary),
          onPressed: () => context.go(Routes.login),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _emailSent ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Icon badge
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: TRYPColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            size: 32,
            color: TRYPColors.primaryDark,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Reset password',
          style: TRYPTypography.headingLarge.copyWith(
            color: TRYPColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter the email address linked to your account and we'll send you a password reset link.",
          style: TRYPTypography.bodyMedium.copyWith(
            color: TRYPColors.grey,
          ),
        ),
        const SizedBox(height: 32),
        Form(
          key: _formKey,
          child: CustomTextField(
            label: 'Email address',
            hint: 'example@email.com',
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
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => context.go(Routes.login),
            child: Text(
              'Back to Login',
              style: TRYPTypography.bodyMedium.copyWith(
                color: TRYPColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 48),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: TRYPColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            size: 44,
            color: TRYPColors.success,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Check your inbox',
          style: TRYPTypography.headingMedium.copyWith(
            color: TRYPColors.secondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'We sent a password reset link to\n${_emailController.text.trim()}',
          style: TRYPTypography.bodyLarge.copyWith(
            color: TRYPColors.grey,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the link in the email to set a new password. The link expires in 1 hour.',
          style: TRYPTypography.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Back to Login',
          onPressed: () => context.go(Routes.login),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () {
            setState(() {
              _emailSent = false;
              _emailController.clear();
            });
          },
          child: Text(
            'Try a different email',
            style: TRYPTypography.bodyMedium.copyWith(
              color: TRYPColors.grey,
            ),
          ),
        ),
      ],
    );
  }
}
