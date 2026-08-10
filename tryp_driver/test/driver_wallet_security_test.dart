import 'package:flutter_test/flutter_test.dart';
import 'package:tryp_driver/core/models/driver_wallet_model.dart';

void main() {
  test(
    'online funds are represented as gross held funds while net position subtracts fees',
    () {
      final wallet = DriverWalletModel.fromJson({
        'driver_id': 'driver-1',
        'cash_collected': 250,
        'online_held': 500,
        'cash_platform_fee_owed': 37.5,
        'platform_fees_total': 112.5,
        'updated_at': '2026-08-10T12:00:00.000Z',
      });

      expect(wallet.cashCollected, 250);
      expect(wallet.onlineHeld, 500);
      expect(wallet.netPosition, 637.5);
    },
  );
}
