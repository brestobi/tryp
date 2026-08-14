import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';
import 'package:tryp/core/utils/validators.dart';

/// Register Screen — Bolt-style: white bg, bold headline, flat inputs, pill CTA
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
      final email = _emailController.text.trim();
      final authService = ref.read(authServiceProvider);
      await authService.signUpWithEmail(
        email,
        _passwordController.text,
        fullName: _nameController.text.trim(),
      );
      if (!mounted) return;
      context.go(Routes.emailVerification, extra: email);
    } catch (error) {
      if (!mounted) return;
      _logger.e('Registration error: $error');

      String errorMessage = 'Registration failed. Please try again.';
      final rawError = error.toString();
      if (rawError.contains('User already registered') ||
          rawError.contains('already exists')) {
        errorMessage = 'An account with this email already exists.';
      } else if (rawError.contains('Weak password') ||
          rawError.contains('at least')) {
        errorMessage = 'Password is too weak. Use at least 8 characters.';
      } else if (rawError.contains('AuthException:')) {
        errorMessage = rawError.replaceAll('AuthException:', '').trim();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: TRYPColors.error,
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
      backgroundColor: TRYPColors.background,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.onboarding),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: TRYPColors.primary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: TRYPColors.inputFill,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    decoration: BoxDecoration(
                      color: TRYPColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Create account',
                              style: TRYPTypography.headingLarge.copyWith(
                                color: TRYPColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start your ride with TRYP.',
                              style: TRYPTypography.bodyLarge.copyWith(
                                color: TRYPColors.grey,
                              ),
                            ),
                            const SizedBox(height: 28),

                            CustomTextField(
                              hint: 'Full name',
                              controller: _nameController,
                              keyboardType: TextInputType.name,
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Full name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            CustomTextField(
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
                            const SizedBox(height: 14),

                            CustomTextField(
                              hint: 'Create a password',
                              controller: _passwordController,
                              obscureText: true,
                              prefixIcon: Icons.lock_outline_rounded,
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
                              label: 'Create account',
                              onPressed: _submit,
                              isLoading: _isLoading,
                              enabled: !_isLoading,
                              backgroundColor: TRYPColors.primary,
                              foregroundColor: TRYPColors.white,
                            ),
                            const SizedBox(height: 24),

                            const LabeledDivider(label: 'or continue with'),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: _SocialButton(
                                    label: 'Google',
                                    icon: Icons.g_mobiledata,
                                    onTap: () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      setState(() => _isLoading = true);
                                      try {
                                        final signedIn = await ref
                                            .read(authServiceProvider)
                                            .signInWithGoogleAuto();
                                        if (!mounted || !signedIn) return;
                                        final route =
                                            await googlePostAuthRoute();
                                        if (!mounted) return;
                                        if (route != null) {
                                          context.go(route);
                                        } else {
                                          await ref
                                              .read(authServiceProvider)
                                              .signOut();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'This account belongs to the TRYP Driver app. Use the passenger app account to continue.',
                                              ),
                                              backgroundColor: TRYPColors.error,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (!mounted) return;
                                        setState(() => _isLoading = false);
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Google sign-in failed.',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SocialButton(
                                    label: 'Apple',
                                    icon: Icons.apple,
                                    onTap: () {},
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 26),

                            Center(
                              child: Text(
                                'By continuing you agree to our Terms of Service\nand Privacy Policy.',
                                style: TRYPTypography.bodySmall.copyWith(
                                  color: TRYPColors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: TRYPTypography.bodyMedium.copyWith(
                                      color: TRYPColors.grey,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.go(Routes.login),
                                    child: Text(
                                      'Log in',
                                      style: TRYPTypography.bodyMedium.copyWith(
                                        color: TRYPColors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: bottomPad),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          border: Border.all(color: TRYPColors.divider, width: 1.5),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: TRYPColors.secondary),
            const SizedBox(width: 8),
            Text(label, style: TRYPTypography.labelMedium),
          ],
        ),
      ),
    );
  }
}
