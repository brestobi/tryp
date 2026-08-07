import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/fare_calculator.dart';
import 'package:tryp/core/services/location_service.dart';
import 'package:tryp/core/services/notification_service.dart';
import 'package:tryp/core/services/payment_service.dart';
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

  const LocationItem({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.icon = Icons.location_on_rounded,
    this.city = 'Johannesburg',
  });
}

/// South African Popular Landmarks Preset List
const List<LocationItem> saLandmarks = [
  LocationItem(
    name: 'Rosebank Mall',
    address: '50 Bath Ave, Rosebank, Johannesburg',
    lat: -26.1464,
    lng: 28.0436,
    icon: Icons.shopping_bag_outlined,
    city: 'Rosebank',
  ),
  LocationItem(
    name: 'O.R. Tambo International Airport',
    address: '1 Jones Rd, Kempton Park, Johannesburg',
    lat: -26.1367,
    lng: 28.2411,
    icon: Icons.flight_takeoff_rounded,
    city: 'Kempton Park',
  ),
  LocationItem(
    name: 'Mall of Africa',
    address: 'Lone Creek Cres, Waterfall City, Midrand',
    lat: -26.0152,
    lng: 28.1070,
    icon: Icons.storefront_rounded,
    city: 'Midrand',
  ),
  LocationItem(
    name: 'Montecasino Entertainment World',
    address: 'Montecasino Blvd, Fourways, Sandton',
    lat: -26.0243,
    lng: 28.0131,
    icon: Icons.local_activity_rounded,
    city: 'Fourways',
  ),
  LocationItem(
    name: 'Nelson Mandela Square',
    address: '5th St, Sandown, Sandton',
    lat: -26.1068,
    lng: 28.0543,
    icon: Icons.nature_people_rounded,
    city: 'Sandton',
  ),
  LocationItem(
    name: 'Johannesburg Park Station',
    address: 'Rissik St, Braamfontein, Johannesburg',
    lat: -26.1969,
    lng: 28.0416,
    icon: Icons.train_rounded,
    city: 'Johannesburg',
  ),
  LocationItem(
    name: 'Vilakazi Street, Soweto',
    address: 'Vilakazi St, Orlando West, Soweto',
    lat: -26.2367,
    lng: 27.9069,
    icon: Icons.restaurant_rounded,
    city: 'Soweto',
  ),
  LocationItem(
    name: 'Menlyn Park Shopping Centre',
    address: 'Atterbury Rd & Lois Ave, Menlyn, Pretoria',
    lat: -25.7825,
    lng: 28.2753,
    icon: Icons.shopping_cart_rounded,
    city: 'Pretoria',
  ),
];

enum PassengerRideMode {
  idle, // Showing "Where to?" bar & map
  searchOverlay, // Searching destination/pickup
  tierSelection, // Selecting TRYP Go / Comfort / XL / Exec tier
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
  GoogleMapController? _mapController;
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

  // Search state
  final TextEditingController _destinationSearchController =
      TextEditingController();
  final TextEditingController _pickupSearchController = TextEditingController();
  List<LocationItem> _searchResults = saLandmarks;
  Timer? _searchDebounceTimer;
  bool _isSearchingPickup = false;

  // Selection & Pricing
  String _selectedRideType = 'TRYP Go';
  String _paymentMethod = 'Cash';
  double _calculatedDistanceKm = 6.4;
  int _calculatedDurationMins = 12;
  bool _isLoading = false;

  // Map markers & polylines
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Dispatch radar animation
  late AnimationController _radarAnimController;
  RealtimeChannel? _rideSubscription;
  Timer? _rideStatusRefreshTimer;
  String? _completionRideId;
  String? _watchedRideId;
  bool _rideStatusRefreshInFlight = false;

