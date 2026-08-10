import 'package:flutter_test/flutter_test.dart';
import 'package:tryp_driver/core/models/driver_wallet_model.dart';

void main() {
  test('parses authoritative wallet buckets and calculates net position', () {
    final wallet = DriverWalletModel.fromJson({
      'driver_id': 'driver-1',
      'cash_collected': 100.00,
      'online_held': 80.00,
      'cash_platform_fee_owed': 15.00,
      'platform_fees_total': 30.00,
      'updated_at': '2026-08-10T12:00:00.000Z',
    });

    expect(wallet.cashCollected, 100.00);
    expect(wallet.onlineHeld, 80.00);
    expect(wallet.cashPlatformFeeOwed, 15.00);
    expect(wallet.platformFeesTotal, 30.00);
    expect(wallet.netPosition, 150.00);
  });

  test('missing numeric values safely default to zero', () {
    final wallet = DriverWalletModel.fromJson({
      'driver_id': 'driver-1',
      'updated_at': '2026-08-10T12:00:00.000Z',
    });

    expect(wallet.cashCollected, 0);
    expect(wallet.onlineHeld, 0);
    expect(wallet.cashPlatformFeeOwed, 0);
    expect(wallet.netPosition, 0);
  });
}
