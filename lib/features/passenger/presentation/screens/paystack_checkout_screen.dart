import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/payment_checkout_result.dart';

class PaystackCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String callbackUrl;
  final Future<String> Function() verifyPayment;

  const PaystackCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.callbackUrl,
    required this.verifyPayment,
  });

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _WebCheckoutInstructions extends StatelessWidget {
  final bool checkoutOpened;
  final VoidCallback onOpenCheckout;
  final VoidCallback onCheckPayment;

  const _WebCheckoutInstructions({
    required this.checkoutOpened,
    required this.onOpenCheckout,
    required this.onCheckPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: TRYPColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: TRYPColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                checkoutOpened ? 'Complete your payment' : 'Secure payment',
                textAlign: TextAlign.center,
                style: TRYPTypography.headingSmall,
              ),
              const SizedBox(height: 10),
              Text(
                checkoutOpened
                    ? 'Paystack is open in a secure browser tab. Finish the payment there, then return here to confirm your ride.'
                    : 'You will be redirected to Paystack’s secure checkout to complete your payment.',
                textAlign: TextAlign.center,
                style: TRYPTypography.bodyMedium.copyWith(
                  color: TRYPColors.grey,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onOpenCheckout,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(
                    checkoutOpened ? 'Open Paystack again' : 'Open Paystack',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TRYPColors.primary,
                    foregroundColor: TRYPColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (checkoutOpened) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onCheckPayment,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('I completed payment'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TRYPColors.primary,
                      side: const BorderSide(color: TRYPColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Your payment is verified securely by TRYP before the ride request continues.',
                textAlign: TextAlign.center,
                style: TRYPTypography.bodySmall.copyWith(height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  WebViewController? _controller;
  Timer? _webVerificationTimer;
  bool _isLoading = true;
  bool _isHandlingReturn = false;
  bool _webCheckoutOpened = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _isLoading = false;
    } else {
      _initializeMobileCheckout();
    }
  }

  void _initializeMobileCheckout() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(TRYPColors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _progress = progress;
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (url) {
            if (_isReturnUrl(url)) {
              unawaited(_handleReturn());
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            debugPrint('Paystack checkout WebView error: ${error.description}');
          },
          onNavigationRequest: (request) {
            if (_isReturnUrl(request.url)) {
              unawaited(_handleReturn());
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  Future<void> _openWebCheckout() async {
    _webVerificationTimer?.cancel();
    final uri = Uri.tryParse(widget.checkoutUrl);
    if (uri == null || !uri.hasScheme) {
      if (mounted) {
        _showWebMessage('Paystack returned an invalid checkout URL.');
      }
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;

    if (!launched) {
      _showWebMessage(
        'Unable to open Paystack. Check your browser permissions and try again.',
      );
      return;
    }

    setState(() {
      _webCheckoutOpened = true;
      _isLoading = false;
    });
    _webVerificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_checkWebPayment(silent: true)),
    );
  }

  Future<void> _checkWebPayment({bool silent = false}) async {
    if (_isHandlingReturn || !mounted) return;
    setState(() => _isHandlingReturn = true);

    try {
      final status = (await widget.verifyPayment()).trim().toLowerCase();
      if (!mounted) return;
      if (status == 'paid' || status == 'failed' || status == 'cancelled') {
        Navigator.of(context).pop(paymentCheckoutResultForStatus(status));
        return;
      }

      setState(() => _isHandlingReturn = false);
      if (!silent) {
        _showWebMessage('Payment is still being confirmed by Paystack.');
      }
    } catch (error) {
      debugPrint('Paystack web payment check failed: $error');
      if (!mounted) return;
      setState(() => _isHandlingReturn = false);
      if (!silent) {
        _showWebMessage('Could not check payment status. Please try again.');
      }
    }
  }

  void _showWebMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: TRYPColors.primary),
    );
  }

  bool _isReturnUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    final callback = Uri.tryParse(widget.callbackUrl);
    if (uri == null) return false;

    final matchesConfiguredCallback =
        callback != null &&
        uri.scheme == callback.scheme &&
        uri.host == callback.host &&
        uri.path == callback.path;
    return matchesConfiguredCallback || _isPaystackCloseUrl(uri);
  }

  bool _isPaystackCloseUrl(Uri uri) {
    return uri.scheme == 'https' &&
        uri.host == 'standard.paystack.co' &&
        uri.path == '/close';
  }

  Future<String> _verifyWithRetries() async {
    var status = 'unverified';
    for (var attempt = 0; attempt < 3; attempt++) {
      status = (await widget.verifyPayment()).trim().toLowerCase();
      if (status == 'paid' || status == 'failed' || status == 'cancelled') {
        return status;
      }
      if (attempt < 2) {
        await Future<void>.delayed(Duration(seconds: attempt + 1));
      }
    }
    return status;
  }

  Future<void> _handleReturn() async {
    if (_isHandlingReturn || !mounted) return;
    setState(() => _isHandlingReturn = true);

    try {
      final status = await _verifyWithRetries();
      if (!mounted) return;
      Navigator.of(context).pop(paymentCheckoutResultForStatus(status));
    } catch (error) {
      debugPrint('Paystack return verification failed: $error');
      if (mounted) {
        Navigator.of(context).pop(PaymentCheckoutResult.pending);
      }
    }
  }

  Future<void> _closeCheckout() async {
    if (_isHandlingReturn || !mounted) return;
    setState(() => _isHandlingReturn = true);

    try {
      // Use the same retry window as the callback path. An unresolved status
      // is pending, not cancelled, because Paystack/webhook settlement may be
      // delayed after the user closes the hosted checkout.
      final status = await _verifyWithRetries();
      if (!mounted) return;
      Navigator.of(context).pop(paymentCheckoutResultForStatus(status));
    } catch (error) {
      debugPrint('Paystack close verification failed: $error');
      if (mounted) Navigator.of(context).pop(PaymentCheckoutResult.pending);
    }
  }

  @override
  void dispose() {
    _webVerificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_closeCheckout());
      },
      child: Scaffold(
        backgroundColor: TRYPColors.white,
        appBar: AppBar(
          backgroundColor: TRYPColors.white,
          foregroundColor: TRYPColors.secondary,
          elevation: 0,
          title: const Text('Secure Paystack checkout'),
          leading: IconButton(
            tooltip: 'Close checkout',
            onPressed: () => unawaited(_closeCheckout()),
            icon: const Icon(Icons.close_rounded),
          ),
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress / 100 : null,
                    backgroundColor: TRYPColors.inputFill,
                    color: TRYPColors.primary,
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            if (kIsWeb)
              _WebCheckoutInstructions(
                checkoutOpened: _webCheckoutOpened,
                onOpenCheckout: () => unawaited(_openWebCheckout()),
                onCheckPayment: () => unawaited(_checkWebPayment()),
              )
            else if (_controller != null)
              WebViewWidget(controller: _controller!),
            if (_isHandlingReturn)
              ColoredBox(
                color: Colors.white.withValues(alpha: 0.92),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: TRYPColors.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Confirming your payment…',
                        style: TRYPTypography.titleMedium,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
