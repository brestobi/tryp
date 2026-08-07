import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/services/location_service.dart';
import 'package:tryp_driver/core/services/notification_service.dart';
import 'package:tryp_driver/core/services/supabase_service.dart';
import 'package:tryp_driver/core/services/trip_service.dart';
import 'package:tryp_driver/core/widgets/common_widgets.dart';

class DriverHomeScreenPage extends ConsumerStatefulWidget {
  const DriverHomeScreenPage({Key? key}) : super(key: key);

  @override
  ConsumerState<DriverHomeScreenPage> createState() =>
      _DriverHomeScreenPageState();
}

class _DriverHomeScreenPageState extends ConsumerState<DriverHomeScreenPage> {
  bool _isOnline = false;
  String _driverName = 'Driver';
  String _driverStatus = 'under_review';
  String _vehicleInfo = 'Vehicle not set';
  double _todayEarnings = 0.00;
  int _completedTripsToday = 0;
  double _driverRating = 4.9;
  bool _isLoading = false;

  Timer? _locationTimer;
  Timer? _requestsPollTimer;
  RealtimeChannel? _pendingRidesChannel;

  List<TripModel> _openRequests = [];
  TripModel? _currentActiveTrip;
  Position? _currentDriverPosition;

  @override
  void initState() {
    super.initState();
    _checkDriverVerificationStatus();
    _checkForActiveTrip();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _requestsPollTimer?.cancel();
    _pendingRidesChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _checkDriverVerificationStatus() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user != null) {
        final profile = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        if (profile != null) {
          setState(() {
            _driverStatus = profile['driver_status'] ?? 'pending';
            _isOnline = profile['is_online'] ?? false;

            if ((profile['full_name'] as String?)?.isNotEmpty == true) {
              _driverName = profile['full_name'];
            } else if (user.email != null && user.email!.contains('@')) {
              _driverName = user.email!.split('@').first;
            }

            final make = profile['vehicle_make'] as String? ?? '';
            final model = profile['vehicle_model'] as String? ?? '';
            final plate = profile['vehicle_plate'] as String? ?? '';
            if (make.isNotEmpty || model.isNotEmpty) {
              _vehicleInfo =
                  '$make $model ${plate.isNotEmpty ? "• $plate" : ""}'.trim();
            }
          });

          if (_isOnline) {
            _startOnlineTrackingAndListening();
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking driver profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkForActiveTrip() async {
    final tripService = ref.read(tripServiceProvider);
    final activeTrip = await tripService.getDriverActiveTrip();
    if (!mounted) return;
    setState(() {
      _currentActiveTrip = activeTrip;
    });
    if (activeTrip != null) {
      ref.read(activeTripStateProvider.notifier).stateTrip = activeTrip;
    }
  }

  void _startOnlineTrackingAndListening() {
    _locationTimer?.cancel();
    _requestsPollTimer?.cancel();

    // 1. Periodic GPS location broadcast
    _updateAndBroadcastLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      _updateAndBroadcastLocation();
    });

    // 2. Poll & Listen for open ride requests in real-time
    _fetchOpenRequests();
    _requestsPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchOpenRequests();
    });

