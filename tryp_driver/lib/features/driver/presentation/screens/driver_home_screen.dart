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
import 'package:tryp_driver/core/widgets/driver_bottom_nav_bar.dart';

class DriverHomeScreenPage extends ConsumerStatefulWidget {
  const DriverHomeScreenPage({Key? key}) : super(key: key);

  @override
  ConsumerState<DriverHomeScreenPage> createState() =>
      _DriverHomeScreenPageState();
}

class _DriverHomeScreenPageState extends ConsumerState<DriverHomeScreenPage>
    with WidgetsBindingObserver {
  bool _isOnline = false;
  String _driverName = 'Driver';
  String _driverStatus = 'under_review';
  final double _driverRating = 4.9;
  bool _isLoading = false;

  Timer? _locationTimer;
  Timer? _requestsPollTimer;
  RealtimeChannel? _pendingRidesChannel;
  bool _locationUpdateInFlight = false;
  bool _requestsFetchInFlight = false;
  bool _requestSheetVisible = false;
  Timer? _requestSheetExpiryTimer;

  List<TripModel> _openRequests = [];
  TripModel? _currentActiveTrip;
  Position? _currentDriverPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDriverVerificationStatus();
    _checkForActiveTrip();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Timers and realtime sockets may be suspended by the operating system.
      // Reconcile the server state and recreate the listeners on resume.
      unawaited(_checkDriverVerificationStatus());
      unawaited(_checkForActiveTrip());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _requestsPollTimer?.cancel();
    _requestSheetExpiryTimer?.cancel();
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
          });

          if (_isOnline) {
            _startOnlineTrackingAndListening();
          } else {
            _stopOnlineTrackingAndListening();
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
    _pendingRidesChannel?.unsubscribe();
    _pendingRidesChannel = null;

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
    _requestSheetExpiryTimer?.cancel();
    _pendingRidesChannel?.unsubscribe();
    _pendingRidesChannel = null;
    setState(() {
      _openRequests = [];
    });
  }

  Future<void> _updateAndBroadcastLocation() async {
    if (!_isOnline || _locationUpdateInFlight) return;
    _locationUpdateInFlight = true;
    try {
      final locService = ref.read(locationServiceProvider);
      final pos = await locService.getCurrentPosition();
      if (pos != null) {
        _currentDriverPosition = pos;
        if (mounted && _openRequests.isNotEmpty) {
          setState(() => _openRequests = _sortOpenRequests(_openRequests));
        }
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
    } finally {
      _locationUpdateInFlight = false;
    }
  }

  Future<void> _fetchOpenRequests() async {
    if (!_isOnline ||
        _driverStatus != 'approved' ||
        _requestsFetchInFlight) {
      return;
    }
    _requestsFetchInFlight = true;

    try {
      final tripService = ref.read(tripServiceProvider);
      final requests = await tripService.getOpenRideRequests();
      if (!mounted) return;

      final previousCount = _openRequests.length;
      final sortedRequests = _sortOpenRequests(requests);
      setState(() {
        _openRequests = sortedRequests;
      });

      // If new request came in, show the closest request first.
      if (sortedRequests.isNotEmpty &&
          sortedRequests.length > previousCount &&
          ModalRoute.of(context)?.isCurrent == true) {
        _showRealRideRequestSheet(sortedRequests.first);
      }
    } catch (e) {
      debugPrint('Error fetching open requests: $e');
    } finally {
      _requestsFetchInFlight = false;
    }
  }

  List<TripModel> _sortOpenRequests(List<TripModel> requests) {
    final sorted = [...requests];
    sorted.sort((a, b) {
      final aDistance = _distanceToPickupKm(a);
      final bDistance = _distanceToPickupKm(b);
      if (aDistance == null && bDistance == null) {
        return b.requestedAt.compareTo(a.requestedAt);
      }
      if (aDistance == null) return 1;
      if (bDistance == null) return -1;
      final distanceOrder = aDistance.compareTo(bDistance);
      return distanceOrder == 0
          ? b.requestedAt.compareTo(a.requestedAt)
          : distanceOrder;
    });
    return sorted;
  }

  double? _distanceToPickupKm(TripModel request) {
    final position = _currentDriverPosition;
    if (position == null) return null;
    return Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          request.pickupLat,
          request.pickupLng,
        ) /
        1000;
  }

  String _requestDistanceLabel(TripModel request) {
    final distanceKm = _distanceToPickupKm(request);
    return distanceKm == null
        ? 'Pickup distance updating'
        : '${distanceKm.toStringAsFixed(1)} km to pickup';
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
  }

  void _showRealRideRequestSheet(TripModel request) {
    if (_requestSheetVisible) return;
    _requestSheetVisible = true;
    _requestSheetExpiryTimer?.cancel();
    _requestSheetExpiryTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted || !_requestSheetVisible) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This ride offer has expired.')),
        );
      }
    });

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

              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: TRYPColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.groups_rounded,
                      size: 18,
                      color: TRYPColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${request.totalPassengers} passenger${request.totalPassengers == 1 ? '' : 's'} expected',
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (request.additionalPassengers > 0)
                      Text(
                        ' (${request.additionalPassengers} companion${request.additionalPassengers == 1 ? '' : 's'})',
                        style: TRYPTypography.bodySmall.copyWith(
                          color: TRYPColors.grey,
                        ),
                      ),
                  ],
                ),
              ),

              if (request.scheduledFor != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: TRYPColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: TRYPColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scheduled pickup: ${_formatTripDate(request.scheduledFor!)}',
                          style: TRYPTypography.bodySmall.copyWith(
                            color: TRYPColors.secondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              const Divider(height: 24),

              // Pickup location
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.my_location,
                  color: TRYPColors.primary,
                ),
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
    ).whenComplete(() {
      _requestSheetExpiryTimer?.cancel();
      _requestSheetExpiryTimer = null;
      _requestSheetVisible = false;
    });
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
    }
  }

  String _formatTripDate(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} at $hour:$minute $period';
  }

  Future<void> _acceptRideRequest(TripModel request) async {
    setState(() => _isLoading = true);
    try {
      final tripService = ref.read(tripServiceProvider);
      final acceptedTrip = await tripService.acceptRide(request.id);

      if (!mounted) return;

      if (acceptedTrip != null) {
        ref.read(activeTripStateProvider.notifier).stateTrip = acceptedTrip;
        context.go(Routes.activeTrip);
      } else {
        _fetchOpenRequests();
      }
    } catch (e) {
      debugPrint('Error accepting ride: $e');
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
                  color: TRYPColors.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: TRYPColors.primary,
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
                      color: TRYPColors.primary,
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
            Image.asset(
              'assets/images/tryp-logo-green.png',
              width: 42,
              height: 30,
              fit: BoxFit.contain,
              semanticLabel: 'TRYP Driver logo',
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                _driverName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TRYPTypography.titleLarge.copyWith(
                  color: TRYPColors.secondary,
                  fontWeight: FontWeight.w800,
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
              color: isVerified ? TRYPColors.primary : TRYPColors.secondary,
            ),
            onPressed: () => context.go(Routes.driverAccount),
            tooltip: 'Account',
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
                            color: TRYPColors.accentSoft,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: TRYPColors.primary),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: TRYPColors.primary,
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
                                        color: TRYPColors.primary,
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
                                color: TRYPColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Compact availability controls: no status card/container.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isOnline ? 'You are online' : 'You are offline',
                              style: TRYPTypography.headingSmall.copyWith(
                                color: TRYPColors.secondary,
                                fontSize: 19,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _isOnline
                                  ? 'Nearby requests are ready for you.'
                                  : 'Go online when you are ready to drive.',
                              style: TRYPTypography.bodySmall.copyWith(
                                color: TRYPColors.grey,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$_driverRating ★',
                          style: TRYPTypography.bodyMedium.copyWith(
                            color: TRYPColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isOnline
                              ? TRYPColors.primary
                              : TRYPColors.secondary,
                          foregroundColor: _isOnline
                              ? TRYPColors.secondary
                              : TRYPColors.white,
                          elevation: 0,
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
                              ? 'COMPLETE VERIFICATION TO GO ONLINE'
                              : (_isOnline ? 'GO OFFLINE' : 'GO ONLINE'),
                          style: TextStyle(
                            color: _isOnline
                                ? TRYPColors.secondary
                                : TRYPColors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Open Ride Requests Section
                    if (_isOnline) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_rounded,
                            size: 16,
                            color: TRYPColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Closest pickup first • live distance',
                            style: TRYPTypography.bodySmall.copyWith(
                              color: TRYPColors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                                      contentPadding: const EdgeInsets.all(12),
                                      leading: CircleAvatar(
                                        radius: 17,
                                        backgroundColor: TRYPColors.secondary,
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            color: TRYPColors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      title: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              request.passengerName ??
                                                  'Verified Passenger',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TRYPTypography.titleMedium
                                                  .copyWith(
                                                    color: TRYPColors.secondary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
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
                                          const SizedBox(height: 4),
                                          Text(
                                            _requestDistanceLabel(request),
                                            style: TRYPTypography.bodySmall
                                                .copyWith(
                                                  color: TRYPColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.my_location,
                                                size: 14,
                                                color: TRYPColors.primary,
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
                                                  '${request.destination}${request.scheduledFor == null ? '' : ' • ${_formatTripDate(request.scheduledFor!)}'}',
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
      bottomNavigationBar: const DriverBottomNavBar(currentIndex: 0),
    );
  }
}
