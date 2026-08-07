import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/app/app_variant.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/services/supabase_service.dart';
import 'package:tryp_driver/core/services/welcome_notification_service.dart';
import 'package:tryp_driver/core/utils/validators.dart';
import 'package:tryp_driver/core/widgets/common_widgets.dart';

/// Driver Login Screen — High-contrast dark/white UI with Driver Console badge & Google Cloud OAuth
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

    // Check user profile role & status in Supabase
    try {
      final profile = await client
          .from('profiles')
          .select('role, driver_status')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final role = profile?['role'] as String?;
      final status = profile?['driver_status'] as String? ?? 'pending';

      if (role == 'driver') {
        if (status == 'approved' || status == 'under_review') {
          context.go(Routes.driverHome);
        } else {
          context.go(Routes.driverOnboarding);
        }
      } else {
        // Account exists but is registered as passenger
        await ref.read(authServiceProvider).signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This account is registered as a Passenger. Please log in using the TRYP Passenger app.',
            ),
            backgroundColor: TRYPColors.error,
          ),
        );
      }
    } catch (e) {
      _logger.e('Error checking post login role: $e');
      if (mounted) context.go(Routes.driverHome);
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
      _logger.e('Driver Login error: $error');
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

                    // Driver Portal Pill Badge
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
                            Icons.directions_car_rounded,
                            size: 14,
                            color: TRYPColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'TRYP DRIVER PORTAL',
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
                              'Driver Login',
                              style: TRYPTypography.headingLarge.copyWith(
                                color: TRYPColors.secondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in to access your trip requests and earnings console.',
                              style: TRYPTypography.bodyLarge.copyWith(
                                color: TRYPColors.grey,
                                fontSize: 14,
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
                              label: 'Access Driver Console',
                              onPressed: _submit,
                              isLoading: _isLoading,
                              enabled: !_isLoading,
                              backgroundColor: TRYPColors.primary,
                              foregroundColor: TRYPColors.white,
                            ),
                            const SizedBox(height: 24),

                            const LabeledDivider(label: 'or sign in with'),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: _SocialButton(
                                    label: 'Google Cloud',
                                    icon: Icons.g_mobiledata,
                                    onTap: () async {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      setState(() => _isLoading = true);
                                      try {
                                        await ref
                                            .read(authServiceProvider)
                                            .signInWithGoogleNative();
                                        if (!mounted) return;

                                        // Ensure profile role is set to driver
                                        final client = Supabase.instance.client;
                                        final user = client.auth.currentUser;
                                        if (user != null) {
                                          await client.from('profiles').upsert({
                                            'id': user.id,
                                            'role': 'driver',
                                            'updated_at': DateTime.now()
                                                .toIso8601String(),
                                          });
                                        }

                                        if (!mounted) return;
                                        await _handlePostLoginRedirect();
                                      } catch (e) {
                                        if (!mounted) return;
                                        setState(() => _isLoading = false);
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Google sign-in error: $e',
                                            ),
                                            backgroundColor: TRYPColors.error,
                                          ),
                                        );
                                      }
                                    },
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
                                    'Don\'t have a driver account? ',
                                    style: TRYPTypography.bodyMedium.copyWith(
                                      color: TRYPColors.grey,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => context.go(Routes.register),
                                    child: Text(
                                      'Register Now',
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
