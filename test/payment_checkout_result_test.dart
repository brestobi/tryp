import 'package:flutter_test/flutter_test.dart';
import 'package:tryp/core/services/payment_checkout_result.dart';

void main() {
  group('Paystack checkout result mapping', () {
    test('maps definitive server outcomes', () {
      expect(
        paymentCheckoutResultForStatus('paid'),
        PaymentCheckoutResult.paid,
      );
      expect(
        paymentCheckoutResultForStatus('failed'),
        PaymentCheckoutResult.failed,
      );
      expect(
        paymentCheckoutResultForStatus('cancelled'),
        PaymentCheckoutResult.cancelled,
      );
    });

    test('keeps unresolved outcomes pending', () {
      expect(
        paymentCheckoutResultForStatus('unverified'),
        PaymentCheckoutResult.pending,
      );
      expect(
        paymentCheckoutResultForStatus('processing'),
        PaymentCheckoutResult.pending,
      );
      expect(
        paymentCheckoutResultForStatus('temporary network error'),
        PaymentCheckoutResult.pending,
      );
      expect(
        paymentCheckoutResultForStatus('PAID'),
        PaymentCheckoutResult.paid,
      );
    });
  });
}
