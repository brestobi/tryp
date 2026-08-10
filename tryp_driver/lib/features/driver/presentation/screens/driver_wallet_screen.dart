import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/models/driver_wallet_model.dart';
import 'package:tryp_driver/core/services/driver_wallet_service.dart';
import 'package:tryp_driver/core/services/supabase_service.dart';
import 'package:tryp_driver/core/widgets/driver_bottom_nav_bar.dart';

class DriverWalletScreen extends ConsumerStatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  ConsumerState<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends ConsumerState<DriverWalletScreen> {
  late final DriverWalletService _walletService;
  RealtimeChannel? _walletChannel;
  DriverWalletModel? _wallet;
  List<DriverWalletTransactionModel> _transactions = [];
  bool _loading = true;
  bool _unlocked = false;
  bool _hasPin = false;
  bool _biometricsAvailable = false;
  bool _biometricsEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _walletService = DriverWalletService(ref.read(supabaseClientProvider));
    unawaited(_prepareAccess());
  }

  @override
  void dispose() {
    _walletChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _prepareAccess() async {
    try {
      final hasPin = await _walletService.hasPin();
      final biometricsAvailable = await _walletService.biometricsAvailable();
      final biometricsEnabled = await _walletService.biometricsEnabled();
      if (!mounted) return;
      setState(() {
        _hasPin = hasPin;
        _biometricsAvailable = biometricsAvailable;
        _biometricsEnabled = biometricsEnabled;
        _loading = false;
      });

      if (hasPin && biometricsAvailable && biometricsEnabled) {
        await _unlockWithBiometrics();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Wallet security could not be prepared. Please try again.';
      });
    }
  }

  Future<void> _unlockWithBiometrics() async {
    final authenticated = await _walletService.authenticateWithBiometrics();
    if (authenticated) await _loadWallet();
  }

  Future<void> _unlockWithPin(String pin) async {
    try {
      final lockout = await _walletService.pinLockoutRemaining();
      if (lockout != null) {
        _showError(
          'Too many failed attempts. Try again in ${lockout.inSeconds + 1} seconds.',
        );
        return;
      }
      final valid = await _walletService.verifyPin(pin);
      if (!valid) {
        _showError('Incorrect wallet PIN.');
        return;
      }
      await _loadWallet();
    } on ArgumentError {
      _showError('Enter your 4 to 6 digit wallet PIN.');
    }
  }

  Future<void> _createPin(String pin, String confirmation) async {
    if (pin != confirmation) {
      _showError('The PINs do not match.');
      return;
    }
    try {
      await _walletService.setPin(pin);
      if (!mounted) return;
      setState(() => _hasPin = true);
      await _loadWallet();
      if (_biometricsAvailable && mounted) {
        final enable = await _askToEnableBiometrics();
        if (enable) {
          final authenticated = await _walletService
              .authenticateWithBiometrics();
          if (mounted && authenticated) {
            setState(() => _biometricsEnabled = true);
          }
        }
      }
    } on ArgumentError {
      _showError('Enter a 4 to 6 digit PIN.');
    }
  }

  Future<bool> _askToEnableBiometrics() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use biometrics next time?'),
        content: const Text(
          'You can use your phone fingerprint or face unlock instead of entering your wallet PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _loadWallet() async {
    try {
      final wallet = await _walletService.fetchWallet();
      final transactions = await _walletService.fetchTransactions();
      final driverId = ref.read(supabaseClientProvider).auth.currentUser?.id;
      if (!mounted || driverId == null) return;
      _walletChannel?.unsubscribe();
      _walletChannel = _walletService.subscribeToWallet(
        driverId: driverId,
        onChanged: (record) {
          if (!mounted || record.isEmpty) return;
          setState(() => _wallet = DriverWalletModel.fromJson(record));
          unawaited(_refreshTransactions());
        },
      );
      setState(() {
        _wallet = wallet;
        _transactions = transactions;
        _unlocked = true;
        _error = null;
      });
    } catch (_) {
      _showError(
        'Could not load your wallet. Check your connection and retry.',
      );
    }
  }

  Future<void> _refreshTransactions() async {
    try {
      final transactions = await _walletService.fetchTransactions();
      if (mounted) setState(() => _transactions = transactions);
    } catch (_) {
      // Keep the last known transactions visible during a transient update.
    }
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.surface,
      appBar: AppBar(
        title: Text('Driver Wallet', style: TRYPTypography.headingSmall),
        actions: [
          if (_unlocked && _biometricsAvailable)
            IconButton(
              onPressed: _unlockWithBiometrics,
              icon: Icon(
                _biometricsEnabled
                    ? Icons.fingerprint_rounded
                    : Icons.fingerprint_outlined,
              ),
              tooltip: _biometricsEnabled
                  ? 'Authenticate with biometrics'
                  : 'Enable biometrics next time',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _unlocked
          ? _buildWallet()
          : _buildLockScreen(),
      bottomNavigationBar: const DriverBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildLockScreen() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: TRYPColors.secondary,
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: TRYPColors.white,
            size: 56,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _hasPin ? 'Wallet locked' : 'Protect your wallet',
          style: TRYPTypography.headingMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _hasPin
              ? 'Enter your wallet PIN to view your cash collected and online payments held by TRYP.'
              : 'Create a private PIN before viewing your driver balances. Your PIN is stored only as an encrypted hash on this device.',
          style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
        ),
        const SizedBox(height: 24),
        if (_hasPin)
          _PinForm(buttonLabel: 'Unlock wallet', onSubmit: _unlockWithPin)
        else
          _SetupPinForm(onSubmit: _createPin),
        if (_hasPin && _biometricsAvailable) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _unlockWithBiometrics,
            icon: const Icon(Icons.fingerprint_rounded),
            label: Text(
              _biometricsEnabled
                  ? 'Use phone biometrics'
                  : 'Set up phone biometrics',
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.error),
          ),
        ],
      ],
    );
  }

  Widget _buildWallet() {
    final wallet = _wallet!;
    return RefreshIndicator(
      onRefresh: _loadWallet,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: TRYPColors.secondary,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recorded wallet position',
                  style: TRYPTypography.bodySmall.copyWith(
                    color: TRYPColors.secondaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'R${wallet.netPosition.toStringAsFixed(2)}',
                  style: TRYPTypography.headingXL.copyWith(
                    color: TRYPColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Online funds are held by TRYP and are not yet payout-ready • updated ${_formatTime(wallet.updatedAt)}',
                  style: TRYPTypography.bodySmall.copyWith(
                    color: TRYPColors.secondaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BalanceCard(
                  icon: Icons.payments_outlined,
                  label: 'Cash collected',
                  amount: wallet.cashCollected,
                  color: TRYPColors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceCard(
                  icon: Icons.account_balance_outlined,
                  label: 'Online held by TRYP',
                  amount: wallet.onlineHeld,
                  color: TRYPColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            label: 'Cash platform fees owed',
            amount: wallet.cashPlatformFeeOwed,
            icon: Icons.receipt_long_outlined,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent settlements', style: TRYPTypography.headingSmall),
              const Icon(Icons.lock_rounded, size: 17, color: TRYPColors.grey),
            ],
          ),
          const SizedBox(height: 10),
          if (_transactions.isEmpty)
            _emptyTransactions()
          else
            ..._transactions.map(
              (transaction) => _TransactionTile(transaction: transaction),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyTransactions() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: TRYPColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: TRYPColors.divider),
    ),
    child: Text(
      'Completed rides will appear here once they are settled.',
      style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
    ),
  );

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _PinForm extends StatefulWidget {
  final String buttonLabel;
  final Future<void> Function(String pin) onSubmit;

  const _PinForm({required this.buttonLabel, required this.onSubmit});

  @override
  State<_PinForm> createState() => _PinFormState();
}

class _PinFormState extends State<_PinForm> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Wallet PIN',
            prefixIcon: Icon(Icons.lock_outline_rounded),
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting
                ? null
                : () async {
                    setState(() => _submitting = true);
                    await widget.onSubmit(_controller.text);
                    if (mounted) setState(() => _submitting = false);
                  },
            child: Text(_submitting ? 'Checking...' : widget.buttonLabel),
          ),
        ),
      ],
    );
  }
}

