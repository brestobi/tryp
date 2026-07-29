import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/notification_service.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class DriverHomeScreenPage extends ConsumerStatefulWidget {
  const DriverHomeScreenPage({Key? key}) : super(key: key);

  @override
  ConsumerState<DriverHomeScreenPage> createState() => _DriverHomeScreenPageState();
}

class _DriverHomeScreenPageState extends ConsumerState<DriverHomeScreenPage> {
  bool _isOnline = false;
  String _driverName = 'Driver';
  String _driverStatus = 'under_review';
  final double _todayEarnings = 450.00;
  final int _completedTripsToday = 3;
  final double _driverRating = 4.9;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkDriverVerificationStatus();
  }

  Future<void> _checkDriverVerificationStatus() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user != null) {
        final profile = await client.from('profiles').select().eq('id', user.id).maybeSingle();
        if (profile != null) {
          setState(() {
            if (profile['driver_status'] != null) {
              _driverStatus = profile['driver_status'];
            }
            if ((profile['full_name'] as String?)?.isNotEmpty == true) {
              _driverName = profile['full_name'];
            } else if (user.email != null && user.email!.contains('@')) {
              _driverName = user.email!.split('@').first;
            }
          });
        }
      }
    } catch (_) {
      // Default to under_review for safety
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOnline() async {
    // SECURITY CHECK: Must be verified to go online!
    if (_driverStatus != 'approved') {
      _showVerificationRequiredDialog();
      return;
    }

    final newOnlineState = !_isOnline;
    setState(() {
      _isOnline = newOnlineState;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('profiles').update({
          'is_online': newOnlineState,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      }
    } catch (e) {
      debugPrint('Error updating driver online status in Supabase: $e');
    }

    ref.read(notificationsProvider.notifier).addNotification(
      title: newOnlineState ? 'Driver Status: Online 🟢' : 'Driver Status: Offline 🔴',
      body: newOnlineState
          ? 'You are now online and available for nearby ride requests.'
          : 'You are now offline and will not receive new ride requests.',
      type: NotificationType.system,
      routePath: Routes.driverHome,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newOnlineState ? 'You are now ONLINE and receiving trip requests' : 'You are now OFFLINE'),
        backgroundColor: newOnlineState ? Colors.green : Colors.orange,
      ),
    );
  }

  void _showVerificationRequiredDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.orange, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Driver Verification Required',
                style: TRYPTypography.headingMedium.copyWith(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'To start accepting rides on TRYP, your South African PrDP license and vehicle registration documents must be verified by our safety team.',
                style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Status indicator chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: TRYPColors.lightGrey,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_empty_rounded, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Text(
                      'Current Status: ${_driverStatus.toUpperCase().replaceAll('_', ' ')}',
                      style: TRYPTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              PrimaryButton(
                label: 'View Required Documents',
                onPressed: () {
                  Navigator.pop(context);
                  context.go(Routes.driverDocuments);
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  // Admin Demo bypass toggle for testing
                  setState(() {
                    _driverStatus = _driverStatus == 'approved' ? 'under_review' : 'approved';
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Demo Status Toggled to: ${_driverStatus.toUpperCase()}'),
                    ),
                  );
                },
                child: Text(
                  _driverStatus == 'approved' ? 'Set Status to Under Review' : 'Demo: Approve Driver Account',
                  style: const TextStyle(color: TRYPColors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSimulatedRideRequest() {
    if (_driverStatus != 'approved') {
      _showVerificationRequiredDialog();
      return;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: TRYPColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'NEW RIDE REQUEST • TRYP Go',
                  style: TRYPTypography.labelLarge.copyWith(
                    color: TRYPColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Verified Passenger', style: TRYPTypography.headingSmall),
                      Text('4.9 ★ Passenger', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
                    ],
                  ),
                  Text('R82.50', style: TRYPTypography.headingMedium.copyWith(color: TRYPColors.secondary)),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location, color: Colors.green),
                title: const Text('Sandton City Mall'),
                subtitle: const Text('1.2 km away (4 min pickup)'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on, color: TRYPColors.secondary),
                title: const Text('Rosebank Mall'),
                subtitle: const Text('Trip distance: 5.2 km'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.go(Routes.activeTrip);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TRYPColors.primary,
                        foregroundColor: TRYPColors.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Accept Ride'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = _driverStatus == 'approved';

    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      appBar: AppBar(
        backgroundColor: TRYPColors.secondary,
        foregroundColor: TRYPColors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: TRYPColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'TRYP DRIVER',
                style: TextStyle(color: TRYPColors.secondary, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isVerified ? Icons.verified_user_rounded : Icons.pending_actions_rounded,
              color: isVerified ? Colors.green : Colors.orange,
            ),
            onPressed: () => context.go(Routes.driverDocuments),
            tooltip: 'Verification Documents',
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: TRYPColors.white),
            onPressed: () => context.go(Routes.passengerHome),
            tooltip: 'Switch to Passenger Mode',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TRYPColors.primary))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verification Status Banner
                    if (!isVerified)
                      GestureDetector(
                        onTap: _showVerificationRequiredDialog,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Verification Pending',
                                      style: TRYPTypography.bodyLarge.copyWith(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Upload & verify PrDP documents to go online.',
                                      style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.orange),
                            ],
                          ),
                        ),
                      ),

                    Row(
                      children: [
                        Text('Welcome, $_driverName', style: TRYPTypography.headingLarge.copyWith(color: TRYPColors.white)),
                        if (isVerified) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.verified_rounded,
                            color: TRYPColors.primary,
                            size: 24,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Toyota Corolla Quest • ND 123-456',
                      style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
                    ),
                    const SizedBox(height: 20),

                    // Status & Earnings Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isOnline ? TRYPColors.primary : TRYPColors.grey.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _isOnline ? Colors.green : (isVerified ? Colors.red : Colors.orange),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isOnline
                                        ? 'ONLINE & READY'
                                        : (isVerified ? 'YOU ARE OFFLINE' : 'UNVERIFIED'),
                                    style: TRYPTypography.labelLarge.copyWith(
                                      color: _isOnline
                                          ? Colors.green
                                          : (isVerified ? Colors.red : Colors.orange),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$_driverRating ★',
                                style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text('Today’s Earnings', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            'R${_todayEarnings.toStringAsFixed(2)}',
                            style: TRYPTypography.headingLarge.copyWith(color: TRYPColors.primary, fontSize: 32),
                          ),
                          const SizedBox(height: 20),

                          // Toggle Online Button with Verification Guard
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !isVerified
                                    ? Colors.grey[800]
                                    : (_isOnline ? Colors.red : TRYPColors.primary),
                                foregroundColor: !isVerified
                                    ? TRYPColors.grey
                                    : (_isOnline ? TRYPColors.white : TRYPColors.secondary),
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _toggleOnline,
                              icon: Icon(!isVerified
                                  ? Icons.lock_outline_rounded
                                  : (_isOnline ? Icons.power_settings_new : Icons.play_arrow_rounded)),
                              label: Text(
                                !isVerified
                                    ? 'VERIFICATION REQUIRED TO GO ONLINE'
                                    : (_isOnline ? 'GO OFFLINE' : 'GO ONLINE'),
                                style: TRYPTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Performance Stats Grid
                    Row(
                      children: [
                        _InfoBox(title: 'Trips Today', value: '$_completedTripsToday'),
                        const SizedBox(width: 12),
                        _InfoBox(title: 'Hours Online', value: '3.5 hrs'),
                        const SizedBox(width: 12),
                        _InfoBox(title: 'Accept Rate', value: '98%'),
                      ],
                    ),

                    const Spacer(),

                    // Test Ride Request Trigger
                    if (isVerified && _isOnline)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: TRYPColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: TRYPColors.primary),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_rounded, color: TRYPColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Test Ride Match',
                                style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.white),
                              ),
                            ),
                            TextButton(
                              onPressed: _showSimulatedRideRequest,
                              child: const Text('Simulate Request'),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String title;
  final String value;

  const _InfoBox({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(title, style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey, fontSize: 11)),
            const SizedBox(height: 6),
            Text(value, style: TRYPTypography.headingSmall.copyWith(color: TRYPColors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