  static const String _darkMapStyle = '''[
  {
    "featureType": "all",
    "elementType": "geometry",
    "stylers": [{"saturation": -20}, {"lightness": 5}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"lightness": 15}]
  },
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [{"visibility": "simplified"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#d4e6f1"}]
  }
]''';

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
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _radarAnimController.dispose();
    _destinationSearchController.dispose();
    _pickupSearchController.dispose();
    _searchDebounceTimer?.cancel();
    _rideStatusRefreshTimer?.cancel();
    _rideSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _restoreActiveRide() async {
    final tripService = ref.read(tripServiceProvider);
    final activeTrip = await tripService.getPassengerActiveTrip();
    if (!mounted || activeTrip == null) return;

    ref.read(activeTripStateProvider.notifier).stateTrip = activeTrip;
    _watchedRideId = activeTrip.id;
    setState(() {
      _mode = activeTrip.status == TripStatus.requested
          ? PassengerRideMode.dispatching
          : PassengerRideMode.activeTrip;
    });

    _subscribeToRide(activeTrip.id);
    _startRideStatusRefreshTimer();
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
      setState(() {
        _mode = updatedTrip.status == TripStatus.requested
            ? PassengerRideMode.dispatching
            : PassengerRideMode.activeTrip;
      });
    } finally {
      _rideStatusRefreshInFlight = false;
    }
  }

  Future<void> _cancelActiveRide() async {
    final activeTrip = ref.read(activeTripStateProvider);
    if (activeTrip == null) return;

    final tripService = ref.read(tripServiceProvider);
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
      onUpdate: (payload) async {
        if (!mounted) return;
        final updatedTrip = await tripService.getTripById(rideId);
        if (!mounted || updatedTrip == null) return;

        if (updatedTrip.status == TripStatus.completed) {
          _openCompletionScreen(updatedTrip);
          return;
        }

        ref.read(activeTripStateProvider.notifier).stateTrip = updatedTrip;
        if (updatedTrip.status == TripStatus.cancelled) {
          ref.read(activeTripStateProvider.notifier).stateTrip = null;
        }
        setState(() {
          _mode = updatedTrip.status == TripStatus.requested
              ? PassengerRideMode.dispatching
              : updatedTrip.status == TripStatus.cancelled
              ? PassengerRideMode.idle
              : PassengerRideMode.activeTrip;
        });
      },
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

      _updateMapMarkers();
    } catch (_) {
      _updateMapMarkers();
    }
  }

  Future<void> _updateMapMarkers() async {
    final markers = <Marker>{};

    // Pickup Marker (Green)
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(_pickup.lat, _pickup.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup Location', snippet: _pickup.name),
      ),
    );

    // Destination Marker if selected (Red)
    if (_destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(_destination!.lat, _destination!.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destination',
            snippet: _destination!.name,
          ),
        ),
      );
    }

    // Fetch and render real online drivers from database
    try {
      final tripService = ref.read(tripServiceProvider);
      final onlineDrivers = await tripService.getOnlineDrivers();
      for (final driver in onlineDrivers) {
        if (driver.currentLat != null && driver.currentLng != null) {
          markers.add(
            Marker(
              markerId: MarkerId('driver_${driver.id}'),
              position: LatLng(driver.currentLat!, driver.currentLng!),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueYellow,
              ),
              infoWindow: InfoWindow(
                title: driver.fullName,
                snippet: driver.vehicleDescription,
              ),
            ),
          );
        }
      }
    } catch (_) {}

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _selectDestination(LocationItem item) async {
    setState(() {
      _destination = item;
      _destinationSearchController.text = item.name;
      _mode = PassengerRideMode.tierSelection;
    });

    FocusScope.of(context).unfocus();
    await _recalculateRoute();
  }

  Future<void> _recalculateRoute() async {
    if (_destination == null) return;

    final locationService = ref.read(locationServiceProvider);
    final routeResult = await locationService.getRealRoute(
      startLat: _pickup.lat,
      startLng: _pickup.lng,
      endLat: _destination!.lat,
      endLng: _destination!.lng,
    );

    if (!mounted) return;

    setState(() {
      _calculatedDistanceKm = routeResult.distanceKm;
      _calculatedDurationMins = routeResult.durationMins;

      _polylines = {
        Polyline(
          polylineId: const PolylineId('ride_route'),
          points: routeResult.polylinePoints,
          color: TRYPColors.secondary,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });

    _updateMapMarkers();
    _animateMapBounds();
  }

  void _animateMapBounds() {
    if (_mapController == null || _destination == null) return;

    final swLat = _pickup.lat < _destination!.lat
        ? _pickup.lat
        : _destination!.lat;
    final swLng = _pickup.lng < _destination!.lng
        ? _pickup.lng
        : _destination!.lng;
    final neLat = _pickup.lat > _destination!.lat
        ? _pickup.lat
        : _destination!.lat;
    final neLng = _pickup.lng > _destination!.lng
        ? _pickup.lng
        : _destination!.lng;

    final bounds = LatLngBounds(
      southwest: LatLng(swLat - 0.01, swLng - 0.01),
      northeast: LatLng(neLat + 0.01, neLng + 0.01),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 70));
  }

  Future<void> _requestRide() async {
    if (_destination == null) return;

    final fare = FareCalculatorService.calculateFare(
      distanceKm: _calculatedDistanceKm,
      rideTypeId: _selectedRideType,
    );

    setState(() {
      _mode = PassengerRideMode.dispatching;
      _isLoading = true;
    });

    try {
      final tripService = ref.read(tripServiceProvider);
      final newTrip = await tripService.requestRide(
        origin: _pickup.name,
        destination: _destination!.name,
        fare: fare,
        rideType: _selectedRideType,
        paymentMethod: _paymentMethod,
        distanceKm: _calculatedDistanceKm,
        pickupLat: _pickup.lat,
        pickupLng: _pickup.lng,
        destLat: _destination!.lat,
        destLng: _destination!.lng,
      );

      ref.read(activeTripStateProvider.notifier).stateTrip = newTrip;
      _watchedRideId = newTrip.id;
      _startRideStatusRefreshTimer();

      // Add Notification
      ref
          .read(notificationsProvider.notifier)
          .addNotification(
            title: 'Ride Requested!',
            body:
                'Searching for nearby drivers to ${_destination!.name} (R${fare.toStringAsFixed(2)})',
            type: NotificationType.ride,
            routePath: Routes.passengerHome,
          );

      // Handle online payment state before continuing the ride flow.
      if (_paymentMethod != 'Cash') {
        final email =
            Supabase.instance.client.auth.currentUser?.email ??
            'passenger@tryp.app';
        final refCode = PaymentService.generateReference();
        final processingSaved = await tripService.setPaymentStatus(
          rideId: newTrip.id,
          status: 'processing',
          reference: refCode,
        );
        if (!processingSaved) {
          throw StateError('Could not initialize secure payment processing.');
        }

        if (mounted) {
          try {
            await PaymentService.chargeForRide(
              context: context,
              email: email,
              amountRands: fare,
              reference: refCode,
              metadata: {'ride_id': newTrip.id},
              onSuccess: () {
                // The client never marks an online payment as paid. A trusted
                // Paystack verification path must finalize it server-side.
                ref
                    .read(notificationsProvider.notifier)
                    .addNotification(
                      title: 'Payment Submitted',
                      body: 'Your payment is being verified securely.',
                      type: NotificationType.payment,
                      routePath: Routes.rideTracking,
                    );
              },
              onCancelled: () {
                unawaited(
                  _persistPaymentStatus(
                    rideId: newTrip.id,
                    status: 'cancelled',
                    reference: refCode,
                  ),
                );
              },
            );
          } catch (_) {
            await tripService.setPaymentStatus(
              rideId: newTrip.id,
              status: 'failed',
              reference: refCode,
            );
            rethrow;
          }
        }
      }

      // Subscribe to real-time trip status changes via Supabase WebSocket stream
      _rideSubscription = tripService.subscribeToRide(
        rideId: newTrip.id,
        onUpdate: (payload) async {
          if (!mounted) return;
          final updatedStatus = payload['status'] as String?;
          if (updatedStatus == 'accepted' ||
              updatedStatus == 'arrived' ||
              updatedStatus == 'in_trip') {
            final fullTrip = await tripService.getPassengerActiveTrip();
            if (fullTrip != null && mounted) {
              ref.read(activeTripStateProvider.notifier).stateTrip = fullTrip;
              setState(() {
                _mode = PassengerRideMode.activeTrip;
              });

              final driverName =
                  fullTrip.driverName ?? 'A verified TRYP driver';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$driverName accepted your ride request!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else if (updatedStatus == 'completed') {
            final completedTrip = await tripService.getTripById(newTrip.id);
            if (completedTrip != null && mounted) {
              _openCompletionScreen(completedTrip);
            }
          } else if (updatedStatus == 'cancelled') {
            ref.read(activeTripStateProvider.notifier).stateTrip = null;
            _rideSubscription?.unsubscribe();
            _rideSubscription = null;
            setState(() {
              _mode = PassengerRideMode.tierSelection;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Ride request was cancelled by driver or system.',
                ),
                backgroundColor: TRYPColors.error,
              ),
            );
          }
        },
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

  Future<void> _persistPaymentStatus({
    required String rideId,
    required String status,
    required String reference,
  }) async {
    final saved = await ref
        .read(tripServiceProvider)
        .setPaymentStatus(rideId: rideId, status: status, reference: reference);
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update the payment status.'),
          backgroundColor: TRYPColors.error,
        ),
      );
    }
  }

  void _onSearchQueryChanged(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() => _searchResults = saLandmarks);
      return;
    }

    final localMatches = saLandmarks.where((item) {
      return item.name.toLowerCase().contains(trimmed) ||
          item.address.toLowerCase().contains(trimmed) ||
          item.city.toLowerCase().contains(trimmed);
    }).toList();

    setState(() => _searchResults = localMatches);

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final locationService = ref.read(locationServiceProvider);
      final apiResults = await locationService.searchLocations(trimmed);
      if (!mounted) return;

      if (apiResults.isNotEmpty) {
        final apiItems = apiResults
            .map(
              (loc) => LocationItem(
                name: loc.shortName,
                address: loc.address,
                lat: loc.latitude,
                lng: loc.longitude,
                icon: Icons.place_rounded,
                city: 'Search Result',
              ),
            )
            .toList();

        setState(() {
          final existingNames = localMatches
              .map((e) => e.name.toLowerCase())
              .toSet();
          final uniqueApi = apiItems.where(
            (item) => !existingNames.contains(item.name.toLowerCase()),
          );
          _searchResults = [...localMatches, ...uniqueApi];
        });
      }
    });
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
                color: Colors.green,
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
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_pickup.lat, _pickup.lng),
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            style: _darkMapStyle,
            onMapCreated: (controller) {
              _mapController = controller;
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
                    _mapController!.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(_currentLocation!.lat, _currentLocation!.lng),
                        15,
                      ),
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
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomPanel()),

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
              'assets/images/tryp_icon.png',
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
                    color: Colors.green,
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

  Widget _buildBottomPanel() {
    switch (_mode) {
      case PassengerRideMode.tierSelection:
        return _buildTierSelectionSheet();
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
                        color: TRYPColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Where to?',
                        style: TRYPTypography.headingSmall.copyWith(
                          color: TRYPColors.secondary.withValues(alpha: 0.6),
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
          const SizedBox(height: 20),
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
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _pickupSearchController,
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
                    onTap: () {
                      if (_isSearchingPickup) {
                        setState(() {
                          _pickup = item;
                          _pickupSearchController.text = item.name;
                          _isSearchingPickup = false;
                        });
                      } else {
                        _selectDestination(item);
                      }
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
  Widget _buildTierSelectionSheet() {
    final dist = _calculatedDistanceKm;
    final duration = _calculatedDurationMins;

    final tiers = [
      {
        'id': 'TRYP Go',
        'name': 'TRYP Go',
        'desc': 'Affordable everyday hatchbacks',
        'icon': Icons.directions_car_rounded,
        'cap': 4,
        'eta': '3 min',
      },
      {
        'id': 'TRYP Comfort',
        'name': 'TRYP Comfort',
        'desc': 'Spacious sedans with top drivers',
        'icon': Icons.directions_car_rounded,
        'cap': 4,
        'eta': '2 min',
      },
      {
        'id': 'TRYP XL',
        'name': 'TRYP XL',
        'desc': 'SUVs & Minivans for groups',
        'icon': Icons.airport_shuttle_rounded,
        'cap': 6,
        'eta': '5 min',
      },
      {
        'id': 'TRYP Exec',
        'name': 'TRYP Exec',
        'desc': 'Premium luxury executive rides',
        'icon': Icons.workspace_premium_rounded,
        'cap': 4,
        'eta': '4 min',
      },
    ];

    final activeFare = FareCalculatorService.calculateFare(
      distanceKm: dist,
      rideTypeId: _selectedRideType,
    );

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
                      '${dist.toStringAsFixed(1)} km • ~$duration mins',
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

          // Tier Cards List
          ...tiers.map((tier) {
            final tierId = tier['id'] as String;
            final isSelected = _selectedRideType == tierId;
            final fareAmt = FareCalculatorService.calculateFare(
              distanceKm: dist,
              rideTypeId: tierId,
            );

            return GestureDetector(
              onTap: () => setState(() => _selectedRideType = tierId),
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
                      child: Icon(
                        tier['icon'] as IconData,
                        color: TRYPColors.white,
                        size: 24,
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
                      'R${fareAmt.toStringAsFixed(2)}',
                      style: TRYPTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

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
            label:
                'Request $_selectedRideType • R${activeFare.toStringAsFixed(2)}',
            isLoading: _isLoading,
            onPressed: _requestRide,
          ),
        ],
      ),
    );
  }

  // ── MODE D: Dispatching Radar Sheet ─────────────────────────────────
  Widget _buildDispatchingSheet() {
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
            'Connecting to nearby drivers...',
            style: TRYPTypography.headingSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Matching you with top-rated ${_selectedRideType} drivers near ${_pickup.name}',
            textAlign: TextAlign.center,
            style: TRYPTypography.bodySmall,
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
        ],
      ),
    );
  }
}
