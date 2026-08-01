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

/// Login Screen — Bolt-style: white bg, bold headline, flat inputs, pill CTA
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

  Future<void> _handlePostLoginRedirect() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return;

    // Check if profile exists and has a role
    final data = await client.from('profiles').select('role').eq('id', user.id).maybeSingle();

    if (data != null && data['role'] != null) {
      final role = data['role'] as String;
      if (role == 'driver') {
        context.go(Routes.driverHome);
      } else {
        context.go(Routes.passengerHome);
      }
    } else {
      context.go(Routes.roleSelection);
    }
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
      await _handlePostLoginRedirect();
    } catch (error) {
      if (!mounted) return;
      _logger.e('Login error: $error');
      final message = error is AuthException
          ? error.message
          : 'Login failed. Please check your credentials and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
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
      backgroundColor: TRYPColors.white,
      // Minimal back button — icon only, no AppBar chrome
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TRYPColors.secondary, size: 24),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.onboarding),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Headline
                        Text(
                          'Welcome back.',
                          style: TRYPTypography.headingLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Log in to continue',
                          style: TRYPTypography.bodyLarge.copyWith(
                            color: TRYPColors.grey,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // Email
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

                        // Password
                        CustomTextField(
                          hint: 'Password',
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

                        // Forgot password — right-aligned
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.go(Routes.forgotPassword),
                            style: TextButton.styleFrom(
                              foregroundColor: TRYPColors.secondary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 10),
                            ),
                            child: Text(
                              'Forgot password?',
                              style: TRYPTypography.labelMedium.copyWith(
                                color: TRYPColors.secondary,
                                decoration: TextDecoration.underline,
                                decorationColor: TRYPColors.grey,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Login CTA
                        PrimaryButton(
                          label: 'Log in',
                          onPressed: _submit,
                          isLoading: _isLoading,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 28),

                        // Divider
                        const LabeledDivider(label: 'or continue with'),
                        const SizedBox(height: 24),

                        // Social login row
                        Row(
                          children: [
                            Expanded(
                              child: _SocialButton(
                                label: 'Google',
                                icon: Icons.g_mobiledata,
                                onTap: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  setState(() => _isLoading = true); // Start loading
                                  try {
                                    await ref.read(authServiceProvider).signInWithGoogleNative();
                                    if (!mounted) return;
                                    await _handlePostLoginRedirect();
                                  } catch (e) {
                                    if (!mounted) return;
                                    setState(() => _isLoading = false); // Stop loading on error
                                    messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text('Google sign-in failed.')),
                                    );
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SocialButton(
                                label: 'Facebook',
                                icon: Icons.facebook_rounded,
                                onTap: () {},
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom: don't have account
              Padding(
                padding: EdgeInsets.only(
                  left: 28,
                  right: 28,
                  bottom: bottomPad + 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: TRYPTypography.bodyMedium.copyWith(
                        color: TRYPColors.grey,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go(Routes.register),
                      child: Text(
                        'Register',
                        style: TRYPTypography.bodyMedium.copyWith(
                          color: TRYPColors.secondary,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Social Login Button — outline pill
// ─────────────────────────────────────────────────────────────────────────────

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
            Text(
              label,
              style: TRYPTypography.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
