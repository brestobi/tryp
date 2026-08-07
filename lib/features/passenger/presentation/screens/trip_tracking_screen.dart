import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/location_service.dart';
import 'package:tryp/core/services/trip_service.dart';

class TripTrackingScreenPage extends ConsumerStatefulWidget {
  const TripTrackingScreenPage({Key? key}) : super(key: key);

  @override
  ConsumerState<TripTrackingScreenPage> createState() =>
      _TripTrackingScreenPageState();
}

class _TripTrackingScreenPageState extends ConsumerState<TripTrackingScreenPage>
    with WidgetsBindingObserver {
  TripModel? _currentTrip;
  RealtimeChannel? _rideSubscription;
  RealtimeChannel? _driverLocationSubscription;
  Timer? _statusRefreshTimer;
  bool _isLoading = true;
  bool _completionPromptShown = false;
  bool _statusRefreshInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadAndSubscribeToActiveRide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshCurrentTrip());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusRefreshTimer?.cancel();
    _rideSubscription?.unsubscribe();
    _driverLocationSubscription?.unsubscribe();
    super.dispose();
  }

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Future<void> _loadAndSubscribeToActiveRide() async {
    setState(() => _isLoading = true);
    final tripService = ref.read(tripServiceProvider);

    var trip = ref.read(activeTripStateProvider);
    if (trip == null) {
      trip = await tripService.getPassengerActiveTrip();
      if (trip != null) {
        ref.read(activeTripStateProvider.notifier).stateTrip = trip;
      }
    }

    if (!mounted) return;

    if (trip == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _currentTrip = trip;
      _isLoading = false;
    });

    if (trip.status == TripStatus.completed) {
      _openCompletionScreen(trip);
      return;
    }

    _subscribeToRideUpdates(trip.id);
    _subscribeToDriverLocation(trip);
    _updateMapMarkersAndRoute(trip);
    _startStatusRefreshTimer();
  }

  void _startStatusRefreshTimer() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refreshCurrentTrip()),
    );
  }

  /// Realtime updates are best-effort and can be missed while the app is
  /// backgrounded or the connection is briefly interrupted. Fetching by ID
  /// avoids the active-trip query's terminal-status filter and guarantees that
  /// a driver completion can still reach the passenger UI.
  Future<void> _refreshCurrentTrip() async {
    final currentTrip = _currentTrip;
    if (!mounted || currentTrip == null || _statusRefreshInFlight) return;

    _statusRefreshInFlight = true;
    try {
      final trip = await ref
          .read(tripServiceProvider)
          .getTripById(currentTrip.id);
      if (!mounted || trip == null || _currentTrip?.id != currentTrip.id) {
        return;
      }

      if (trip.status == TripStatus.completed) {
        _openCompletionScreen(trip);
        return;
      }

      if (trip.status == TripStatus.cancelled) {
        _finishCancelledRide();
        return;
      }

      final driverChanged = _currentTrip?.driverId != trip.driverId;
      setState(() => _currentTrip = trip);
      ref.read(activeTripStateProvider.notifier).stateTrip = trip;
      if (driverChanged) _subscribeToDriverLocation(trip);
      _updateMapMarkersAndRoute(trip);
    } finally {
      _statusRefreshInFlight = false;
    }
  }

  void _subscribeToDriverLocation(TripModel trip) {
    _driverLocationSubscription?.unsubscribe();
    final driverId = trip.driverId;
    if (driverId == null) return;

    final tripService = ref.read(tripServiceProvider);
    _driverLocationSubscription = tripService.subscribeToDriverLocation(
      driverId: driverId,
      onUpdate: (profile) {
        if (!mounted) return;
        final lat = (profile['current_lat'] as num?)?.toDouble();
        final lng = (profile['current_lng'] as num?)?.toDouble();
        if (lat == null || lng == null || _currentTrip == null) return;

        final updatedTrip = _currentTrip!.copyWith(
          driverLat: lat,
          driverLng: lng,
        );
        setState(() => _currentTrip = updatedTrip);
        ref.read(activeTripStateProvider.notifier).stateTrip = updatedTrip;
        _updateMapMarkersAndRoute(updatedTrip);
      },
    );
  }

  void _subscribeToRideUpdates(String rideId) {
    _rideSubscription?.unsubscribe();
    final tripService = ref.read(tripServiceProvider);

    _rideSubscription = tripService.subscribeToRide(
      rideId: rideId,
      onUpdate: (_) {
        unawaited(_refreshCurrentTrip());
      },
    );
  }

  void _finishCancelledRide() {
    if (!mounted) return;
    _currentTrip = null;
    _statusRefreshTimer?.cancel();
    _rideSubscription?.unsubscribe();
    _driverLocationSubscription?.unsubscribe();
    _rideSubscription = null;
    _driverLocationSubscription = null;
    ref.read(activeTripStateProvider.notifier).stateTrip = null;
    context.go(Routes.passengerHome);
  }

  Future<void> _updateMapMarkersAndRoute(TripModel trip) async {
    final markers = <Marker>{};

    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(trip.pickupLat, trip.pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup Location', snippet: trip.origin),
      ),
    );

    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(trip.destLat, trip.destLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination', snippet: trip.destination),
      ),
    );

    if (trip.driverLat != null && trip.driverLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('driver_live'),
          position: LatLng(trip.driverLat!, trip.driverLng!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
          infoWindow: InfoWindow(
            title: trip.driverName ?? 'Driver',
            snippet: trip.vehicleDescription,
          ),
        ),
      );
    }

    setState(() {
      _markers = markers;
    });

    try {
      final locService = ref.read(locationServiceProvider);
      final route = await locService.getRealRoute(
        startLat: trip.pickupLat,
        startLng: trip.pickupLng,
        endLat: trip.destLat,
        endLng: trip.destLng,
      );

      if (!mounted) return;

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('active_trip_route'),
            points: route.polylinePoints,
            color: TRYPColors.primary,
            width: 5,
          ),
        };
      });

      if (_mapController != null) {
        final bounds = LatLngBounds(
          southwest: LatLng(
            trip.pickupLat < trip.destLat ? trip.pickupLat : trip.destLat,
            trip.pickupLng < trip.destLng ? trip.pickupLng : trip.destLng,
          ),
          northeast: LatLng(
            trip.pickupLat > trip.destLat ? trip.pickupLat : trip.destLat,
            trip.pickupLng > trip.destLng ? trip.pickupLng : trip.destLng,
          ),
        );
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      }
    } catch (_) {}
  }

  Future<void> _cancelRide() async {
    if (_currentTrip == null) return;
    try {
      final tripService = ref.read(tripServiceProvider);
      final updated = await tripService.updateTripStatus(
        rideId: _currentTrip!.id,
        status: TripStatus.cancelled,
      );
      if (updated == null)
        throw StateError('Cancellation was rejected by the server.');
      ref.read(activeTripStateProvider.notifier).stateTrip = null;
      if (!mounted) return;
      context.go(Routes.passengerHome);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel ride: $e'),
          backgroundColor: TRYPColors.error,
        ),
      );
    }
  }

  void _openCompletionScreen(TripModel trip) {
    if (_completionPromptShown || !mounted) return;
    _completionPromptShown = true;
    _statusRefreshTimer?.cancel();
    ref.read(activeTripStateProvider.notifier).stateTrip = null;
    _rideSubscription?.unsubscribe();
    _driverLocationSubscription?.unsubscribe();
    _rideSubscription = null;
    _driverLocationSubscription = null;
    context.go(Routes.rideCompletion, extra: trip);
  }

  void _showSosDialog() {
    String incidentType = 'emergency';
    final messageController = TextEditingController();
    var isSubmitting = false;
    const types = <String, String>{
      'emergency': 'Emergency',
      'unsafe_driving': 'Unsafe driving',
      'medical': 'Medical help',
      'harassment': 'Harassment',
      'other': 'Other',
    };

    unawaited(
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('TRYP Safety Center'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Describe what is happening so our safety team can respond.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: incidentType,
                  items: types.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null)
                      setDialogState(() => incidentType = value);
                  },
                  decoration: const InputDecoration(labelText: 'Incident type'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message (optional)',
                    hintText: 'Add useful details',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final trip = _currentTrip;
                        setDialogState(() => isSubmitting = true);
                        final saved = await ref
                            .read(tripServiceProvider)
                            .createSafetyIncident(
                              rideId: trip?.id,
                              incidentType: incidentType,
                              message: messageController.text,
                            );
                        if (!mounted) return;
                        if (!saved) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not contact the safety center.',
                              ),
                              backgroundColor: TRYPColors.error,
                            ),
                          );
                          return;
                        }
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Safety team alerted. Stay on the line and follow local emergency procedures.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                child: const Text('Alert Safety Team'),
              ),
            ],
          ),
        ),
      ).then((_) => messageController.dispose()),
    );
  }

  void _makeCall(String phone) {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver phone number not available')),
      );
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Calling driver: $phone')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: TRYPColors.primary,
        body: Center(child: CircularProgressIndicator(color: TRYPColors.white)),
      );
    }

    if (_currentTrip == null) {
      return Scaffold(
        backgroundColor: TRYPColors.primary,
        appBar: AppBar(
          backgroundColor: TRYPColors.primary,
          foregroundColor: TRYPColors.white,
          title: const Text('Trip Tracking'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.directions_car_rounded,
                size: 48,
                color: TRYPColors.accent,
              ),
              const SizedBox(height: 12),
              Text(
                'No active trip to track',
                style: TRYPTypography.headingSmall.copyWith(
                  color: TRYPColors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(Routes.passengerHome),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TRYPColors.accent,
                  foregroundColor: TRYPColors.primary,
                ),
                child: const Text('Go to Passenger Home'),
              ),
            ],
          ),
        ),
      );
    }

    final trip = _currentTrip!;
    final status = trip.status;

    String headerTitle = 'Ride Tracking';
    String statusSubtitle = 'Connecting to real-time driver dispatch...';

    switch (status) {
      case TripStatus.requested:
        headerTitle = 'Searching for Nearby Drivers';
        statusSubtitle =
            'We are notifying active, verified drivers near your pickup.';
        break;
      case TripStatus.accepted:
        headerTitle = 'Driver En Route';
        statusSubtitle =
            '${trip.driverName ?? "Your driver"} is heading to pickup location.';
        break;
      case TripStatus.arrived:
        headerTitle = 'Driver Has Arrived!';
        statusSubtitle =
            'Your driver is waiting outside. Share PIN code to start.';
        break;
      case TripStatus.inTrip:
        headerTitle = 'On Trip to Destination';
        statusSubtitle = 'Heading towards ${trip.destination}.';
        break;
      case TripStatus.completed:
        headerTitle = 'Trip Completed';
        statusSubtitle = 'You have arrived at your destination.';
        break;
      case TripStatus.cancelled:
        headerTitle = 'Ride Cancelled';
        statusSubtitle = 'This ride request was cancelled.';
        break;
    }

    return Scaffold(
      backgroundColor: TRYPColors.primary,
      appBar: AppBar(
        backgroundColor: TRYPColors.primary,
        foregroundColor: TRYPColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TRYPColors.white),
          onPressed: () => context.go(Routes.passengerHome),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headerTitle,
              style: TRYPTypography.headingSmall.copyWith(
                fontSize: 16,
                color: TRYPColors.white,
              ),
            ),
            Text(
              statusSubtitle,
              style: TRYPTypography.bodySmall.copyWith(
                color: TRYPColors.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sos_rounded, color: Colors.red),
            onPressed: _showSosDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Real-Time Google Map
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(trip.pickupLat, trip.pickupLng),
                  zoom: 14,
                ),
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                onMapCreated: (controller) {
                  _mapController = controller;
                  _updateMapMarkersAndRoute(trip);
                },
              ),
            ),

            // Bottom Trip Info & Driver Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: TRYPColors.dark,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == TripStatus.requested) ...[
                    const CircularProgressIndicator(color: TRYPColors.primary),
                    const SizedBox(height: 14),
                    Text(
                      'Waiting for a driver to accept...',
                      style: TRYPTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: TRYPColors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drivers in your area have received your request',
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: _cancelRide,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TRYPColors.accent,
                        side: const BorderSide(
                          color: TRYPColors.accent,
                          width: 1.4,
                        ),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancel Ride Request'),
                    ),
                  ] else if (status == TripStatus.inTrip) ...[
                    Text(
                      'Your driver will complete the trip when you arrive. You can rate the driver once the trip is finished.',
                      style: TRYPTypography.bodyMedium.copyWith(
                        color: TRYPColors.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (status == TripStatus.completed) ...[
                    Text(
                      'Trip completed. Thank you for riding with TRYP!',
                      style: TRYPTypography.bodyMedium.copyWith(
                        color: TRYPColors.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    // Assigned Driver Card
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: TRYPColors.accent,
                          backgroundImage:
                              (trip.driverAvatar != null &&
                                  trip.driverAvatar!.isNotEmpty)
                              ? NetworkImage(trip.driverAvatar!)
                              : null,
                          child:
                              (trip.driverAvatar == null ||
                                  trip.driverAvatar!.isEmpty)
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: TRYPColors.white,
                                  size: 28,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.driverName ?? 'Assigned TRYP Driver',
                                style: TRYPTypography.headingSmall.copyWith(
                                  fontSize: 17,
                                  color: TRYPColors.white,
                                ),
                              ),
                              Text(
                                trip.vehicleDescription,
                                style: TRYPTypography.bodySmall.copyWith(
                                  color: TRYPColors.muted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _makeCall(trip.driverPhone ?? ''),
                          icon: const Icon(
                            Icons.phone_rounded,
                            color: TRYPColors.accent,
                            size: 28,
                          ),
                          tooltip: 'Call Driver',
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Safety PIN Code Display
                    if (trip.pinCode.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: TRYPColors.accentSoft,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: TRYPColors.accent),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YOUR SAFETY PIN',
                                  style: TRYPTypography.labelSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: TRYPColors.primary,
                                  ),
                                ),
                                Text(
                                  'Give this 4-digit PIN to your driver to start ride',
                                  style: TRYPTypography.bodySmall.copyWith(
                                    color: TRYPColors.primary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: TRYPColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                trip.pinCode,
                                style: TRYPTypography.headingMedium.copyWith(
                                  color: TRYPColors.white,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Fare (${trip.paymentMethod}):',
                          style: TRYPTypography.bodySmall.copyWith(
                            color: TRYPColors.muted,
                          ),
                        ),
                        Text(
                          'R${trip.fare.toStringAsFixed(2)}',
                          style: TRYPTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: TRYPColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
