import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/services/welcome_notification_service.dart';
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

  Future<void> _handlePostLoginRedirect({bool fromGoogle = false}) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) return;

    final route = fromGoogle
        ? await googlePostAuthRoute()
        : await expectedHomeForCurrentVariant();
    if (!mounted) return;

    if (route != null) {
      context.go(route);
    } else {
      await ref.read(authServiceProvider).signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This account belongs to the TRYP Driver app. '
            'Use a passenger account to continue.',
          ),
          backgroundColor: TRYPColors.error,
        ),
      );
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

      WelcomeNotificationService.showWelcomeNotification(
        callback: (title, body) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title\n$body'),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              backgroundColor: TRYPColors.secondary,
            ),
          );
        },
      );

      await _handlePostLoginRedirect();
    } catch (error) {
      if (!mounted) return;
      _logger.e('Login error: $error');
      final message = error is AuthException
          ? error.message
          : 'Login failed. Please check your credentials and try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: TRYPColors.error),
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
                              'Welcome back',
                              style: TRYPTypography.headingLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Log in to continue your ride.',
                              style: TRYPTypography.bodyLarge.copyWith(
                                color: TRYPColors.grey,
                              ),
                            ),
                            const SizedBox(height: 28),

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
                            const SizedBox(height: 12),

                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () =>
                                    context.go(Routes.forgotPassword),
                                style: TextButton.styleFrom(
                                  foregroundColor: TRYPColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: TRYPTypography.labelMedium.copyWith(
                                    color: TRYPColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            PrimaryButton(
                              label: 'Log in',
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
                                            .signInWithGoogleNative();
                                        if (!mounted || !signedIn) return;
                                        await _handlePostLoginRedirect(
                                          fromGoogle: true,
                                        );
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
            Text(label, style: TRYPTypography.labelMedium),
          ],
        ),
      ),
    );
  }
}