class _SetupPinForm extends StatefulWidget {
  final Future<void> Function(String pin, String confirmation) onSubmit;

  const _SetupPinForm({required this.onSubmit});

  @override
  State<_SetupPinForm> createState() => _SetupPinFormState();
}

class _SetupPinFormState extends State<_SetupPinForm> {
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Create PIN',
            prefixIcon: Icon(Icons.pin_outlined),
            counterText: '',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmation,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Confirm PIN',
            prefixIcon: Icon(Icons.verified_user_outlined),
            counterText: '',
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting
                ? null
                : () async {
                    setState(() => _submitting = true);
                    await widget.onSubmit(_pin.text, _confirmation.text);
                    if (mounted) setState(() => _submitting = false);
                  },
            child: Text(_submitting ? 'Saving...' : 'Create secure PIN'),
          ),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final Color color;

  const _BalanceCard({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TRYPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 14),
          Text(label, style: TRYPTypography.bodySmall),
          const SizedBox(height: 4),
          Text(
            'R${amount.toStringAsFixed(2)}',
            style: TRYPTypography.titleLarge.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;

  const _InfoRow({
    required this.label,
    required this.amount,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TRYPColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: TRYPColors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TRYPTypography.bodyMedium)),
          Text(
            'R${amount.toStringAsFixed(2)}',
            style: TRYPTypography.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final DriverWalletTransactionModel transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final cash = transaction.paymentMethod.toLowerCase() == 'cash';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TRYPColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: (cash ? TRYPColors.warning : TRYPColors.success)
                .withValues(alpha: 0.12),
            child: Icon(
              cash ? Icons.payments_outlined : Icons.account_balance_outlined,
              color: cash ? TRYPColors.warning : TRYPColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cash ? 'Cash ride' : 'Online ride held by TRYP',
                  style: TRYPTypography.titleMedium,
                ),
                Text(
                  'Ride ${transaction.rideId.substring(0, 8)} • fee R${transaction.platformFee.toStringAsFixed(2)}',
                  style: TRYPTypography.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            'R${transaction.driverNetAmount.toStringAsFixed(2)}',
            style: TRYPTypography.titleMedium.copyWith(
              color: cash ? TRYPColors.warning : TRYPColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
