import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/utils/validators.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

/// Password update screen shown after a Supabase recovery link is opened.
class ResetPasswordScreenPage extends ConsumerStatefulWidget {
  final VoidCallback? onCancel;

  const ResetPasswordScreenPage({super.key, this.onCancel});

  @override
  ConsumerState<ResetPasswordScreenPage> createState() =>
      _ResetPasswordScreenPageState();
}

class _ResetPasswordScreenPageState
    extends ConsumerState<ResetPasswordScreenPage> {
  final _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isLoading = false;
  bool _isComplete = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.updatePassword(_passwordController.text);

      // Keep the recovery session alive long enough to show confirmation. It
      // is ended when the user leaves this screen.
      if (!mounted) return;
      setState(() => _isComplete = true);
    } catch (error) {
      if (!mounted) return;
      _logger.e('Password update error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authErrorMessage(error)),
          backgroundColor: TRYPColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToLogin() {
    unawaited(_finishRecovery());
  }

  Future<void> _finishRecovery() async {
    try {
      await ref.read(authServiceProvider).signOut();
    } catch (error) {
      _logger.w('Could not end recovery session: $error');
    }

    if (!mounted) return;
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      context.go(Routes.login);
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
          onPressed: _goToLogin,
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(28, 8, 28, bottomPad + 32),
          child: _isComplete ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: TRYPColors.inputFill,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.password_rounded,
            size: 28,
            color: TRYPColors.secondary,
          ),
        ),
        const SizedBox(height: 24),
        Text('Create a new password.', style: TRYPTypography.headingLarge),
        const SizedBox(height: 8),
        Text(
          'Choose a strong password for your passenger account.',
          style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
        ),
        const SizedBox(height: 36),
        Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                hint: 'New password',
                controller: _passwordController,
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required';
                  }
                  if (!Validators.isStrongPassword(value)) {
                    return 'Use 8+ characters with upper, lower, and a number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              CustomTextField(
                hint: 'Confirm new password',
                controller: _confirmationController,
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (!Validators.passwordsMatch(
                    _passwordController.text,
                    value,
                  )) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Update password',
          onPressed: _submit,
          isLoading: _isLoading,
          enabled: !_isLoading,
        ),
        const SizedBox(height: 18),
        Center(
          child: TextButton(
            onPressed: _goToLogin,
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
      children: [
        const SizedBox(height: 72),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: TRYPColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 46,
            color: TRYPColors.success,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Password updated',
          style: TRYPTypography.headingMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Your passenger account is secure. Sign in with your new password.',
          style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 44),
        PrimaryButton(label: 'Go to Login', onPressed: _goToLogin),
      ],
    );
  }
}
