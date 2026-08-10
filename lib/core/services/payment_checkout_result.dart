/// Outcome returned when the hosted Paystack checkout is left.
enum PaymentCheckoutResult { paid, failed, cancelled, pending }

/// Convert a server verification status into a checkout result.
///
/// An unknown or temporarily unresolved status must remain pending rather than
/// being treated as cancellation, because Paystack/webhook settlement can lag
/// behind the checkout redirect.
PaymentCheckoutResult paymentCheckoutResultForStatus(String status) {
  switch (status.trim().toLowerCase()) {
    case 'paid':
      return PaymentCheckoutResult.paid;
    case 'failed':
      return PaymentCheckoutResult.failed;
    case 'cancelled':
      return PaymentCheckoutResult.cancelled;
    case 'pending':
    case 'processing':
    case 'unverified':
    default:
      return PaymentCheckoutResult.pending;
  }
}
