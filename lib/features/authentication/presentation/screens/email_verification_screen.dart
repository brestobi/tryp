import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

/// Email Verification Screen
class EmailVerificationScreenPage extends ConsumerStatefulWidget {
  final String email;
  final bool isSignUp;

  const EmailVerificationScreenPage({
    super.key,
    required this.email,
    this.isSignUp = true,
  });

  @override
  ConsumerState<EmailVerificationScreenPage> createState() =>
      _EmailVerificationScreenPageState();
}

class _EmailVerificationScreenPageState
    extends ConsumerState<EmailVerificationScreenPage> {
  final _logger = Logger();
  
  // 8 controllers for 8 digits
  final List<TextEditingController> _controllers = List.generate(8, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(8, (_) => FocusNode());

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
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
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
      if (!widget.isSignUp) {
        final authService = ref.read(authServiceProvider);
        await authService.sendEmailOTP(widget.email);
      }
      if (!mounted) return;
      _startCountdown();
    } catch (e) {
      _logger.e('Failed to send OTP: $e');
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to send verification code.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _controllers.map((c) => c.text).join();
    if (code.length != 8) {
      setState(() => _errorMessage = 'Please enter a valid 8-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final supabase = ref.read(supabaseClientProvider);
      await supabase.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: widget.isSignUp ? OtpType.signup : OtpType.email,
      );
      if (!mounted) return;
      context.go(Routes.roleSelection);
    } catch (e) {
      _logger.e('OTP verification failed: $e');
      if (!mounted) return;
      setState(() => _errorMessage = 'Invalid or expired code. Check your email and try again.');
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
              Text('Verify your email', style: TRYPTypography.headingLarge),
              const SizedBox(height: 10),
              Text(
                widget.isSignUp
                    ? 'We sent an 8-digit confirmation code to\n${widget.email}'
                    : 'Enter the code sent to ${widget.email}',
                style: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
              ),
              const SizedBox(height: 30),
              
              // Custom PIN Input Field
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(8, (index) {
                  return SizedBox(
                    width: 35,
                    child: TextFormField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TRYPTypography.headingSmall,
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: TRYPColors.inputFill,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty && index < 7) {
                          _focusNodes[index + 1].requestFocus();
                        } else if (value.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                      },
                    ),
                  );
                }),
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
