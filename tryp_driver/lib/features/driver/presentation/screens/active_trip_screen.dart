import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/constants/map_styles.dart';
import 'package:tryp_driver/core/services/location_service.dart';
import 'package:tryp_driver/core/services/trip_service.dart';
import 'package:tryp_driver/core/widgets/common_widgets.dart';
import 'package:tryp_driver/core/widgets/ride_chat_sheet.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  TripModel? _activeTrip;
  RealtimeChannel? _rideSubscription;

  MapboxMap? _mapController;
  CircleAnnotationManager? _circleAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  Timer? _gpsUpdateTimer;
  Timer? _statusRefreshTimer;
  DateTime? _lastPickupRouteAt;
  geo.Position? _driverPosition;
  double? _pickupDistanceKm;
  int? _pickupEtaMins;
  bool _completionDialogShown = false;
  bool _statusRefreshInFlight = false;
  bool _gpsUpdateInFlight = false;
  bool _pickupRouteInFlight = false;

  final TextEditingController _pinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadActiveTrip();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final trip = _activeTrip;
      if (trip != null) {
        // Recreate the ride channel and GPS loop after the OS resumes the app.
        _subscribeToRideUpdates(trip.id);
        _startGpsUpdates();
        unawaited(_refreshPickupRouteIfNeeded(force: true));
        unawaited(_refreshActiveTrip());
      } else {
        unawaited(_loadActiveTrip());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rideSubscription?.unsubscribe();
    _gpsUpdateTimer?.cancel();
    _statusRefreshTimer?.cancel();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveTrip() async {
    setState(() => _isLoading = true);
    final tripService = ref.read(tripServiceProvider);

    // Try state provider first
    var trip = ref.read(activeTripStateProvider);
    if (trip == null) {
      trip = await tripService.getDriverActiveTrip();
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
      _activeTrip = trip;
      _isLoading = false;
    });

    _subscribeToRideUpdates(trip.id);
    _startStatusRefreshTimer();
    _buildMapMarkersAndRoute(trip);
    _startGpsUpdates();
  }

  void _startStatusRefreshTimer() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refreshActiveTrip()),
    );
  }

  Future<void> _refreshActiveTrip() async {
    final activeTrip = _activeTrip;
    if (!mounted || activeTrip == null || _statusRefreshInFlight) return;

    _statusRefreshInFlight = true;
    try {
      final updatedTrip = await ref
          .read(tripServiceProvider)
          .getTripById(activeTrip.id);
      if (!mounted || updatedTrip == null || _activeTrip?.id != activeTrip.id) {
        return;
      }

      if (updatedTrip.status == TripStatus.cancelled) {
        _finishCancelledTrip();
        return;
      }

      if (updatedTrip.status == TripStatus.completed) {
        _statusRefreshTimer?.cancel();
        _gpsUpdateTimer?.cancel();
        setState(() => _activeTrip = updatedTrip);
        ref.read(activeTripStateProvider.notifier).stateTrip = updatedTrip;
        _showCompletionDialog(updatedTrip);
        return;
      }

      setState(() => _activeTrip = updatedTrip);
      ref.read(activeTripStateProvider.notifier).stateTrip = updatedTrip;
    } finally {
      _statusRefreshInFlight = false;
    }
  }

  void _finishCancelledTrip() {
    _statusRefreshTimer?.cancel();
    _gpsUpdateTimer?.cancel();
    _rideSubscription?.unsubscribe();
    _rideSubscription = null;
    _activeTrip = null;
    ref.read(activeTripStateProvider.notifier).stateTrip = null;
    if (mounted) context.go(Routes.driverHome);
  }

  void _subscribeToRideUpdates(String rideId) {
    _rideSubscription?.unsubscribe();
    final tripService = ref.read(tripServiceProvider);
    _rideSubscription = tripService.subscribeToRide(
      rideId: rideId,
      onUpdate: (_) => unawaited(_refreshActiveTrip()),
    );
  }

  void _startGpsUpdates() {
    _gpsUpdateTimer?.cancel();
    _gpsUpdateTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_activeTrip == null || _gpsUpdateInFlight) return;
      _gpsUpdateInFlight = true;
      try {
        final locService = ref.read(locationServiceProvider);
        final pos = await locService.getCurrentPosition();
        if (pos != null && mounted) {
          _driverPosition = pos;
          unawaited(_refreshPickupRouteIfNeeded());
          final tripService = ref.read(tripServiceProvider);
          await tripService.updateDriverLocation(
            lat: pos.latitude,
            lng: pos.longitude,
            heading: pos.heading,
            isOnline: true,
          );
        }
      } catch (_) {
        // The next heartbeat retries; the server-side presence job will
        // remove this driver from dispatch if the failures continue.
      } finally {
        _gpsUpdateInFlight = false;
      }
    });
  }

  Future<void> _refreshPickupRouteIfNeeded({bool force = false}) async {
    final trip = _activeTrip;
    final position = _driverPosition;
    if (!mounted ||
        trip == null ||
        trip.status != TripStatus.accepted ||
        position == null ||
        _pickupRouteInFlight) {
      return;
    }

    final lastUpdated = _lastPickupRouteAt;
    if (!force &&
        lastUpdated != null &&
        DateTime.now().difference(lastUpdated) < const Duration(seconds: 15)) {
      return;
    }

    _pickupRouteInFlight = true;
    try {
      final route = await ref.read(locationServiceProvider).getRealRoute(
        startLat: position.latitude,
        startLng: position.longitude,
        endLat: trip.pickupLat,
        endLng: trip.pickupLng,
      );
      if (!mounted || _activeTrip?.id != trip.id) return;

      _lastPickupRouteAt = DateTime.now();
      setState(() {
        _pickupDistanceKm = route.distanceKm;
        _pickupEtaMins = route.durationMins;
      });
      await _drawRoute(route);
      _mapController?.easeTo(
        CameraOptions(
          center: _mapPoint(
            (position.latitude + trip.pickupLat) / 2,
            (position.longitude + trip.pickupLng) / 2,
          ),
          zoom: 13,
        ),
        MapAnimationOptions(duration: 600),
      );
    } catch (_) {
      // The next GPS heartbeat retries route guidance.
    } finally {
      _pickupRouteInFlight = false;
    }
  }

  Future<void> _drawRoute(RouteResult route) async {
    if (!mounted || _mapController == null) return;
    _polylineAnnotationManager ??= await _mapController!.annotations
        .createPolylineAnnotationManager();
    await _polylineAnnotationManager!.deleteAll();
    await _polylineAnnotationManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: route.polylinePoints
              .map((point) => Position(point.longitude, point.latitude))
              .toList(),
        ),
        lineColor: TRYPColors.liveTracking.toARGB32(),
        lineWidth: 5,
        lineJoin: LineJoin.ROUND,
      ),
    );
  }

  Point _mapPoint(double latitude, double longitude) =>
      Point(coordinates: Position(longitude, latitude));

  Future<void> _buildMapMarkersAndRoute(TripModel trip) async {
    final map = _mapController;
    if (map == null) return;

    _circleAnnotationManager ??= await map.annotations
        .createCircleAnnotationManager();
    await _circleAnnotationManager!.deleteAll();
    await _circleAnnotationManager!.createMulti([
      CircleAnnotationOptions(
        geometry: _mapPoint(trip.pickupLat, trip.pickupLng),
        circleColor: TRYPColors.primary.toARGB32(),
        circleRadius: 8,
        circleStrokeColor: TRYPColors.white.toARGB32(),
        circleStrokeWidth: 2,
      ),
      CircleAnnotationOptions(
        geometry: _mapPoint(trip.destLat, trip.destLng),
        circleColor: TRYPColors.secondary.toARGB32(),
        circleRadius: 8,
        circleStrokeColor: TRYPColors.white.toARGB32(),
        circleStrokeWidth: 2,
      ),
    ]);

    try {
      final locService = ref.read(locationServiceProvider);
      final route = await locService.getRealRoute(
        startLat: trip.pickupLat,
        startLng: trip.pickupLng,
        endLat: trip.destLat,
        endLng: trip.destLng,
      );

      if (!mounted || _mapController == null) return;

      await _drawRoute(route);
    } catch (_) {}
  }

  Future<void> _updateTripStatus(
    TripStatus nextStatus, {
    bool asDriverCompletion = false,
  }) async {
    if (_activeTrip == null) return;
    setState(() => _isLoading = true);

    try {
      final tripService = ref.read(tripServiceProvider);

      TripModel? updated;

      if (asDriverCompletion) {
        // The assigned driver is the only party authorized to complete the ride.
        updated = await tripService.completeRide(
          rideId: _activeTrip!.id,
          actor: 'driver',
        );
      } else {
        updated = await tripService.updateTripStatus(
          rideId: _activeTrip!.id,
          status: nextStatus,
        );
      }

      if (!mounted) return;

      if (updated == null) {
        throw StateError(
          asDriverCompletion
              ? 'The ride could not be completed. Please try again.'
              : 'The trip status could not be updated. Please try again.',
        );
      }

      setState(() {
        _activeTrip = updated;
      });
      ref.read(activeTripStateProvider.notifier).stateTrip = updated;

      if (updated.status == TripStatus.completed) {
        _statusRefreshTimer?.cancel();
        _gpsUpdateTimer?.cancel();
        _showCompletionDialog(updated);
      }
    } catch (e) {
      debugPrint('Could not update trip status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update the trip. Please try again.'),
            backgroundColor: TRYPColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markArrivedAtPickup() async {
    final trip = _activeTrip;
    if (trip == null) return;

    final position = await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your location is unavailable. Enable GPS and try again.'),
          backgroundColor: TRYPColors.error,
        ),
      );
      return;
    }

    final distanceMeters = geo.Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      trip.pickupLat,
      trip.pickupLng,
    );
    if (distanceMeters > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Move closer to the pickup point before marking arrival (${distanceMeters.round()} m away).',
          ),
          backgroundColor: TRYPColors.secondary,
        ),
      );
      return;
    }

    await _updateTripStatus(TripStatus.arrived);
  }

  void _showPinVerificationDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: TRYPColors.primary),
            const SizedBox(width: 8),
            Text(
              'Passenger Safety PIN',
              style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask passenger for their 4-digit PIN code displayed on their screen to start ride.',
              style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: TRYPTypography.headingLarge.copyWith(
                letterSpacing: 8,
                color: TRYPColors.secondary,
              ),
              decoration: InputDecoration(
                hintText: '••••',
                filled: true,
                fillColor: TRYPColors.inputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TRYPColors.primary,
              foregroundColor: TRYPColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              final inputPin = _pinController.text.trim();
              final expectedPin = _activeTrip?.pinCode ?? '';
              if (expectedPin.isNotEmpty && inputPin != expectedPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('That safety PIN is incorrect. Please try again.'),
                    backgroundColor: TRYPColors.error,
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext);
              _updateTripStatus(TripStatus.inTrip);
            },
            child: const Text(
              'Verify & Start Trip',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showChat() {
    final trip = _activeTrip;
    if (trip == null || trip.driverId == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RideChatSheet(
        tripService: ref.read(tripServiceProvider),
        rideId: trip.id,
        currentUserId: trip.driverId!,
        otherPartyName: trip.passengerName ?? 'the passenger',
      ),
    );
  }

  void _showCompletionDialog(TripModel trip) {
    if (_completionDialogShown) return;
    _completionDialogShown = true;

    int rating = 5;
    final reviewController = TextEditingController();
    var isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: TRYPColors.primary,
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                'Trip Complete!',
                style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${trip.rideReference.isNotEmpty ? trip.rideReference : 'Trip'} · Fare Collected: R${trip.fare.toStringAsFixed(2)}',
                style: TRYPTypography.headingMedium.copyWith(
                  color: TRYPColors.secondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Payment Method: ${trip.paymentMethod}',
                style: TRYPTypography.bodySmall.copyWith(
                  color: TRYPColors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'R${trip.fare.toStringAsFixed(2)} has been credited to your TRYP Driver earnings balance.',
                style: TRYPTypography.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text('Rate your passenger', style: TRYPTypography.titleMedium),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    icon: Icon(
                      starIndex <= rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: TRYPColors.primary,
                    ),
                    onPressed: () => setDialogState(() => rating = starIndex),
                  );
                }),
              ),
              TextField(
                controller: reviewController,
                maxLength: 240,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Review (optional)',
                ),
              ),
            ],
          ),
          actions: [
            PrimaryButton(
              label: 'Submit Rating & Return',
              isLoading: isSubmitting,
              onPressed: () async {
                setDialogState(() => isSubmitting = true);
                final saved = await ref
                    .read(tripServiceProvider)
                    .submitRating(
                      rideId: trip.id,
                      rating: rating,
                      review: reviewController.text,
                    );
                if (!mounted) return;
                if (!saved) {
                  _completionDialogShown = false;
                  setDialogState(() => isSubmitting = false);
                  return;
                }
                reviewController.dispose();
                ref.read(activeTripStateProvider.notifier).stateTrip = null;
                Navigator.pop(context);
                context.go(Routes.driverHome);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _makeCall(String phone) {
    if (phone.isEmpty) return;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _activeTrip == null) {
      return const Scaffold(
        backgroundColor: TRYPColors.white,
        body: Center(
          child: CircularProgressIndicator(color: TRYPColors.primary),
        ),
      );
    }

    if (_activeTrip == null) {
      return Scaffold(
        backgroundColor: TRYPColors.white,
        appBar: AppBar(title: const Text('Active Trip')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_drinks_rounded,
                size: 48,
                color: TRYPColors.grey,
              ),
              const SizedBox(height: 12),
              Text(
                'No active trip in progress',
                style: TRYPTypography.headingSmall,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(Routes.driverHome),
                child: const Text('Go to Driver Home'),
              ),
            ],
          ),
        ),
      );
    }

    final trip = _activeTrip!;
    final status = trip.status;

    String headerTitle = 'Trip Details';
    String actionButtonLabel = 'Update Status';
    VoidCallback? onActionButtonPressed;

    switch (status) {
      case TripStatus.accepted:
        headerTitle = 'En Route to Pickup';
        actionButtonLabel = 'I Have Arrived at Pickup';
        onActionButtonPressed = _markArrivedAtPickup;
        break;
      case TripStatus.arrived:
        headerTitle = 'Arrived at Pickup';
        actionButtonLabel = 'Verify Safety PIN & Start Trip';
        onActionButtonPressed = _showPinVerificationDialog;
        break;
      case TripStatus.inTrip:
        headerTitle = 'Trip in Progress';
        actionButtonLabel =
            'Complete Trip • Collect R${trip.fare.toStringAsFixed(2)}';
        onActionButtonPressed = () =>
            _updateTripStatus(TripStatus.completed, asDriverCompletion: true);
        break;
      case TripStatus.completed:
        headerTitle = 'Trip Completed';
        actionButtonLabel = 'Return to Driver Home';
        onActionButtonPressed = () => context.go(Routes.driverHome);
        break;
      case TripStatus.cancelled:
        headerTitle = 'Trip Cancelled';
        actionButtonLabel = 'Return to Driver Home';
        onActionButtonPressed = () => context.go(Routes.driverHome);
        break;
      default:
        break;
    }

    return Scaffold(
      backgroundColor: TRYPColors.surface,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(Routes.driverHome),
        ),
        title: Text(
          headerTitle,
          style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
        ),
        actions: [
          if (status == TripStatus.accepted ||
              status == TripStatus.arrived ||
              status == TripStatus.inTrip)
            IconButton(
              icon: const Icon(Icons.chat_rounded),
              onPressed: _showChat,
              tooltip: 'Chat with passenger',
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: TRYPColors.success,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  'Active Ride',
                  style: TRYPTypography.labelSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (status == TripStatus.accepted)
                  IconButton(
                    icon: const Icon(Icons.navigation_rounded),
                    onPressed: () =>
                        unawaited(_refreshPickupRouteIfNeeded(force: true)),
                    tooltip: 'Refresh pickup route',
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Map Preview
            Expanded(
              child: MapWidget(
                key: const ValueKey('driver-active-trip-map'),
                cameraOptions: CameraOptions(
                  center: _mapPoint(trip.pickupLat, trip.pickupLng),
                  zoom: 14,
                ),
                styleUri: TRYPMapStyles.light,
                onStyleLoadedListener: (_) {
                  final map = _mapController;
                  if (map != null) {
                    unawaited(TRYPMapStyles.applyBranding(map));
                  }
                },
                onMapCreated: (controller) {
                  _mapController = controller;
                  unawaited(
                    controller.location.updateSettings(
                      LocationComponentSettings(enabled: true),
                    ),
                  );
                  unawaited(_buildMapMarkersAndRoute(trip));
                },
              ),
            ),

            // Passenger & Action Panel
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: TRYPColors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: TRYPColors.secondary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Passenger Details Card
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: TRYPColors.primary,
                        backgroundImage:
                            (trip.passengerAvatar != null &&
                                trip.passengerAvatar!.isNotEmpty)
                            ? NetworkImage(trip.passengerAvatar!)
                            : null,
                        child:
                            (trip.passengerAvatar == null ||
                                trip.passengerAvatar!.isEmpty)
                            ? const Icon(
                                Icons.person_rounded,
                                color: TRYPColors.secondary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.passengerName ?? 'Verified Passenger',
                              style: TRYPTypography.headingSmall.copyWith(
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              status == TripStatus.accepted ||
                                      status == TripStatus.arrived
                                  ? 'Pickup: ${trip.origin}'
                                  : 'Dropoff: ${trip.destination}',
                              style: TRYPTypography.bodySmall.copyWith(
                                color: TRYPColors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _makeCall(trip.passengerPhone ?? ''),
                        icon: const Icon(
                          Icons.phone_rounded,
                          color: TRYPColors.primary,
                        ),
                        tooltip: 'Call Passenger',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.groups_rounded,
                        size: 18,
                        color: TRYPColors.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${trip.totalPassengers} passenger${trip.totalPassengers == 1 ? '' : 's'} expected',
                        style: TRYPTypography.bodySmall.copyWith(
                          color: TRYPColors.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (trip.additionalPassengers > 0)
                        Text(
                          ' (${trip.additionalPassengers} companion${trip.additionalPassengers == 1 ? '' : 's'})',
                          style: TRYPTypography.bodySmall.copyWith(
                            color: TRYPColors.grey,
                          ),
                        ),
                    ],
                  ),
                  if (status == TripStatus.accepted &&
                      _pickupEtaMins != null &&
                      _pickupDistanceKm != null) ...[
                    const SizedBox(height: 10),
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
                            Icons.navigation_rounded,
                            size: 18,
                            color: TRYPColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pickup route: ${_pickupDistanceKm!.toStringAsFixed(1)} km • about ${_pickupEtaMins} min',
                              style: TRYPTypography.bodySmall.copyWith(
                                color: TRYPColors.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Route & Fare Summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${trip.rideReference.isNotEmpty ? trip.rideReference : 'Trip'} Fare:',
                        style: TRYPTypography.bodySmall.copyWith(
                          color: TRYPColors.grey,
                        ),
                      ),
                      Text(
                        'R${trip.fare.toStringAsFixed(2)} (${trip.paymentMethod})',
                        style: TRYPTypography.titleMedium.copyWith(
                          color: TRYPColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Distance:',
                        style: TRYPTypography.bodySmall.copyWith(
                          color: TRYPColors.grey,
                        ),
                      ),
                      Text(
                        '${trip.distanceKm.toStringAsFixed(1)} km',
                        style: TRYPTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  if (trip.pinCode.isNotEmpty &&
                      (status == TripStatus.accepted ||
                          status == TripStatus.arrived)) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: TRYPColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: TRYPColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Passenger Safety PIN Required to Start',
                            style: TRYPTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  PrimaryButton(
                    label: actionButtonLabel,
                    isLoading: _isLoading,
                    onPressed: onActionButtonPressed ?? () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
