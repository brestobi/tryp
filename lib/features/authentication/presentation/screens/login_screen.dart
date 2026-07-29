import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';
import 'package:tryp/core/utils/validators.dart';

class LoginScreenPage extends ConsumerStatefulWidget {
  const LoginScreenPage({super.key});

  @override
  ConsumerState<LoginScreenPage> createState() => _LoginScreenPageState();
}

class _LoginScreenPageState extends ConsumerState<LoginScreenPage> {
  final _logger = Logger();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      context.go(Routes.roleSelection);
    } catch (error) {
      if (!mounted) return;
      _logger.e('Login error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An authentication error occurred. Please try again.')),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Welcome back!',
                style: TRYPTypography.headingLarge.copyWith(
                  color: TRYPColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log in to continue',
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
                      hint: 'Enter your password',
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            context.go(Routes.forgotPassword);
                          },
                          child: Text(
                            'Forgot password?',
                            style: TRYPTypography.bodyMedium.copyWith(
                              color: TRYPColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Login',
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
                    "Don't have an account? ",
                    style: TRYPTypography.bodyMedium,
                  ),
                  GestureDetector(
                    onTap: () {
                      context.go(Routes.register);
                    },
                    child: Text(
                      'Register',
                      style: TRYPTypography.bodyMedium.copyWith(
                        color: TRYPColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text('or continue with'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialLoginButton(
                    icon: Icons.g_mobiledata,
                    onTap: () async {
                      try {
                        await ref.read(authServiceProvider).signInWithGoogle();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Google Sign-in failed.')),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _SocialLoginButton(
                    icon: Icons.facebook,
                    onTap: () {
                      // TODO: Implement Facebook sign-in
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialLoginButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SocialLoginButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: TRYPColors.lightGrey),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, size: 28, color: TRYPColors.secondary),
      ),
    );
  }
}
