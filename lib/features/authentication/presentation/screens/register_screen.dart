import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';
import 'package:tryp/core/utils/validators.dart';

class RegisterScreenPage extends ConsumerStatefulWidget {
  const RegisterScreenPage({super.key});

  @override
  ConsumerState<RegisterScreenPage> createState() => _RegisterScreenPageState();
}

class _RegisterScreenPageState extends ConsumerState<RegisterScreenPage> {
  final _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _registrationSuccess = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        fullName: _nameController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _registrationSuccess = true);
    } catch (error) {
      if (!mounted) return;
      _logger.e('Registration error: $error');

      String errorMessage = 'Registration failed. Please try again.';
      final rawError = error.toString();
      if (rawError.contains('User already registered') ||
          rawError.contains('already exists')) {
        errorMessage =
            'An account with this email already exists. Please login instead.';
      } else if (rawError.contains('Weak password') ||
          rawError.contains('at least')) {
        errorMessage =
            'Password is too weak. Please use at least 8 characters.';
      } else if (rawError.contains('AuthException:')) {
        errorMessage = rawError.replaceAll('AuthException:', '').trim();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(errorMessage)),
            ],
          ),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 4),
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _registrationSuccess ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  // ── Success state ───────────────────────────────────────────────────────────

  Widget _buildSuccess() {
    final firstName = _nameController.text.trim().split(' ').first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: TRYPColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 52,
            color: TRYPColors.primaryDark,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Welcome, $firstName! 🎉',
          style: TRYPTypography.headingMedium.copyWith(
            color: TRYPColors.secondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your account has been created successfully.',
          style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Log in to start using TRYP.',
          style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        PrimaryButton(
          label: 'Go to Login',
          onPressed: () => context.go(Routes.login),
          icon: Icons.login_rounded,
        ),
      ],
    );
  }

  // ── Registration form ───────────────────────────────────────────────────────

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Create account',
            style: TRYPTypography.headingLarge.copyWith(
              color: TRYPColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Register to start riding',
            style: TRYPTypography.bodyLarge.copyWith(
              color: TRYPColors.grey,
            ),
          ),
          const SizedBox(height: 32),
          Form(
            key: _formKey,
            child: Column(
              children: [
                CustomTextField(
                  label: 'Full Name',
                  hint: 'John Doe',
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Email',
                  hint: 'example@email.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
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
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'Password',
                  hint: 'Create a password',
                  controller: _passwordController,
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (!Validators.isValidPasswordLength(value)) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Register',
                  onPressed: _submit,
                  isLoading: _isLoading,
                  enabled: !_isLoading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TRYPTypography.bodyMedium,
              ),
              GestureDetector(
                onTap: () => context.go(Routes.login),
                child: Text(
                  'Login',
                  style: TRYPTypography.bodyMedium.copyWith(
                    color: TRYPColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
