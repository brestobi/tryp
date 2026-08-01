import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

/// Email Verification Screen
class EmailVerificationScreenPage extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreenPage({
    super.key,
    required this.email,
  });

  @override
  ConsumerState<EmailVerificationScreenPage> createState() =>
      _EmailVerificationScreenPageState();
}

class _EmailVerificationScreenPageState
    extends ConsumerState<EmailVerificationScreenPage> {
  final _logger = Logger();
  final _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isSending = false;
  String? _errorMessage;

  static const int _resendCooldown = 30;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendOTP());
  }

  @override
  void dispose() {
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = _resendCooldown);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String get _countdownLabel {
    if (_secondsRemaining == 0) return 'Resend code';
    final mins = _secondsRemaining ~/ 60;
    final secs = _secondsRemaining % 60;
    return 'Resend in ${mins > 0 ? '${mins.toString().padLeft(2, '0')}:' : ''}${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _sendOTP() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendEmailOTP(widget.email);
      if (!mounted) return;
      _startCountdown();
    } catch (e) {
      _logger.e('Failed to send OTP: $e');
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to send OTP.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyEmailOTP(widget.email, code);
      if (!mounted) return;
      context.go(Routes.roleSelection);
    } catch (e) {
      _logger.e('OTP verification failed: $e');
      if (!mounted) return;
      setState(() => _errorMessage = 'Invalid or expired code.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TRYPColors.secondary),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Verify Email', style: TRYPTypography.headingLarge),
              const SizedBox(height: 10),
              Text('We sent a code to ${widget.email}', style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey)),
              const SizedBox(height: 30),
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TRYPTypography.headingMedium.copyWith(letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '------',
                  counterText: '',
                  filled: true,
                  fillColor: TRYPColors.inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_errorMessage!, style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.error)),
                ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: _secondsRemaining == 0 ? _sendOTP : null,
                child: Text(_countdownLabel),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Verify',
                onPressed: _verifyCode,
                isLoading: _isVerifying,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
