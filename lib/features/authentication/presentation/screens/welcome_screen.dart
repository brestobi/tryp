import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class WelcomeScreenPage extends StatelessWidget {
  const WelcomeScreenPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome to TRYP',
                style: TRYPTypography.headingLarge.copyWith(
                  color: TRYPColors.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Move Smart. Move Safe.',
                style: TRYPTypography.bodyLarge.copyWith(
                  color: TRYPColors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              PrimaryButton(
                label: 'Login',
                onPressed: () => context.go(Routes.login),
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                label: 'Register',
                onPressed: () => context.go(Routes.register),
              ),
              const SizedBox(height: 24),
              Text(
                'Or continue with',
                style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _SocialLoginButton(icon: Icons.g_mobiledata),
                  SizedBox(width: 12),
                  _SocialLoginButton(icon: Icons.facebook),
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

  const _SocialLoginButton({Key? key, required this.icon}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: TRYPColors.lightGrey,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: TRYPColors.secondary, size: 28),
    );
  }
}
