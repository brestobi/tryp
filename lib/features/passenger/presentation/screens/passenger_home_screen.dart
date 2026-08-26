import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/constants/map_styles.dart';
import 'package:tryp/core/services/fare_calculator.dart';
import 'package:tryp/core/services/location_service.dart';
import 'package:tryp/core/services/notification_service.dart';
import 'package:tryp/core/services/payment_service.dart';
import 'package:tryp/core/services/payment_checkout_result.dart';
import 'package:tryp/core/services/ride_request_readiness.dart';
import 'package:tryp/core/services/passenger_verification_service.dart';
import 'package:tryp/core/services/trip_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

/// Location Preset Item
class LocationItem {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final IconData icon;
  final String city;
  final String? placeId;

  const LocationItem({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.icon = Icons.location_on_rounded,
    this.city = 'Johannesburg',
    this.placeId,
  });
}

/// Suggested villages and localities between Tzaneen and The Oaks, Limpopo.
///
/// These are intentionally curated map-centre coordinates, not exact pickup
/// entrances. The optional advanced map-pin flow can provide that precision
/// later without making the basic destination finder depend on a network API.
const List<LocationItem> tzaneenVillages = [
  LocationItem(
    name: 'Tzaneen',
    address: 'Tzaneen, Greater Tzaneen, Limpopo',
    lat: -23.8333,
    lng: 30.1667,
    icon: Icons.location_city_rounded,
    city: 'Greater Tzaneen',
  ),
  LocationItem(
    name: 'Nkowankowa',
    address: 'Nkowankowa, Greater Tzaneen, Limpopo',
    lat: -23.8833,
    lng: 30.3833,
    icon: Icons.home_work_outlined,
    city: 'Greater Tzaneen',
  ),
  LocationItem(
    name: 'Letsitele',
    address: 'Letsitele, Greater Tzaneen, Limpopo',
    lat: -23.9000,
    lng: 30.3833,
    icon: Icons.agriculture_outlined,
    city: 'Greater Tzaneen',
  ),
  LocationItem(
    name: 'Lenyenye',
    address: 'Lenyenye, Greater Tzaneen, Limpopo',
    lat: -23.9500,
    lng: 30.3167,
    icon: Icons.home_work_outlined,
    city: 'Greater Tzaneen',
  ),
  LocationItem(
    name: 'Gravelotte',
    address: 'Gravelotte, Mopani District, Limpopo',
    lat: -23.9333,
    lng: 30.6167,
    icon: Icons.route_rounded,
    city: 'Mopani District',
  ),
  LocationItem(
    name: 'Ofcolaco',
    address: 'Ofcolaco, Mopani District, Limpopo',
    lat: -24.0802,
    lng: 30.3950,
    icon: Icons.home_work_outlined,
    city: 'Mopani District',
  ),
  LocationItem(
    name: 'Trichardtsdal',
    address: 'Trichardtsdal, Mopani District, Limpopo',
    lat: -24.1695,
    lng: 30.4006,
    icon: Icons.home_work_outlined,
    city: 'Mopani District',
  ),
  LocationItem(
    name: 'Calais',
    address: 'Calais, Mopani District, Limpopo',
    lat: -24.1320,
    lng: 30.3480,
    icon: Icons.home_work_outlined,
    city: 'Mopani District',
  ),
  LocationItem(
    name: 'The Oaks',
    address: 'The Oaks, Maruleng, Limpopo',
    lat: -24.3630,
    lng: 30.6730,
    icon: Icons.location_on_rounded,
    city: 'Maruleng',
  ),
];

enum PassengerRideMode {
  idle, // Showing "Where to?" bar & map
  searchOverlay, // Searching destination/pickup
  tierSelection, // Selecting TRYP Go / Comfort / XL / Exec tier
  scheduledConfirmation, // Scheduled ride saved for a future pickup
  dispatching, // Searching for driver (pulsing radar)
  activeTrip, // Driver assigned & en route
}

/// Demolished & Rebuilt Passenger Home Screen — Bolt Style:
/// The Home Screen IS the primary Ride Screen.
class PassengerHomeScreenPage extends ConsumerStatefulWidget {
  const PassengerHomeScreenPage({super.key});

  @override
  ConsumerState<PassengerHomeScreenPage> createState() =>
      _PassengerHomeScreenPageState();
}

