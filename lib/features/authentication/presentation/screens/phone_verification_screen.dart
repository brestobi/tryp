import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class PhoneVerificationScreenPage extends ConsumerStatefulWidget {
  /// The phone number that was used to trigger the OTP SMS.
  final String phone;

  const PhoneVerificationScreenPage({
    super.key,
    required this.phone,
  });

  @override
  ConsumerState<PhoneVerificationScreenPage> createState() =>
      _PhoneVerificationScreenPageState();
}

class _PhoneVerificationScreenPageState
    extends ConsumerState<PhoneVerificationScreenPage> {
  final _logger = Logger();
  final _codeController = TextEditingController();

  bool _isVerifying = false;
  bool _isSending = false;
  String? _errorMessage;

  // Resend countdown
  static const int _resendCooldown = 30;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Kick off OTP send immediately when screen opens (if phone is provided).
    if (widget.phone.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendOTP());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _sendOTP() async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _errorMessage = null;
    });
    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendPhoneOTP(widget.phone);
      if (!mounted) return;
      _startCountdown();
    } catch (e) {
      _logger.e('Failed to send OTP: $e');
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter the verification code.');
      return;
    }
    if (code.length != 6) {
      setState(() => _errorMessage = 'Code must be exactly 6 digits.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyOTP(widget.phone, code);
      if (!mounted) return;
      context.go(Routes.roleSelection);
    } catch (e) {
      _logger.e('OTP verification failed: $e');
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('Token has expired') || raw.contains('expired')) {
      return 'Code has expired. Please request a new one.';
    }
    if (raw.contains('Invalid') || raw.contains('invalid')) {
      return 'Invalid code. Please check and try again.';
    }
    if (raw.contains('rate limit') || raw.contains('too many')) {
      return 'Too many attempts. Please wait a moment before retrying.';
    }
    return 'Something went wrong. Please try again.';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final maskedPhone = widget.phone.isNotEmpty
        ? '${widget.phone.substring(0, widget.phone.length > 6 ? widget.phone.length - 4 : 1)}****'
        : 'your phone';

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

              // Header
              Text(
                'Enter verification code',
                style: TRYPTypography.headingMedium.copyWith(
                  color: TRYPColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to $maskedPhone',
                style: TRYPTypography.bodyLarge.copyWith(
                  color: TRYPColors.grey,
                ),
              ),
              const SizedBox(height: 32),

              // OTP input
              CustomTextField(
                label: 'Verification code',
                hint: '123456',
                controller: _codeController,
                keyboardType: TextInputType.number,
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TRYPTypography.bodySmall.copyWith(
                          color: Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Resend row
              Row(
                children: [
                  Text(
                    "Didn't receive a code? ",
                    style: TRYPTypography.bodySmall.copyWith(
                      color: TRYPColors.grey,
                    ),
                  ),
                  GestureDetector(
                    onTap: _secondsRemaining == 0 && !_isSending
                        ? _sendOTP
                        : null,
                    child: _isSending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: TRYPColors.primary,
                            ),
                          )
                        : Text(
                            _countdownLabel,
                            style: TRYPTypography.bodySmall.copyWith(
                              color: _secondsRemaining == 0
                                  ? TRYPColors.primary
                                  : TRYPColors.grey,
                              fontWeight: _secondsRemaining == 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Verify button
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
