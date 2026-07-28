import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class PhoneVerificationScreenPage extends StatefulWidget {
  const PhoneVerificationScreenPage({Key? key}) : super(key: key);

  @override
  State<PhoneVerificationScreenPage> createState() => _PhoneVerificationScreenPageState();
}

class _PhoneVerificationScreenPageState extends State<PhoneVerificationScreenPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _verifyCode() {
    if (_codeController.text.isEmpty) return;
    setState(() => _isLoading = true);
    // TODO: implement OTP verification
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.go(Routes.roleSelection);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        title: const Text('Phone Verification'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(
                'Enter the 6-digit code sent to your phone',
                style: TRYPTypography.bodyLarge.copyWith(
                  color: TRYPColors.secondary,
                ),
              ),
              const SizedBox(height: 24),
              CustomTextField(
                label: 'Verification code',
                hint: '123 456',
                controller: _codeController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Text(
                'Didn’t receive a code? Resend in 00:30',
                style: TRYPTypography.bodySmall.copyWith(
                  color: TRYPColors.grey,
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Verify',
                onPressed: _verifyCode,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
