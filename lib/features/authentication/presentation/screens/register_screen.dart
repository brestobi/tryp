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
      context.go(Routes.roleSelection);
    } catch (error) {
      if (!mounted) return;
      _logger.e('Registration error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A registration error occurred. Please try again.')),
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
          child: SingleChildScrollView(
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
                      onTap: () {
                        context.go(Routes.login);
                      },
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
          ),
        ),
      ),
    );
  }
}
