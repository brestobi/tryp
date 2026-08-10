import 'dart:async';

import 'package:flutter/material.dart';
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

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isHandlingReturn = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
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
            WebViewWidget(controller: _controller),
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
