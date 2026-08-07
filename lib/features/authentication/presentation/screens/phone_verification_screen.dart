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

/// Phone Verification Screen — Bolt-style: white bg, bold headline, OTP boxes, pill CTA
class PhoneVerificationScreenPage extends ConsumerStatefulWidget {
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

  static const int _resendCooldown = 30;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
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
      context.go(postVerificationRoute());
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

  @override
  Widget build(BuildContext context) {
    final maskedPhone = widget.phone.isNotEmpty
        ? '${widget.phone.substring(0, widget.phone.length > 6 ? widget.phone.length - 4 : 1)}••••'
        : 'your phone';
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: TRYPColors.secondary, size: 24),
          onPressed: () => context.canPop() ? context.pop() : context.go(Routes.login),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, 8, 28, bottomPad + 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: TRYPColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.sms_outlined,
                    size: 28,
                    color: TRYPColors.secondary,
                  ),
                ),
                const SizedBox(height: 24),

                Text('Enter code.', style: TRYPTypography.headingLarge),
                const SizedBox(height: 6),
                Text(
                  'We sent a 6-digit code to $maskedPhone',
                  style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
                ),
                const SizedBox(height: 36),

                // OTP Input — large monospace field
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  autofocus: true,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) {
                    if (v.length == 6) _verifyCode();
                  },
                  style: TRYPTypography.headingMedium.copyWith(
                    letterSpacing: 10,
                    color: TRYPColors.secondary,
                  ),
                  decoration: InputDecoration(
                    hintText: '------',
                    hintStyle: TRYPTypography.headingMedium.copyWith(
                      letterSpacing: 10,
                      color: TRYPColors.greyLight,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: TRYPColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                          color: TRYPColors.secondary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 20),
                  ),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: TRYPColors.error, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TRYPTypography.bodySmall
                              .copyWith(color: TRYPColors.error),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // Resend row
                Row(
                  children: [
                    Text(
                      "Didn't receive it? ",
                      style: TRYPTypography.bodySmall,
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
                                color: TRYPColors.secondary,
                              ),
                            )
                          : Text(
                              _countdownLabel,
                              style: TRYPTypography.bodySmall.copyWith(
                                color: _secondsRemaining == 0
                                    ? TRYPColors.secondary
                                    : TRYPColors.grey,
                                fontWeight: _secondsRemaining == 0
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                decoration: _secondsRemaining == 0
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                              ),
                            ),
                    ),
                  ],
                ),

                const Spacer(),

                // Verify CTA
                PrimaryButton(
                  label: 'Verify',
                  onPressed: _verifyCode,
                  isLoading: _isVerifying,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
