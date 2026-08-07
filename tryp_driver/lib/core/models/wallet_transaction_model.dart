enum TransactionType {
  topup,
  farePayment,
  driverPayout,
  refund,
}

class WalletTransactionModel {
  final String id;
  final String userId;
  final double amount;
  final TransactionType type;
  final String paymentMethod;
  final String reference;
  final String status;
  final DateTime timestamp;

  const WalletTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.paymentMethod,
    required this.reference,
    required this.status,
    required this.timestamp,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    TransactionType txType;
    switch (json['type'] as String? ?? 'topup') {
      case 'fare_payment':
        txType = TransactionType.farePayment;
        break;
      case 'driver_payout':
        txType = TransactionType.driverPayout;
        break;
      case 'refund':
        txType = TransactionType.refund;
        break;
      case 'topup':
      default:
        txType = TransactionType.topup;
        break;
    }

    return WalletTransactionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: txType,
      paymentMethod: json['payment_method'] as String? ?? 'Paystack',
      reference: json['reference'] as String? ?? '',
      status: json['status'] as String? ?? 'completed',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'type': type.name,
      'payment_method': paymentMethod,
      'reference': reference,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