class _PassengerHomeScreenPageState
    extends ConsumerState<PassengerHomeScreenPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MapboxMap? _mapController;
  CircleAnnotationManager? _circleAnnotationManager;
  static const String _destinationTapInteractionId =
      'passenger-destination-map-tap';
  PolylineAnnotationManager? _lineAnnotationManager;
  PassengerRideMode _mode = PassengerRideMode.idle;

  // Locations
  LocationItem _pickup = const LocationItem(
    name: 'Sandton City Mall',
    address: '83 Rivonia Rd, Sandhurst, Sandton',
    lat: -26.1076,
    lng: 28.0567,
    icon: Icons.my_location_rounded,
    city: 'Sandton',
  );
  LocationItem? _destination;
  LocationItem? _currentLocation;
  bool _hasCenteredOnCurrentLocation = false;

  // Search state
  final TextEditingController _destinationSearchController =
      TextEditingController();
  final TextEditingController _pickupSearchController = TextEditingController();
  final TextEditingController _coordinateController = TextEditingController();
  List<LocationItem> _searchResults = tzaneenVillages;
  int _locationSelectionId = 0;
  bool _isSelectingOnMap = false;
  bool _isSearchingPickup = false;

  // Selection & Pricing
  String _selectedRideType = 'TRYP Go';
  String _paymentMethod = 'Cash';
  int _additionalPassengers = 0;
  bool _isScheduledRide = false;
  DateTime? _scheduledFor;
  double? _calculatedDistanceKm;
  int? _calculatedDurationMins;
  bool _isRouteCalculationComplete = false;
  int _routeCalculationId = 0;
  bool _isLoading = false;

  // Map annotations are managed by Mapbox after the map is created.

  // Dispatch radar animation
  late AnimationController _radarAnimController;
  RealtimeChannel? _rideSubscription;
  Timer? _rideStatusRefreshTimer;
  Timer? _searchDebounceTimer;
  int _searchRequestId = 0;
  String? _completionRideId;
  String? _watchedRideId;
  DateTime? _lastPaymentVerificationAt;
  bool _rideStatusRefreshInFlight = false;
  bool _paymentVerificationInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fetchUserLocation();
    _restoreActiveRide();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshActiveRideStatus());
      final activeTrip = ref.read(activeTripStateProvider);
      if (activeTrip != null) {
        // Recreate the ride channel because mobile operating systems may
        // suspend websocket connections while the app is backgrounded.
        _watchedRideId = activeTrip.id;
        _subscribeToRide(activeTrip.id);
        if (activeTrip.paymentMethod != 'Cash' &&
            activeTrip.paymentStatus != 'paid') {
          unawaited(_verifyOnlinePayment(activeTrip.id));
        }
      }
    }
  }

  Future<void> _verifyOnlinePayment(String rideId) async {
    if (_paymentVerificationInFlight) return;
    final lastChecked = _lastPaymentVerificationAt;
    if (lastChecked != null &&
        DateTime.now().difference(lastChecked) < const Duration(seconds: 8)) {
      return;
    }

    _paymentVerificationInFlight = true;
    _lastPaymentVerificationAt = DateTime.now();
    try {
      final status = await PaymentService.verifyRidePayment(rideId: rideId);
      if (!mounted) return;

      final tripService = ref.read(tripServiceProvider);
      final result = paymentCheckoutResultForStatus(status);
      if (result == PaymentCheckoutResult.failed ||
          result == PaymentCheckoutResult.cancelled) {
        final cancellationResult = await ref
            .read(tripServiceProvider)
            .cancelUnpaidRidePayment(rideId);
        if (cancellationResult == 'paid') {
          final settledTrip = await ref
              .read(tripServiceProvider)
              .getTripById(rideId);
          if (settledTrip != null && mounted) {
            ref.read(activeTripStateProvider.notifier).stateTrip = settledTrip;
            setState(() {
              _mode = settledTrip.status == TripStatus.requested
                  ? PassengerRideMode.dispatching
                  : PassengerRideMode.activeTrip;
            });
          }
          return;
        }
        if (cancellationResult != 'cancelled') return;
        ref.read(activeTripStateProvider.notifier).stateTrip = null;
        _watchedRideId = null;
        _rideStatusRefreshTimer?.cancel();
        _rideSubscription?.unsubscribe();
        _rideSubscription = null;
        if (mounted) setState(() => _mode = PassengerRideMode.idle);
        return;
      }

      final updatedTrip = await tripService.getTripById(rideId);
      if (updatedTrip != null && mounted) {
        ref.read(activeTripStateProvider.notifier).stateTrip = updatedTrip;
        setState(() {
          _mode = _isFutureScheduledRide(updatedTrip)
              ? PassengerRideMode.scheduledConfirmation
              : updatedTrip.status == TripStatus.requested
              ? PassengerRideMode.dispatching
              : PassengerRideMode.activeTrip;
        });
      }
    } catch (error) {
      debugPrint('Paystack payment recovery check failed: $error');
    } finally {
      _paymentVerificationInFlight = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _radarAnimController.dispose();
    _destinationSearchController.dispose();
    _pickupSearchController.dispose();
    _coordinateController.dispose();
    _rideStatusRefreshTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _rideSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _restoreActiveRide() async {
    final tripService = ref.read(tripServiceProvider);
    final activeTrip = await tripService.getPassengerActiveTrip();
    if (!mounted || activeTrip == null) return;

    ref.read(activeTripStateProvider.notifier).stateTrip = activeTrip;
    _syncScheduleFromTrip(activeTrip);
    _watchedRideId = activeTrip.id;
    _lastPaymentVerificationAt = null;
    setState(() {
      _mode = _isFutureScheduledRide(activeTrip)
          ? PassengerRideMode.scheduledConfirmation
          : activeTrip.status == TripStatus.requested
          ? PassengerRideMode.dispatching
          : PassengerRideMode.activeTrip;
    });

    _subscribeToRide(activeTrip.id);
    _startRideStatusRefreshTimer();
    if (activeTrip.paymentMethod != 'Cash' &&
        activeTrip.paymentStatus != 'paid') {
      unawaited(_verifyOnlinePayment(activeTrip.id));
    }
  }

  void _startRideStatusRefreshTimer() {
    _rideStatusRefreshTimer?.cancel();
    _rideStatusRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(_refreshActiveRideStatus()),
    );
  }

  /// Reconcile the active-trip panel with the server if realtime delivery was
  /// missed while the app was backgrounded or briefly offline.
  Future<void> _refreshActiveRideStatus() async {
    final activeTrip = ref.read(activeTripStateProvider);
    final rideId = _watchedRideId ?? activeTrip?.id;
    if (!mounted || rideId == null || _rideStatusRefreshInFlight) return;

    _rideStatusRefreshInFlight = true;
    try {
      final updatedTrip = await ref
          .read(tripServiceProvider)
          .getTripById(rideId);
      if (!mounted || updatedTrip == null || _watchedRideId != rideId) {
        return;
      }

      if (updatedTrip.status == TripStatus.completed) {
        _openCompletionScreen(updatedTrip);
        return;
      }

      if (updatedTrip.status == TripStatus.cancelled) {
        ref.read(activeTripStateProvider.notifier).stateTrip = null;
        _watchedRideId = null;
        _rideStatusRefreshTimer?.cancel();
        _rideSubscription?.unsubscribe();
        _rideSubscription = null;
        setState(() => _mode = PassengerRideMode.idle);
        return;
      }

      ref.read(activeTripStateProvider.notifier).stateTrip = updatedTrip;
      _syncScheduleFromTrip(updatedTrip);
      if (updatedTrip.paymentMethod != 'Cash' &&
          updatedTrip.paymentStatus != 'paid') {
        unawaited(_verifyOnlinePayment(updatedTrip.id));
      }
      setState(() {
        _mode = _isFutureScheduledRide(updatedTrip)
            ? PassengerRideMode.scheduledConfirmation
            : updatedTrip.status == TripStatus.requested
            ? PassengerRideMode.dispatching
            : PassengerRideMode.activeTrip;
      });
    } finally {
      _rideStatusRefreshInFlight = false;
    }
  }

  bool _isFutureScheduledRide(TripModel trip) {
    final scheduledFor = trip.scheduledFor;
    return scheduledFor != null && scheduledFor.isAfter(DateTime.now());
  }

  void _syncScheduleFromTrip(TripModel trip) {
    _scheduledFor = trip.scheduledFor;
    _isScheduledRide = trip.scheduledFor != null;
    if (trip.destination.isNotEmpty && trip.destLat != 0 && trip.destLng != 0) {
      _destination = LocationItem(
        name: trip.destination,
        address: trip.destination,
        lat: trip.destLat,
        lng: trip.destLng,
        city: 'Booked destination',
      );
    }
  }

  String _formatPickupTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} at $hour:$minute $period';
  }

  Future<void> _chooseScheduledPickup() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate:
          (_scheduledFor?.toLocal() ?? now.add(const Duration(hours: 1))),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
      helpText: 'Choose pickup date',
    );
    if (!mounted || selectedDate == null) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: _scheduledFor == null
          ? TimeOfDay.fromDateTime(now.add(const Duration(hours: 1)))
          : TimeOfDay.fromDateTime(_scheduledFor!.toLocal()),
      helpText: 'Choose pickup time',
    );
    if (!mounted || selectedTime == null) return;

    final scheduledFor = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    if (!scheduledFor.isAfter(now.add(const Duration(minutes: 10)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please choose a pickup time at least 10 minutes from now.',
          ),
          backgroundColor: TRYPColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isScheduledRide = true;
      _scheduledFor = scheduledFor;
    });
  }

  void _showPickupTimePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TRYPColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pickup time', style: TRYPTypography.headingSmall),
              const SizedBox(height: 6),
              Text(
                'Choose whether you need a ride now or later.',
                style: TRYPTypography.bodySmall.copyWith(
                  color: TRYPColors.grey,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: !_isScheduledRide ? TRYPColors.inputFill : null,
                leading: const Icon(
                  Icons.flash_on_rounded,
                  color: TRYPColors.primary,
                ),
                title: const Text('Now'),
                subtitle: const Text('Request a nearby driver immediately'),
                trailing: !_isScheduledRide
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: TRYPColors.secondary,
                      )
                    : null,
                onTap: () {
                  setState(() {
                    _isScheduledRide = false;
                    _scheduledFor = null;
                  });
                  Navigator.pop(sheetContext);
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: _isScheduledRide ? TRYPColors.inputFill : null,
                leading: const Icon(
                  Icons.calendar_month_rounded,
                  color: TRYPColors.secondary,
                ),
                title: Text(
                  _scheduledFor == null
                      ? 'Schedule for later'
                      : _formatPickupTime(_scheduledFor!),
                ),
                subtitle: const Text('Book a date and time in advance'),
                trailing: _isScheduledRide
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: TRYPColors.secondary,
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _chooseScheduledPickup();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelActiveRide() async {
    final activeTrip = ref.read(activeTripStateProvider);
    if (activeTrip == null || !activeTrip.canPassengerCancel) return;

    final tripService = ref.read(tripServiceProvider);
    if (activeTrip.paymentMethod != 'Cash' &&
        activeTrip.paymentStatus != 'paid') {
      final cancellationResult = await tripService.cancelUnpaidRidePayment(
        activeTrip.id,
      );
      if (cancellationResult == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not safely cancel the payment. Please try again.',
              ),
              backgroundColor: TRYPColors.error,
            ),
          );
        }
        return;
      }
      if (cancellationResult == 'paid') {
        final settledTrip = await tripService.getTripById(activeTrip.id);
        if (settledTrip != null && mounted) {
          ref.read(activeTripStateProvider.notifier).stateTrip = settledTrip;
          setState(() {
            _mode = settledTrip.status == TripStatus.requested
                ? PassengerRideMode.dispatching
                : PassengerRideMode.activeTrip;
          });
        }
        return;
      }
      if (cancellationResult != 'cancelled') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment is still being verified. The ride was not cancelled.',
              ),
              backgroundColor: TRYPColors.secondary,
            ),
          );
        }
        return;
      }
    } else {
      final updated = await tripService.updateTripStatus(
        rideId: activeTrip.id,
        status: TripStatus.cancelled,
      );
      if (!mounted) return;

      if (updated == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not cancel the ride request.'),
            backgroundColor: TRYPColors.error,
          ),
        );
        return;
      }
    }

    ref.read(activeTripStateProvider.notifier).stateTrip = null;
    _rideStatusRefreshTimer?.cancel();
    _rideSubscription?.unsubscribe();
    _rideSubscription = null;
    setState(() => _mode = PassengerRideMode.idle);
  }

  void _subscribeToRide(String rideId) {
    _rideSubscription?.unsubscribe();
    final tripService = ref.read(tripServiceProvider);
    _rideSubscription = tripService.subscribeToRide(
      rideId: rideId,
      onUpdate: (_) => unawaited(_refreshActiveRideStatus()),
    );
  }

  void _openCompletionScreen(TripModel trip) {
    if (_completionRideId == trip.id || !mounted) return;
    _completionRideId = trip.id;
    _watchedRideId = null;
    _rideStatusRefreshTimer?.cancel();
    ref.read(activeTripStateProvider.notifier).stateTrip = null;
    _rideSubscription?.unsubscribe();
    _rideSubscription = null;
    context.go(Routes.rideCompletion, extra: trip);
  }

  Future<void> _fetchUserLocation() async {
    try {
      final locationService = ref.read(locationServiceProvider);
      final userLoc = await locationService.getUserLocationWithAddress();
      if (!mounted) return;

      final locItem = LocationItem(
        name: userLoc.shortName,
        address: userLoc.address,
        lat: userLoc.latitude,
        lng: userLoc.longitude,
        icon: Icons.gps_fixed_rounded,
        city: 'Current Location',
      );

      setState(() {
        _currentLocation = locItem;
        _pickup = locItem;
        _pickupSearchController.text = locItem.name;
      });

      _centerMapOnCurrentLocation();
      _updateMapMarkers();
    } catch (_) {
      _updateMapMarkers();
    }
  }

  void _centerMapOnCurrentLocation() {
    final currentLocation = _currentLocation;
    final map = _mapController;
    if (_hasCenteredOnCurrentLocation ||
        currentLocation == null ||
        map == null) {
      return;
    }

    _hasCenteredOnCurrentLocation = true;
    map.easeTo(
      CameraOptions(
        center: _mapPoint(currentLocation.lat, currentLocation.lng),
        zoom: 15,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  Point _mapPoint(double latitude, double longitude) =>
      Point(coordinates: Position(longitude, latitude));

  Future<void> _clearMapRoute() async {
    if (kIsWeb) return;
    if (_lineAnnotationManager != null) {
      await _lineAnnotationManager!.deleteAll();
    }
  }

  Future<void> _drawMapRoute(List<MapCoordinate> points) async {
    if (kIsWeb) return;
    final map = _mapController;
    if (map == null || points.isEmpty) return;

    _lineAnnotationManager ??= await map.annotations
        .createPolylineAnnotationManager();
    await _lineAnnotationManager!.deleteAll();
    await _lineAnnotationManager!.create(
      PolylineAnnotationOptions(
        geometry: LineString(
          coordinates: points
              .map((point) => Position(point.longitude, point.latitude))
              .toList(),
        ),
        lineColor: TRYPColors.primary.toARGB32(),
        lineWidth: 5,
        lineJoin: LineJoin.ROUND,
      ),
    );
  }

  Future<void> _updateMapMarkers() async {
    // Circle and polyline annotation managers are not implemented by the
    // Mapbox Flutter Web plugin. The base map remains available on web.
    if (kIsWeb) return;
    final map = _mapController;
    if (map == null) return;

    _circleAnnotationManager ??= await map.annotations
        .createCircleAnnotationManager();
    await _circleAnnotationManager!.deleteAll();

    final annotations = <CircleAnnotationOptions>[
      CircleAnnotationOptions(
        geometry: _mapPoint(_pickup.lat, _pickup.lng),
        circleColor: TRYPColors.secondary.toARGB32(),
        circleRadius: 8,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2,
      ),
    ];

    if (_destination != null) {
      annotations.add(
        CircleAnnotationOptions(
          geometry: _mapPoint(_destination!.lat, _destination!.lng),
          circleColor: Colors.red.toARGB32(),
          circleRadius: 8,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2,
        ),
      );
    }

    // Fetch and render real online drivers from database.
    try {
      final tripService = ref.read(tripServiceProvider);
      final onlineDrivers = await tripService.getOnlineDrivers(
        pickupLat: _pickup.lat,
        pickupLng: _pickup.lng,
      );
      for (final driver in onlineDrivers) {
        if (driver.currentLat != null && driver.currentLng != null) {
          annotations.add(
            CircleAnnotationOptions(
              geometry: _mapPoint(driver.currentLat!, driver.currentLng!),
              circleColor: TRYPColors.white.toARGB32(),
              circleRadius: 7,
              circleStrokeColor: TRYPColors.secondary.toARGB32(),
              circleStrokeWidth: 2,
            ),
          );
        }
      }
    } catch (_) {}

    await _circleAnnotationManager!.createMulti(annotations);
  }

  Future<LocationItem?> _resolveLocationItem(LocationItem item) async {
    // Every tap invalidates an earlier async selection, including a preset or
    // current-location tap that does not need a network request.
    final selectionId = ++_locationSelectionId;

    // Curated villages and the current GPS location already contain a
    // deliberate coordinate. Mapbox results carry an encoded result ID and
    // are resolved locally before map use.
    if (item.placeId == null) return item;

    final details = await ref
        .read(locationServiceProvider)
        .getPlaceDetails(item.placeId!);
    if (!mounted || selectionId != _locationSelectionId || details == null) {
      return null;
    }

    return LocationItem(
      // Keep the display text returned by Mapbox while using the exact
      // coordinates resolved from its encoded result ID.
      name: item.name,
      address: item.address,
      lat: details.latitude,
      lng: details.longitude,
      icon: item.icon,
      city: item.city,
      placeId: details.placeId,
    );
  }

  Future<void> _selectDestination(LocationItem item) async {
    ++_routeCalculationId;
    setState(() {
      _isRouteCalculationComplete = false;
      _calculatedDistanceKm = null;
      _calculatedDurationMins = null;
    });

    await _clearMapRoute();
    final resolved = await _resolveLocationItem(item);
    if (!mounted || resolved == null) return;

    setState(() {
      _destination = resolved;
      _destinationSearchController.text = resolved.name;
      _isRouteCalculationComplete = false;
      _calculatedDistanceKm = null;
      _calculatedDurationMins = null;

      _mode = PassengerRideMode.tierSelection;
    });

    FocusScope.of(context).unfocus();
    await _recalculateRoute();
  }

  Future<void> _recalculateRoute() async {
    final calculationId = ++_routeCalculationId;
    if (_destination == null) {
      if (mounted) {
        setState(() {
          _isRouteCalculationComplete = false;
          _calculatedDistanceKm = null;
          _calculatedDurationMins = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isRouteCalculationComplete = false);
    }

    final locationService = ref.read(locationServiceProvider);
    final routeResult = await locationService.getRealRoute(
      startLat: _pickup.lat,
      startLng: _pickup.lng,
      endLat: _destination!.lat,
      endLng: _destination!.lng,
    );

    if (!mounted || calculationId != _routeCalculationId) return;

    setState(() {
      _calculatedDistanceKm = routeResult.distanceKm;
      _calculatedDurationMins = routeResult.durationMins;
      _isRouteCalculationComplete = true;
    });

    await _drawMapRoute(routeResult.polylinePoints);
    await _updateMapMarkers();
    _animateMapBounds();
  }

  void _animateMapBounds() {
    if (_mapController == null || _destination == null) return;

    final centerLat = (_pickup.lat + _destination!.lat) / 2;
    final centerLng = (_pickup.lng + _destination!.lng) / 2;
    _mapController!.easeTo(
      CameraOptions(center: _mapPoint(centerLat, centerLng), zoom: 11.5),
      MapAnimationOptions(duration: 800),
    );
  }

  Future<void> _requestRide() async {
    if (_destination == null ||
        !_isRouteCalculationComplete ||
        _calculatedDistanceKm == null ||
        _calculatedDurationMins == null ||
        _isLoading) {
      return;
    }

    final isVerified = await ref
        .read(passengerVerificationServiceProvider)
        .isApproved();
    if (!isVerified) {
      if (!mounted) return;
      await context.push(Routes.passengerVerification);
      return;
    }
    final liveSchemas = ref.read(fareSchemasProvider).asData?.value;
    final fareSchema = liveSchemas?[_selectedRideType];
    if (fareSchema == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Current fare rates are still loading. Please try again.',
            ),
            backgroundColor: TRYPColors.error,
          ),
        );
      }
      return;
    }

    final selectedCapacity = FareCalculatorService.capacityForRideType(
      _selectedRideType,
    );
    if (_additionalPassengers + 1 > selectedCapacity) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$_selectedRideType allows up to $selectedCapacity people. Choose fewer companions or TRYP XL.',
            ),
            backgroundColor: TRYPColors.error,
          ),
        );
      }
      return;
    }

    final fare = FareCalculatorService.calculateFare(
      distanceKm: _calculatedDistanceKm!,
      durationMins: _calculatedDurationMins!.toDouble(),
      rideTypeId: _selectedRideType,
      schema: fareSchema,
      additionalPassengers: _additionalPassengers,
    );

    setState(() {
      _mode = PassengerRideMode.dispatching;
      _isLoading = true;
    });

    try {
      final tripService = ref.read(tripServiceProvider);
      if (!mounted) return;
      final checkoutNavigator = Navigator.of(context);
      final newTrip = await tripService.requestRide(
        origin: _pickup.name,
        destination: _destination!.name,
        fare: fare,
        rideType: _selectedRideType,
        paymentMethod: _paymentMethod,
        distanceKm: _calculatedDistanceKm!,
        durationMins: _calculatedDurationMins!.toDouble(),
        pickupLat: _pickup.lat,
        pickupLng: _pickup.lng,
        destLat: _destination!.lat,
        destLng: _destination!.lng,
        scheduledFor: _isScheduledRide ? _scheduledFor : null,
        additionalPassengers: _additionalPassengers,
      );

      ref.read(activeTripStateProvider.notifier).stateTrip = newTrip;
      _syncScheduleFromTrip(newTrip);
      _watchedRideId = newTrip.id;
      _lastPaymentVerificationAt = null;
      if (_isFutureScheduledRide(newTrip)) {
        setState(() => _mode = PassengerRideMode.scheduledConfirmation);
      }
      _startRideStatusRefreshTimer();

      // Add Notification
      ref
          .read(notificationsProvider.notifier)
          .addNotification(
            title: _isScheduledRide ? 'Ride Scheduled' : 'Ride Requested!',
            body: _isScheduledRide
                ? 'Your ride to ${_destination!.name} is booked for ${_formatPickupTime(_scheduledFor!)}.'
                : 'Searching for nearby drivers to ${_destination!.name} (R${fare.toStringAsFixed(2)})',
            type: NotificationType.ride,
            routePath: Routes.passengerHome,
          );

      // Online payment initialization, amount calculation, reference
      // generation, and subaccount routing all happen in Supabase. The app
      // only opens the server-returned hosted checkout URL.
      if (_paymentMethod != 'Cash') {
        try {
          final checkoutResult = await PaymentService.chargeForRide(
            navigator: checkoutNavigator,
            rideId: newTrip.id,
          );
          if (!mounted) return;
          if (checkoutResult == PaymentCheckoutResult.cancelled ||
              checkoutResult == PaymentCheckoutResult.failed) {
            final cancellationResult = await tripService
                .cancelUnpaidRidePayment(newTrip.id);
            if (cancellationResult == null) {
              throw StateError(
                'The payment state could not be updated safely. Ride cancellation was not completed.',
              );
            }
            if (cancellationResult == 'paid') {
              // A webhook may have won the race. Keep the settled ride and
              // reload it instead of presenting a cancellation message.
              final settledTrip = await tripService.getTripById(newTrip.id);
              if (settledTrip != null && mounted) {
                ref.read(activeTripStateProvider.notifier).stateTrip =
                    settledTrip;
                setState(() {
                  _mode = settledTrip.status == TripStatus.requested
                      ? PassengerRideMode.dispatching
                      : PassengerRideMode.activeTrip;
                });
              }
              return;
            }
            if (cancellationResult != 'cancelled') {
              // The transaction is unresolved; leave the ride available for
              // webhook/app-resume reconciliation rather than releasing it.
              return;
            }
            if (!mounted) return;
            ref.read(activeTripStateProvider.notifier).stateTrip = null;
            _watchedRideId = null;
            _rideStatusRefreshTimer?.cancel();
            _rideSubscription?.unsubscribe();
            _rideSubscription = null;
            if (!mounted) return;
            setState(() => _mode = PassengerRideMode.tierSelection);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  checkoutResult == PaymentCheckoutResult.failed
                      ? 'Payment failed. The ride request was cancelled.'
                      : 'Payment cancelled. The ride request was cancelled.',
                ),
                backgroundColor: TRYPColors.error,
              ),
            );
            return;
          }
          if (checkoutResult == PaymentCheckoutResult.pending) {
            if (mounted) {
              ref
                  .read(notificationsProvider.notifier)
                  .addNotification(
                    title: 'Payment Verification Pending',
                    body: 'We are still confirming your Paystack payment.',
                    type: NotificationType.payment,
                    routePath: Routes.rideTracking,
                  );
            }
          }
          if (mounted) {
            ref
                .read(notificationsProvider.notifier)
                .addNotification(
                  title: checkoutResult == PaymentCheckoutResult.paid
                      ? 'Payment Confirmed'
                      : 'Payment Checkout Opened',
                  body: checkoutResult == PaymentCheckoutResult.paid
                      ? 'Your Paystack payment was confirmed securely.'
                      : 'Payment verification is still in progress.',
                  type: NotificationType.payment,
                  routePath: Routes.rideTracking,
                );
          }
        } catch (error) {
          // Initialization failures must not leave a non-payable ride looking
          // like an active request after the payment screen has gone away.
          // The row-locking RPC refuses to cancel if a webhook settled it.
          final cancellationResult = await tripService.cancelUnpaidRidePayment(
            newTrip.id,
          );
          if (cancellationResult == 'cancelled') {
            ref.read(activeTripStateProvider.notifier).stateTrip = null;
            _watchedRideId = null;
            _rideStatusRefreshTimer?.cancel();
            _rideSubscription?.unsubscribe();
            _rideSubscription = null;
          } else if (cancellationResult == 'paid') {
            final settledTrip = await tripService.getTripById(newTrip.id);
            if (settledTrip != null && mounted) {
              ref.read(activeTripStateProvider.notifier).stateTrip =
                  settledTrip;
              _watchedRideId = settledTrip.id;
              setState(() {
                _mode = settledTrip.status == TripStatus.requested
                    ? PassengerRideMode.dispatching
                    : PassengerRideMode.activeTrip;
              });
            }
          } else {
            // Keep the ride active while Paystack/webhook reconciliation is
            // unresolved. Do not convert an unknown payment into cancellation.
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Payment status is still being confirmed. We will keep checking.',
                  ),
                  backgroundColor: TRYPColors.secondary,
                ),
              );
            }
          }
          return;
        }
      }

      // Subscribe to real-time trip status changes via Supabase WebSocket stream
      _rideSubscription = tripService.subscribeToRide(
        rideId: newTrip.id,
        onUpdate: (_) => unawaited(_refreshActiveRideStatus()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not request ride: $e'),
          backgroundColor: TRYPColors.error,
        ),
      );
      setState(() => _mode = PassengerRideMode.tierSelection);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchQueryChanged(String query) {
    _searchDebounceTimer?.cancel();
    final requestId = ++_searchRequestId;
    final trimmed = query.trim();
    final normalized = trimmed.toLowerCase();

    if (trimmed.isEmpty) {
      setState(() => _searchResults = tzaneenVillages);
      return;
    }

    final localMatches = tzaneenVillages.where((item) {
      return item.name.toLowerCase().contains(normalized) ||
          item.address.toLowerCase().contains(normalized) ||
          item.city.toLowerCase().contains(normalized);
    }).toList();
    setState(() => _searchResults = localMatches);

    if (trimmed.length < 2) return;

    // Debounce typing and ignore late responses so old results cannot overwrite
    // a newer Mapbox query.
    _searchDebounceTimer = Timer(const Duration(milliseconds: 700), () {
      unawaited(_searchMapbox(trimmed, requestId));
    });
  }

  Future<void> _searchMapbox(String query, int requestId) async {
    final suggestions = await ref
        .read(locationServiceProvider)
        .searchPlaces(query, near: MapCoordinate(_pickup.lat, _pickup.lng));
    if (!mounted || requestId != _searchRequestId) return;

    final mapboxResults = suggestions.map((suggestion) {
      return LocationItem(
        name: suggestion.name,
        address: suggestion.address,
        lat: 0,
        lng: 0,
        icon: Icons.location_on_rounded,
        city: 'Mapbox',
        placeId: suggestion.placeId,
      );
    }).toList();

    final combined = <LocationItem>[];
    final seen = <String>{};
    for (final item in [..._searchResults, ...mapboxResults]) {
      final key = '${item.name.toLowerCase()}|${item.address.toLowerCase()}';
      if (seen.add(key)) combined.add(item);
    }

    setState(() => _searchResults = combined);
  }

  Future<void> _selectMapPoint(Point point) async {
    final coordinates = point.coordinates;
    final longitude = coordinates.lng.toDouble();
    final latitude = coordinates.lat.toDouble();
    final service = ref.read(locationServiceProvider);
    final resolved = await service.reverseGeocode(latitude, longitude);
    if (!mounted) return;
    final item = LocationItem(
      name: resolved.shortName,
      address: resolved.address,
      lat: latitude,
      lng: longitude,
      icon: Icons.push_pin_rounded,
      city: 'Map pin',
    );
    await _selectDestination(item);
  }

  Future<void> _useCoordinateDestination() async {
    final raw = _coordinateController.text.trim();
    final parts = raw.split(RegExp(r'[ ,]+'));
    if (parts.length != 2) {
      _showLocationError('Enter coordinates as latitude, longitude.');
      return;
    }
    final latitude = double.tryParse(parts[0]);
    final longitude = double.tryParse(parts[1]);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      _showLocationError('Those coordinates are not valid.');
      return;
    }

    final resolved = await ref
        .read(locationServiceProvider)
        .reverseGeocode(latitude, longitude);
    if (!mounted) return;
    await _selectDestination(
      LocationItem(
        name: resolved.shortName,
        address: resolved.address,
        lat: latitude,
        lng: longitude,
        icon: Icons.pin_drop_rounded,
        city: 'Coordinates',
      ),
    );
  }

  void _showLocationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: TRYPColors.error),
    );
  }

  void _openDestinationLocationOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TRYPColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose destination', style: TRYPTypography.headingSmall),
              const SizedBox(height: 6),
              Text(
                'Use the option that is easiest for you.',
                style: TRYPTypography.bodySmall.copyWith(
                  color: TRYPColors.grey,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: TRYPColors.inputFill,
                leading: const Icon(
                  Icons.push_pin_rounded,
                  color: TRYPColors.primary,
                ),
                title: const Text('Pin a place on the map'),
                subtitle: const Text(
                  'Tap anywhere on the map to choose a destination',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _isSelectingOnMap = true;
                    _mode = PassengerRideMode.idle;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Tap the map to place your destination pin.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: TRYPColors.inputFill,
                leading: const Icon(
                  Icons.gps_fixed_rounded,
                  color: TRYPColors.secondary,
                ),
                title: const Text('Enter coordinates'),
                subtitle: const Text('Latitude, longitude'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showCoordinateDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCoordinateDialog() async {
    _coordinateController.clear();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter coordinates'),
        content: TextField(
          controller: _coordinateController,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            hintText: 'Example: -23.8333, 30.1667',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              unawaited(_useCoordinateDestination());
            },
            child: const Text('Use location'),
          ),
        ],
      ),
    );
  }

  void _showPaymentMethodPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: TRYPColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Method', style: TRYPTypography.headingSmall),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: TRYPColors.inputFill,
              leading: const Icon(
                Icons.payments_rounded,
                color: TRYPColors.primary,
                size: 28,
              ),
              title: Text(
                'Cash',
                style: TRYPTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Pay driver directly in cash upon arrival'),
              trailing: _paymentMethod == 'Cash'
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: TRYPColors.secondary,
                    )
                  : null,
              onTap: () {
                setState(() => _paymentMethod = 'Cash');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: TRYPColors.inputFill,
              leading: const Icon(
                Icons.credit_card_rounded,
                color: TRYPColors.secondary,
                size: 28,
              ),
              title: Text(
                'Paystack Card / Online',
                style: TRYPTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Credit/Debit card via Paystack'),
              trailing: _paymentMethod == 'Paystack Card'
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: TRYPColors.secondary,
                    )
                  : null,
              onTap: () {
                setState(() => _paymentMethod = 'Paystack Card');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadNotifs = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: TRYPColors.primary,
      extendBodyBehindAppBar: true,
      appBar: _mode == PassengerRideMode.searchOverlay
          ? null
          : _buildTopAppBar(unreadNotifs),
      body: Stack(
        children: [
          // ── 1. Full-screen Interactive Map ─────────────────────────────
          MapWidget(
            key: const ValueKey('passenger-home-map'),
            viewport: CameraViewportState(
              center: _mapPoint(_pickup.lat, _pickup.lng),
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
              controller.addInteraction(
                TapInteraction.onMap((mapContext) {
                  if (_isSelectingOnMap &&
                      mapContext.gestureState == GestureState.ended) {
                    setState(() => _isSelectingOnMap = false);
                    unawaited(_selectMapPoint(mapContext.point));
                  }
                }),
                interactionID: _destinationTapInteractionId,
              );
              _centerMapOnCurrentLocation();
              if (!kIsWeb) {
                unawaited(
                  controller.location.updateSettings(
                    LocationComponentSettings(enabled: true),
                  ),
                );
                unawaited(_updateMapMarkers());
              }
            },
          ),

          // ── 2. Floating My Location FAB ────────────────────────────────
          if (_mode == PassengerRideMode.idle ||
              _mode == PassengerRideMode.tierSelection)
            Positioned(
              right: 20,
              bottom: _mode == PassengerRideMode.idle ? 230 : 380,
              child: FloatingActionButton.small(
                heroTag: 'my_loc_btn',
                backgroundColor: TRYPColors.white,
                foregroundColor: TRYPColors.secondary,
                onPressed: () {
                  if (_currentLocation != null && _mapController != null) {
                    _mapController!.easeTo(
                      CameraOptions(
                        center: _mapPoint(
                          _currentLocation!.lat,
                          _currentLocation!.lng,
                        ),
                        zoom: 15,
                      ),
                      MapAnimationOptions(duration: 500),
                    );
                  } else {
                    _fetchUserLocation();
                  }
                },
                child: const Icon(Icons.my_location_rounded),
              ),
            ),

          // ── 3. Dispatch Radar Overlay Animation ───────────────────────
          if (_mode == PassengerRideMode.dispatching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1.6).animate(
                      CurvedAnimation(
                        parent: _radarAnimController,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: TRYPColors.primary.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                        border: Border.all(color: TRYPColors.primary, width: 2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_car_filled_rounded,
                          size: 48,
                          color: TRYPColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── 4. Dynamic Interactive Bottom Panel ───────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(
              ref.watch(fareSchemasProvider).asData?.value ??
                  const <String, FareSchema>{},
            ),
          ),

          // ── 5. Full Screen Search Overlay Sheet ───────────────────────
          if (_mode == PassengerRideMode.searchOverlay)
            Positioned.fill(child: _buildSearchOverlayScreen()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(int unreadNotifs) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Logo badge using the branded image asset.
          Container(
            width: 48,
            height: 40,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: TRYPColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Image.asset(
              'assets/images/tryp-logo-red.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 10),

          // Location badge
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: TRYPColors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: TRYPColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _pickup.name,
                      style: TRYPTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: TRYPColors.secondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Notification bell button
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: TRYPColors.white,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: TRYPColors.secondary,
                ),
                onPressed: () => context.push(Routes.notifications),
              ),
              if (unreadNotifs > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: TRYPColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$unreadNotifs',
                        style: const TextStyle(
                          color: TRYPColors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel(Map<String, FareSchema> fareSchemas) {
    switch (_mode) {
      case PassengerRideMode.tierSelection:
        return _buildTierSelectionSheet(fareSchemas);
      case PassengerRideMode.scheduledConfirmation:
        return _buildScheduledRideSheet();
      case PassengerRideMode.dispatching:
        return _buildDispatchingSheet();
      case PassengerRideMode.activeTrip:
        return _buildActiveTripSheet();
      case PassengerRideMode.idle:
      default:
        return _buildIdleSheet();
    }
  }

  // ── MODE A: Idle Sheet with "Where to?" bar & Bottom Nav ───────────
  Widget _buildIdleSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: TRYPColors.divider,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 16),

          // "Where to?" Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                setState(() => _mode = PassengerRideMode.searchOverlay);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: TRYPColors.inputFill,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: TRYPColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        color: TRYPColors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Where to?',
                        style: TRYPTypography.headingSmall.copyWith(
                          color: TRYPColors.secondary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: TRYPColors.accentSoft,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: TRYPColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Now',
                            style: TRYPTypography.labelSmall.copyWith(
                              color: TRYPColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Long Distance Option
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () => context.push(Routes.longDistanceRides),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [TRYPColors.secondary, TRYPColors.primaryAlt],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: TRYPColors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        color: TRYPColors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Long Distance',
                            style: TRYPTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Intercity trips with available seats',
                            style: TRYPTypography.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: TRYPColors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.event_seat_rounded,
                            size: 12,
                            color: TRYPColors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Book',
                            style: TRYPTypography.labelSmall.copyWith(
                              color: TRYPColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TRYPBottomNavBar(currentIndex: 0),
        ],
      ),
    );
  }

  // ── MODE B: Full Screen Search Overlay Modal ──────────────────────
  Widget _buildSearchOverlayScreen() {
    return Container(
      color: TRYPColors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Top Bar with back button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: TRYPColors.secondary,
                    ),
                    onPressed: () {
                      setState(() => _mode = PassengerRideMode.idle);
                    },
                  ),
                  Text(
                    'Plan your ride',
                    style: TRYPTypography.headingMedium.copyWith(fontSize: 20),
                  ),
                ],
              ),
            ),

            // Pickup & Destination Inputs Box
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TRYPColors.inputFill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Pickup Field
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: TRYPColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _pickupSearchController,
                          onTap: () {
                            _isSearchingPickup = true;
                            _onSearchQueryChanged('');
                          },
                          onChanged: (val) {
                            _isSearchingPickup = true;
                            _onSearchQueryChanged(val);
                          },
                          decoration: const InputDecoration(
                            hintText: 'Pickup location',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: TRYPTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Text(
                          'Destination',
                          style: TRYPTypography.labelSmall.copyWith(
                            color: TRYPColors.grey,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _openDestinationLocationOptions,
                          icon: const Icon(Icons.tune_rounded, size: 16),
                          label: const Text('Other options'),
                          style: TextButton.styleFrom(
                            foregroundColor: TRYPColors.secondary,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Destination Field
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: TRYPColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _destinationSearchController,
                          autofocus: true,
                          onTap: () {
                            _isSearchingPickup = false;
                            _onSearchQueryChanged('');
                          },
                          onChanged: (val) {
                            _isSearchingPickup = false;
                            _onSearchQueryChanged(val);
                          },
                          decoration: const InputDecoration(
                            hintText: 'Where to?',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: TRYPTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Results List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TRYPColors.inputFill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.icon,
                        color: TRYPColors.secondary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: TRYPTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      item.address,
                      style: TRYPTypography.bodySmall,
                    ),
                    onTap: () async {
                      if (!_isSearchingPickup) {
                        await _selectDestination(item);
                        return;
                      }

                      ++_routeCalculationId;
                      setState(() {
                        _isRouteCalculationComplete = false;
                        _calculatedDistanceKm = null;
                        _calculatedDurationMins = null;
                      });

                      final resolved = await _resolveLocationItem(item);
                      if (!mounted || resolved == null) return;

                      setState(() {
                        _pickup = resolved;
                        _pickupSearchController.text = resolved.name;
                        _isSearchingPickup = false;
                        _isRouteCalculationComplete = false;
                        _calculatedDistanceKm = null;
                        _calculatedDurationMins = null;
                      });
                      if (!context.mounted) return;
                      FocusScope.of(context).unfocus();
                      await _recalculateRoute();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── MODE C: Vehicle Tier Selection Sheet ───────────────────────────
  Widget _buildTierSelectionSheet(Map<String, FareSchema> fareSchemas) {
    final dist = _calculatedDistanceKm;
    final duration = _calculatedDurationMins;
    final activeSchema = fareSchemas[_selectedRideType];
    final selectedCapacity = FareCalculatorService.capacityForRideType(
      _selectedRideType,
    );
    final selectedTierFits = _additionalPassengers + 1 <= selectedCapacity;
    final activeFare =
        dist == null ||
            duration == null ||
            activeSchema == null ||
            !selectedTierFits
        ? null
        : FareCalculatorService.calculateFare(
            distanceKm: dist,
            durationMins: duration.toDouble(),
            rideTypeId: _selectedRideType,
            schema: activeSchema,
            additionalPassengers: _additionalPassengers,
          );

    final tiers = [
      {
        'id': 'TRYP Go',
        'name': 'TRYP Go',
        'desc': 'Affordable everyday hatchbacks',
        'image': 'assets/images/tryp-go-notext.png',
        'cap': 4,
        'eta': '3 min',
      },
      {
        'id': 'TRYP Comfort',
        'name': 'TRYP Comfort',
        'desc': 'Spacious sedans with top drivers',
        'image': 'assets/images/tryp-comfort-notext.png',
        'cap': 4,
        'eta': '2 min',
      },
      {
        'id': 'TRYP XL',
        'name': 'TRYP XL',
        'desc': 'SUVs & Minivans for groups',
        'image': 'assets/images/tryp-xl-notext.png',
        'cap': 6,
        'eta': '5 min',
      },
      {
        'id': 'TRYP Exec',
        'name': 'TRYP Exec',
        'desc': 'Premium luxury executive rides',
        // No Exec-specific asset exists yet; use the closest sedan image.
        'image': 'assets/images/tryp-comfort-notext.png',
        'cap': 4,
        'eta': '4 min',
      },
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: TRYPColors.divider,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Route info header
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: TRYPColors.secondary,
                ),
                onPressed: () => setState(() => _mode = PassengerRideMode.idle),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trip to ${_destination?.name ?? "Destination"}',
                      style: TRYPTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dist == null || duration == null
                          ? 'Calculating route…'
                          : '${dist.toStringAsFixed(1)} km • ~$duration mins',
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Passenger count is selected before the fare cards are calculated.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TRYPColors.inputFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups_rounded, color: TRYPColors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'People joining you',
                        style: TRYPTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'You + $_additionalPassengers companion${_additionalPassengers == 1 ? '' : 's'}',
                        style: TRYPTypography.bodySmall.copyWith(
                          color: TRYPColors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _additionalPassengers == 0
                      ? null
                      : () => setState(() => _additionalPassengers--),
                  icon: const Icon(Icons.remove_circle_outline_rounded),
                  tooltip: 'Remove companion',
                ),
                Text(
                  '$_additionalPassengers',
                  style: TRYPTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: _additionalPassengers >= 5
                      ? null
                      : () => setState(() => _additionalPassengers++),
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Add companion',
                ),
              ],
            ),
          ),
          if (!selectedTierFits) ...[
            const SizedBox(height: 8),
            Text(
              'This group is too large for $_selectedRideType. Select TRYP XL to continue.',
              style: TRYPTypography.bodySmall.copyWith(
                color: TRYPColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Tier Cards List
          ...tiers.map((tier) {
            final tierId = tier['id'] as String;
            final isSelected = _selectedRideType == tierId;
            final tierCapacity = tier['cap'] as int;
            final tierFits = _additionalPassengers + 1 <= tierCapacity;
            final tierSchema = fareSchemas[tierId];
            final fareAmt =
                tierSchema == null ||
                    dist == null ||
                    duration == null ||
                    !tierFits
                ? null
                : FareCalculatorService.calculateFare(
                    distanceKm: dist,
                    durationMins: duration.toDouble(),
                    rideTypeId: tierId,
                    schema: tierSchema,
                    additionalPassengers: _additionalPassengers,
                  );

            return GestureDetector(
              onTap: tierFits
                  ? () => setState(() => _selectedRideType = tierId)
                  : null,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? TRYPColors.primary.withValues(alpha: 0.12)
                      : TRYPColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? TRYPColors.primary : TRYPColors.divider,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TRYPColors.primary
                            : TRYPColors.inputFill,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.asset(
                        tier['image'] as String,
                        width: 54,
                        height: 40,
                        fit: BoxFit.contain,
                        semanticLabel: '${tier['name']} vehicle',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                tier['name'] as String,
                                style: TRYPTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• ${tier["eta"]}',
                                style: TRYPTypography.bodySmall.copyWith(
                                  color: TRYPColors.grey,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            tier['desc'] as String,
                            style: TRYPTypography.bodySmall.copyWith(
                              color: TRYPColors.grey,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      !tierFits
                          ? 'Too many'
                          : fareAmt == null
                          ? '—'
                          : 'R${fareAmt.toStringAsFixed(2)}',
                      style: TRYPTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: !tierFits
                            ? TRYPColors.error
                            : fareAmt == null
                            ? TRYPColors.grey
                            : TRYPColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 12),

          _buildPickupTimeSelector(),
          const SizedBox(height: 12),

          // Payment selector & CTA
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _showPaymentMethodPicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: TRYPColors.inputFill,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.payment_rounded,
                          size: 18,
                          color: TRYPColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _paymentMethod,
                          style: TRYPTypography.labelMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: TRYPColors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          PrimaryButton(
            label: activeFare == null
                ? 'Loading current fares…'
                : 'Request $_selectedRideType • R${activeFare.toStringAsFixed(2)}',
            isLoading: _isLoading,
            enabled:
                selectedTierFits &&
                canRequestTrip(
                  mapCalculationComplete: _isRouteCalculationComplete,
                  fare: activeFare,
                  isLoading: _isLoading,
                ),
            onPressed: _requestRide,
          ),
        ],
      ),
    );
  }

  Widget _buildPickupTimeSelector() {
    final label = !_isScheduledRide || _scheduledFor == null
        ? 'Now'
        : _formatPickupTime(_scheduledFor!);
    return GestureDetector(
      onTap: _showPickupTimePicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _isScheduledRide
              ? TRYPColors.primary.withValues(alpha: 0.12)
              : TRYPColors.inputFill,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isScheduledRide ? TRYPColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isScheduledRide
                  ? Icons.calendar_month_rounded
                  : Icons.flash_on_rounded,
              size: 19,
              color: TRYPColors.secondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pickup time',
                    style: TRYPTypography.labelSmall.copyWith(
                      color: TRYPColors.grey,
                    ),
                  ),
                  Text(
                    label,
                    style: TRYPTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_calendar_rounded,
              size: 19,
              color: TRYPColors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduledRideSheet() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TRYPColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              color: TRYPColors.secondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text('Ride scheduled', style: TRYPTypography.headingSmall),
          const SizedBox(height: 8),
          Text(
            _scheduledFor == null
                ? 'Your ride has been booked.'
                : 'Pickup: ${_formatPickupTime(_scheduledFor!)}',
            textAlign: TextAlign.center,
            style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'To ${_destination?.name ?? 'your destination'}',
            style: TRYPTypography.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _cancelActiveRide,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Text('Cancel Scheduled Ride'),
          ),
        ],
      ),
    );
  }

  // ── MODE D: Dispatching Radar Sheet ─────────────────────────────────
  Widget _buildDispatchingSheet() {
    final activeTrip = ref.watch(activeTripStateProvider);
    final paymentPending =
        activeTrip != null &&
        activeTrip.paymentMethod != 'Cash' &&
        activeTrip.paymentStatus != 'paid';

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: TRYPColors.secondary),
          const SizedBox(height: 16),
          Text(
            paymentPending
                ? 'Confirming your online payment...'
                : 'Connecting to nearby drivers...',
            style: TRYPTypography.headingSmall,
          ),
          const SizedBox(height: 6),
          Text(
            paymentPending
                ? 'Your ride will be sent to drivers after Paystack confirms the payment.'
                : 'Matching you with top-rated $_selectedRideType drivers near ${_pickup.name}',
            textAlign: TextAlign.center,
            style: TRYPTypography.bodySmall,
          ),
          const SizedBox(height: 20),
          if (paymentPending)
            PrimaryButton(
              label: 'Check Payment Status',
              onPressed: () => unawaited(_verifyOnlinePayment(activeTrip.id)),
            ),
          if (paymentPending) const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _cancelActiveRide,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
  }

  // ── MODE E: Active Trip Sheet ──────────────────────────────────────
  Widget _buildActiveTripSheet() {
    final activeTrip = ref.watch(activeTripStateProvider);
    final driverName = activeTrip?.driverName ?? 'Assigned Driver';
    final vehicleDesc =
        activeTrip?.vehicleDescription ?? 'TRYP Verified Vehicle';
    final avatarUrl = activeTrip?.driverAvatar;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: TRYPColors.primary,
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(Icons.person_rounded, color: TRYPColors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: TRYPTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(vehicleDesc, style: TRYPTypography.bodySmall),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: TRYPColors.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: TRYPColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '4.9',
                      style: TRYPTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: TRYPColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          PrimaryButton(
            label: 'Track Live Trip Progress',
            onPressed: () => context.push(Routes.rideTracking),
          ),
          if (activeTrip?.canPassengerCancel == true) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _cancelActiveRide,
              style: OutlinedButton.styleFrom(
                foregroundColor: TRYPColors.error,
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(
                  color: TRYPColors.error.withValues(alpha: 0.65),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: const Text('Cancel Ride Request'),
            ),
          ],
        ],
      ),
    );
  }
}