    // 3. Realtime WebSocket Channel
    final tripService = ref.read(tripServiceProvider);
    _pendingRidesChannel = tripService.subscribeToPendingRides(
      onRideCreatedOrUpdated: () {
        _fetchOpenRequests();
        _checkForActiveTrip();
      },
    );
  }

  void _stopOnlineTrackingAndListening() {
    _locationTimer?.cancel();
    _requestsPollTimer?.cancel();
    _pendingRidesChannel?.unsubscribe();
    _pendingRidesChannel = null;
    setState(() {
      _openRequests = [];
    });
  }

  Future<void> _updateAndBroadcastLocation() async {
    if (!_isOnline) return;
    try {
      final locService = ref.read(locationServiceProvider);
      final pos = await locService.getCurrentPosition();
      if (pos != null) {
        _currentDriverPosition = pos;
        final tripService = ref.read(tripServiceProvider);
        await tripService.updateDriverLocation(
          lat: pos.latitude,
          lng: pos.longitude,
          heading: pos.heading,
          isOnline: true,
        );
      }
    } catch (e) {
      debugPrint('Error updating driver location: $e');
    }
  }

  Future<void> _fetchOpenRequests() async {
    if (!_isOnline || _driverStatus != 'approved') return;

    try {
      final tripService = ref.read(tripServiceProvider);
      final requests = await tripService.getOpenRideRequests();
      if (!mounted) return;

      final previousCount = _openRequests.length;
      setState(() {
        _openRequests = requests;
      });

      // If new request came in, auto-show detail bottom sheet for first request
      if (requests.isNotEmpty &&
          requests.length > previousCount &&
          ModalRoute.of(context)?.isCurrent == true) {
        _showRealRideRequestSheet(requests.first);
      }
    } catch (e) {
      debugPrint('Error fetching open requests: $e');
    }
  }

  Future<void> _toggleOnline() async {
    if (_driverStatus != 'approved') {
      _showVerificationRequiredDialog();
      return;
    }

    final newOnlineState = !_isOnline;
    setState(() => _isOnline = newOnlineState);

    final tripService = ref.read(tripServiceProvider);
    await tripService.setDriverOnlineStatus(newOnlineState);

    if (newOnlineState) {
      _startOnlineTrackingAndListening();
    } else {
      _stopOnlineTrackingAndListening();
    }

    ref
        .read(notificationsProvider.notifier)
        .addNotification(
          title: newOnlineState
              ? 'Driver Status: Online'
              : 'Driver Status: Offline',
          body: newOnlineState
              ? 'You are now online and receiving real-time ride requests from nearby passengers.'
              : 'You are now offline and will not receive ride requests.',
          type: NotificationType.system,
          routePath: Routes.driverHome,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newOnlineState
              ? 'ONLINE — Listening for real-time ride requests'
              : 'OFFLINE',
        ),
        backgroundColor: newOnlineState ? Colors.green : Colors.orange,
      ),
    );
  }

  void _showRealRideRequestSheet(TripModel request) {
    double? pickupDistanceKm;
    if (_currentDriverPosition != null) {
      final meters = Geolocator.distanceBetween(
        _currentDriverPosition!.latitude,
        _currentDriverPosition!.longitude,
        request.pickupLat,
        request.pickupLng,
      );
      pickupDistanceKm = meters / 1000.0;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: TRYPColors.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'NEW RIDE REQUEST • ${request.rideType.toUpperCase()}',
                      style: TRYPTypography.labelLarge.copyWith(
                        color: TRYPColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'R${request.fare.toStringAsFixed(2)}',
                    style: TRYPTypography.headingLarge.copyWith(
                      color: TRYPColors.secondary,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Passenger Details
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: TRYPColors.primary.withValues(alpha: 0.3),
                    backgroundImage:
                        (request.passengerAvatar != null &&
                            request.passengerAvatar!.isNotEmpty)
                        ? NetworkImage(request.passengerAvatar!)
                        : null,
                    child:
                        (request.passengerAvatar == null ||
                            request.passengerAvatar!.isEmpty)
                        ? const Icon(
                            Icons.person_rounded,
                            color: TRYPColors.secondary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.passengerName ?? 'Verified Passenger',
                        style: TRYPTypography.headingSmall.copyWith(
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        request.passengerPhone != null &&
                                request.passengerPhone!.isNotEmpty
                            ? request.passengerPhone!
                            : 'Payment: ${request.paymentMethod}',
                        style: TRYPTypography.bodySmall.copyWith(
                          color: TRYPColors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 24),

              // Pickup location
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location, color: Colors.green),
                title: Text(
                  request.origin,
                  style: TRYPTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  pickupDistanceKm != null
                      ? '${pickupDistanceKm.toStringAsFixed(1)} km away from your location'
                      : 'Pickup Location',
                  style: TRYPTypography.bodySmall.copyWith(
                    color: TRYPColors.grey,
                  ),
                ),
              ),

              // Destination location
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.location_on,
                  color: TRYPColors.secondary,
                ),
                title: Text(
                  request.destination,
                  style: TRYPTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Trip distance: ${request.distanceKm.toStringAsFixed(1)} km',
                  style: TRYPTypography.bodySmall.copyWith(
                    color: TRYPColors.grey,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _declineRideRequest(request, modalContext),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(modalContext);
                        _acceptRideRequest(request);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TRYPColors.primary,
                        foregroundColor: TRYPColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Accept Ride',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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

  Future<void> _declineRideRequest(
    TripModel request,
    BuildContext modalContext,
  ) async {
    Navigator.pop(modalContext);
    final tripService = ref.read(tripServiceProvider);
    final declined = await tripService.declineRide(request.id);
    if (!mounted) return;

    if (declined) {
      setState(() {
        _openRequests.removeWhere((ride) => ride.id == request.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride declined and removed from your requests.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not decline this ride. Please try again.'),
          backgroundColor: TRYPColors.error,
        ),
      );
    }
  }

  Future<void> _acceptRideRequest(TripModel request) async {
    setState(() => _isLoading = true);
    try {
      final tripService = ref.read(tripServiceProvider);
      final acceptedTrip = await tripService.acceptRide(request.id);

      if (!mounted) return;

      if (acceptedTrip != null) {
        ref.read(activeTripStateProvider.notifier).stateTrip = acceptedTrip;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride Accepted! En route to pickup passenger.'),
            backgroundColor: Colors.green,
          ),
        );
        context.go(Routes.activeTrip);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride request is no longer available.'),
            backgroundColor: TRYPColors.error,
          ),
        );
        _fetchOpenRequests();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error accepting ride: $e'),
          backgroundColor: TRYPColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.orange,
                  size: 40,
                ),
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
                style: TRYPTypography.bodyMedium.copyWith(
                  color: TRYPColors.grey,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: TRYPColors.lightGrey,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.hourglass_empty_rounded,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Current Status: ${_driverStatus.toUpperCase().replaceAll('_', ' ')}',
                      style: TRYPTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              PrimaryButton(
                label: 'Complete Verification Onboarding',
                onPressed: () {
                  Navigator.pop(context);
                  context.go(Routes.driverOnboarding);
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go(Routes.driverDocuments);
                  },
                  child: const Text('View Uploaded Documents'),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  final newStatus = _driverStatus == 'approved'
                      ? 'under_review'
                      : 'approved';
                  final client = ref.read(supabaseClientProvider);
                  final user = client.auth.currentUser;
                  if (user != null) {
                    await client
                        .from('profiles')
                        .update({'driver_status': newStatus})
                        .eq('id', user.id);
                  }
                  setState(() => _driverStatus = newStatus);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Driver status updated to: ${newStatus.toUpperCase()}',
                      ),
                    ),
                  );
                },
                child: Text(
                  _driverStatus == 'approved'
                      ? 'Set Status to Under Review'
                      : 'Approve Driver Account (Test Mode)',
                  style: const TextStyle(color: TRYPColors.grey, fontSize: 12),
                ),
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
      backgroundColor: TRYPColors.surface,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: TRYPColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'TRYP DRIVER',
                style: TextStyle(
                  color: TRYPColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isVerified
                  ? Icons.verified_user_rounded
                  : Icons.pending_actions_rounded,
              color: isVerified ? Colors.green : Colors.orange,
            ),
            onPressed: () => context.go(Routes.driverDocuments),
            tooltip: 'Verification Documents',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TRYPColors.secondary),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Trip Banner if Driver has a ride in progress
                    if (_currentActiveTrip != null)
                      GestureDetector(
                        onTap: () => context.go(Routes.activeTrip),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: TRYPColors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: TRYPColors.secondary.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.directions_car_rounded,
                                color: TRYPColors.primary,
                                size: 28,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'ACTIVE TRIP IN PROGRESS',
                                      style: TRYPTypography.labelLarge.copyWith(
                                        color: TRYPColors.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    Text(
                                      '${_currentActiveTrip!.origin} ➔ ${_currentActiveTrip!.destination}',
                                      style: TRYPTypography.bodySmall.copyWith(
                                        color: TRYPColors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: TRYPColors.grey,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Verification Banner
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
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 24,
                              ),
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
                                      'Upload & verify PrDP documents to start accepting real rides.',
                                      style: TRYPTypography.bodySmall.copyWith(
                                        color: TRYPColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                      ),

                    Row(
                      children: [
                        Text(
                          'Welcome, $_driverName',
                          style: TRYPTypography.headingLarge.copyWith(
                            color: TRYPColors.secondary,
                          ),
                        ),
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
                      _vehicleInfo,
                      style: TRYPTypography.bodyMedium.copyWith(
                        color: TRYPColors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Status & Earnings Card
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: TRYPColors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isOnline
                              ? TRYPColors.success
                              : TRYPColors.divider,
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
                                      color: _isOnline
                                          ? Colors.green
                                          : (isVerified
                                                ? Colors.red
                                                : Colors.orange),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isOnline
                                        ? 'ONLINE & RECEIVING REQUESTS'
                                        : (isVerified
                                              ? 'YOU ARE OFFLINE'
                                              : 'UNVERIFIED'),
                                    style: TRYPTypography.labelLarge.copyWith(
                                      color: _isOnline
                                          ? Colors.green
                                          : (isVerified
                                                ? Colors.red
                                                : Colors.orange),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '$_driverRating ★',
                                style: TRYPTypography.bodyMedium.copyWith(
                                  color: TRYPColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Today’s Earnings',
                            style: TRYPTypography.bodySmall.copyWith(
                              color: TRYPColors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'R${_todayEarnings.toStringAsFixed(2)}',
                            style: TRYPTypography.headingLarge.copyWith(
                              color: TRYPColors.secondary,
                              fontSize: 32,
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: !isVerified
                                    ? TRYPColors.lightGrey
                                    : (_isOnline
                                          ? TRYPColors.error
                                          : TRYPColors.primary),
                                foregroundColor: !isVerified
                                    ? TRYPColors.grey
                                    : TRYPColors.white,
                                minimumSize: const Size.fromHeight(54),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: _toggleOnline,
                              icon: Icon(
                                !isVerified
                                    ? Icons.lock_outline_rounded
                                    : (_isOnline
                                          ? Icons.power_settings_new
                                          : Icons.play_arrow_rounded),
                              ),
                              label: Text(
                                !isVerified
                                    ? 'VERIFICATION REQUIRED TO GO ONLINE'
                                    : (_isOnline
                                          ? 'GO OFFLINE'
                                          : 'GO ONLINE TO ACCEPT RIDES'),
                                style: TRYPTypography.labelLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Open Ride Requests Section
                    if (_isOnline) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Live Ride Requests',
                            style: TRYPTypography.headingSmall.copyWith(
                              color: TRYPColors.secondary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _openRequests.isNotEmpty
                                  ? TRYPColors.accentSoft
                                  : TRYPColors.lightGrey,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_openRequests.length} Available',
                              style: TextStyle(
                                color: _openRequests.isNotEmpty
                                    ? TRYPColors.secondary
                                    : TRYPColors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: _openRequests.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(
                                      color: TRYPColors.secondary,
                                      strokeWidth: 2,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Searching for nearby passengers...',
                                      style: TRYPTypography.bodyMedium.copyWith(
                                        color: TRYPColors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Make sure location permissions are granted',
                                      style: TRYPTypography.bodySmall.copyWith(
                                        color: TRYPColors.grey.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _openRequests.length,
                                itemBuilder: (context, index) {
                                  final request = _openRequests[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    color: TRYPColors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                      side: const BorderSide(
                                        color: TRYPColors.divider,
                                      ),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      title: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            request.passengerName ??
                                                'Verified Passenger',
                                            style: TRYPTypography.titleMedium
                                                .copyWith(
                                                  color: TRYPColors.secondary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            'R${request.fare.toStringAsFixed(2)}',
                                            style: TRYPTypography.headingSmall
                                                .copyWith(
                                                  color: TRYPColors.secondary,
                                                ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.my_location,
                                                size: 14,
                                                color: Colors.green,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  request.origin,
                                                  style: TRYPTypography
                                                      .bodySmall
                                                      .copyWith(
                                                        color: TRYPColors
                                                            .secondary,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: TRYPColors.secondary,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  request.destination,
                                                  style: TRYPTypography
                                                      .bodySmall
                                                      .copyWith(
                                                        color: TRYPColors
                                                            .secondary,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      trailing: ElevatedButton(
                                        onPressed: () =>
                                            _showRealRideRequestSheet(request),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: TRYPColors.primary,
                                          foregroundColor: TRYPColors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'View Details',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ] else ...[
                      const Spacer(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
