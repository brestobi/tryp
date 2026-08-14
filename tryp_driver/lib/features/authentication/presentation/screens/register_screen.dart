import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/services/supabase_service.dart';
import 'package:tryp_driver/core/utils/validators.dart';
import 'package:tryp_driver/core/widgets/common_widgets.dart';

/// Driver Register Screen — Sleek card UI with SA PrDP hint & Google OAuth
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
        role: 'driver',
      );
      if (!mounted) return;
      context.go(Routes.emailVerification, extra: email);
    } catch (error) {
      if (!mounted) return;
      _logger.e('Driver Registration error: $error');

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

      _logger.e(errorMessage);
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: TRYPColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: TRYPColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.badge_rounded,
                            size: 14,
                            color: TRYPColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'DRIVER REGISTRATION',
                            style: TRYPTypography.labelSmall.copyWith(
                              color: TRYPColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                    decoration: BoxDecoration(
                      color: TRYPColors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: TRYPColors.secondary.withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              'Create Driver Account',
                              style: TRYPTypography.headingLarge.copyWith(
                                color: TRYPColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Enter your legal name as printed on your South African ID / Driving Permit.',
                              style: TRYPTypography.bodyLarge.copyWith(
                                color: TRYPColors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 24),

                            CustomTextField(
                              hint: 'Full Legal Name',
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
                              hint: 'Create a secure password',
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
                              label: 'Continue to Driver Verification',
                              onPressed: _submit,
                              isLoading: _isLoading,
                              enabled: !_isLoading,
                              backgroundColor: TRYPColors.primary,
                              foregroundColor: TRYPColors.white,
                            ),
                            const SizedBox(height: 24),

                            const LabeledDivider(label: 'or sign up with'),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: _SocialButton(
                                    label: 'Google Cloud',
                                    icon: Icons.g_mobiledata,
                                    onTap: () async {
                                      setState(() => _isLoading = true);
                                      try {
                                        final signedIn = await ref
                                            .read(authServiceProvider)
                                            .signInWithGoogleNative();
                                        if (!mounted) return;
                                        if (!signedIn) {
                                          setState(() => _isLoading = false);
                                          return;
                                        }

                                        // The server allows this only for a
                                        // newly-created Google profile. An
                                        // existing passenger is rejected.
                                        await ref
                                            .read(authServiceProvider)
                                            .claimDriverRole();

                                        if (!mounted) return;
                                        context.go(Routes.driverOnboarding);
                                      } catch (e) {
                                        // A failed claim must not leave a
                                        // passenger session active in the
                                        // driver app.
                                        try {
                                          await ref
                                              .read(authServiceProvider)
                                              .signOut();
                                        } catch (_) {
                                          // Preserve the original auth error.
                                        }
                                        if (!mounted) return;
                                        setState(() => _isLoading = false);
                                        _logger.e(
                                          'Google registration error: $e',
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 26),

                            Center(
                              child: Text(
                                'By registering, you agree to TRYP Driver Partner\nTerms of Service and Privacy Policy.',
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
                                    'Already registered as a driver? ',
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
            Icon(icon, size: 24, color: TRYPColors.secondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TRYPTypography.labelMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
