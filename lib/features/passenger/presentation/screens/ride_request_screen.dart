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

/// Preset Location Item for Ride Planner
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

enum _SearchField { none, pickup, destination }

class RideRequestScreenPage extends ConsumerStatefulWidget {
  const RideRequestScreenPage({super.key});

  @override
  ConsumerState<RideRequestScreenPage> createState() => _RideRequestScreenPageState();
}

class _RideRequestScreenPageState extends ConsumerState<RideRequestScreenPage> {
  static const LocationItem currentPickupLocation = LocationItem(
    name: 'Sandton City Mall',
    address: '83 Rivonia Rd, Sandhurst, Sandton',
    lat: -26.1076,
    lng: 28.0567,
    icon: Icons.my_location_rounded,
    city: 'Sandton',
  );

  static const List<LocationItem> allSouthAfricanLandmarks = [
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
      address: ' Montecasino Blvd, Fourways, Sandton',
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
    LocationItem(
      name: 'Union Buildings',
      address: 'Government Ave, Pretoria Central',
      lat: -25.7402,
      lng: 28.2123,
      icon: Icons.account_balance_rounded,
      city: 'Pretoria',
    ),
    LocationItem(
      name: 'V&A Waterfront',
      address: '19 Dock Rd, Cape Town',
      lat: -33.9036,
      lng: 18.4205,
      icon: Icons.directions_boat_rounded,
      city: 'Cape Town',
    ),
    LocationItem(
      name: 'Table Mountain Aerial Cableway',
      address: 'Tafelberg Rd, Gardens, Cape Town',
      lat: -33.9481,
      lng: 18.4032,
      icon: Icons.landscape_rounded,
      city: 'Cape Town',
    ),
    LocationItem(
      name: 'Gateway Theatre of Shopping',
      address: '1 Palm Blvd, Umhlanga, Durban',
      lat: -29.7257,
      lng: 31.0664,
      icon: Icons.store_rounded,
      city: 'Durban',
    ),
    LocationItem(
      name: 'Gold Reef City Theme Park',
      address: 'Northern Pkwy & Data Cres, Ormonde, Johannesburg',
      lat: -26.2362,
      lng: 28.0129,
      icon: Icons.attractions_rounded,
      city: 'Johannesburg',
    ),
  ];

  LocationItem _pickup = const LocationItem(
    name: 'Getting location...',
    address: 'Detecting your location',
    lat: -26.1076,
    lng: 28.0567,
    icon: Icons.gps_fixed_rounded,
    city: '',
  );
  late LocationItem _destination;
  LocationItem? _currentLocation;
  final TextEditingController _pickupSearchController = TextEditingController();
  final TextEditingController _destinationSearchController = TextEditingController();
  final FocusNode _pickupFocusNode = FocusNode();
  final FocusNode _destinationFocusNode = FocusNode();
  _SearchField _activeSearchField = _SearchField.none;
  List<LocationItem> _searchResults = [];
  bool _isLoadingLocation = true;  // True while GPS resolves
  bool _useCurrentLocation = true;
  String _selectedRideType = 'Economy';
  String _paymentMethod = 'Cash';
  bool _isLoading = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _calculatedDistanceKm = 5.2;
  int _calculatedDurationMins = 10;
  Timer? _searchDebounceTimer;
  static const String _mapStyle = '''[
  {
    "featureType": "all",
    "elementType": "geometry",
    "stylers": [
      {"saturation": -30},
      {"lightness": -20}
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {"saturation": -20},
      {"lightness": 10}
    ]
  },
  {
    "featureType": "poi",
    "elementType": "labels",
    "stylers": [
      {"visibility": "simplified"}
    ]
  },
  {
    "featureType": "transit",
    "elementType": "all",
    "stylers": [
      {"visibility": "off"}
    ]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry",
    "stylers": [
      {"visibility": "off"}
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [
      {"color": "#2a3d4a"}
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {"color": "#1f2f3f"}
    ]
  }
]''';

  @override
  void initState() {
    super.initState();
    _destination = allSouthAfricanLandmarks.first;
    _destinationSearchController.text = _destination.name;
    _pickupSearchController.text = 'Detecting your location...';
    _searchResults = allSouthAfricanLandmarks;

    _pickupFocusNode.addListener(() {
      if (_pickupFocusNode.hasFocus) {
        setState(() {
          _activeSearchField = _SearchField.pickup;
          _searchResults = allSouthAfricanLandmarks;
        });
      }
    });

    _destinationFocusNode.addListener(() {
      if (_destinationFocusNode.hasFocus) {
        setState(() {
          _activeSearchField = _SearchField.destination;
          _searchResults = allSouthAfricanLandmarks;
        });
      }
    });
  }

  Future<void> _fetchUserLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final userLoc = await locationService.getUserLocationWithAddress();
      if (!mounted) return;

      final currentLocation = LocationItem(
        name: userLoc.shortName,
        address: userLoc.address,
        lat: userLoc.latitude,
        lng: userLoc.longitude,
        icon: Icons.gps_fixed_rounded,
        city: '',
      );

      setState(() {
        _currentLocation = currentLocation;
        if (_useCurrentLocation || _pickup.name == 'Getting location...' || _pickup.name == currentPickupLocation.name) {
          _pickup = currentLocation;
          _pickupSearchController.text = currentLocation.name;
          _useCurrentLocation = true;
        }
        _isLoadingLocation = false;
      });

      if (_useCurrentLocation) {
        _recalculateRouteAndFare();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _currentLocation = currentPickupLocation;
        if (_useCurrentLocation || _pickup.name == 'Getting location...' || _pickup.name == currentPickupLocation.name) {
          _pickup = currentPickupLocation;
          _pickupSearchController.text = currentPickupLocation.name;
          _useCurrentLocation = true;
        }
      });
      if (_useCurrentLocation) {
        _recalculateRouteAndFare();
      }
    }
  }

  @override
  void dispose() {
    _pickupSearchController.dispose();
    _destinationSearchController.dispose();
    _pickupFocusNode.dispose();
    _destinationFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchQueryChanged(String query) {
    final trimmed = query.trim();
    final field = _activeSearchField;
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = allSouthAfricanLandmarks;
      });
      return;
    }

    final lowercaseQuery = trimmed.toLowerCase();
    final localMatches = allSouthAfricanLandmarks.where((item) {
      return item.name.toLowerCase().contains(lowercaseQuery) ||
          item.address.toLowerCase().contains(lowercaseQuery) ||
          item.city.toLowerCase().contains(lowercaseQuery);
    }).toList();

    setState(() {
      _searchResults = localMatches;
    });

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final locationService = ref.read(locationServiceProvider);
      final apiResults = await locationService.searchLocations(trimmed);
      if (!mounted) return;

      final currentText = field == _SearchField.pickup ? _pickupSearchController.text.trim() : _destinationSearchController.text.trim();
      if (trimmed != currentText) return;

      if (apiResults.isNotEmpty) {
        final apiItems = apiResults.map((loc) => LocationItem(
          name: loc.shortName,
          address: loc.address,
          lat: loc.latitude,
          lng: loc.longitude,
          icon: Icons.place_rounded,
          city: 'Search result',
        )).toList();

        setState(() {
          final existingNames = localMatches.map((e) => e.name.toLowerCase()).toSet();
          final filteredApi = apiItems.where((item) => !existingNames.contains(item.name.toLowerCase()));
          _searchResults = [...localMatches, ...filteredApi];
        });
      }
    });
  }

  Future<void> _selectPickup(LocationItem item) async {
    setState(() {
      _pickup = item;
      _pickupSearchController.text = item.name;
      _useCurrentLocation = false;
      _activeSearchField = _SearchField.none;
    });
    FocusScope.of(context).unfocus();
    await _recalculateRouteAndFare();
  }

  Future<void> _selectDestination(LocationItem item) async {
    setState(() {
      _destination = item;
      _destinationSearchController.text = item.name;
      _activeSearchField = _SearchField.none;
    });
    FocusScope.of(context).unfocus();
    await _recalculateRouteAndFare();
  }

  Future<void> _restoreCurrentLocation() async {
    if (_currentLocation == null) {
      await _fetchUserLocation();
      return;
    }

    setState(() {
      _useCurrentLocation = true;
      _pickup = _currentLocation!;
      _pickupSearchController.text = _currentLocation!.name;
      _activeSearchField = _SearchField.none;
    });
    await _recalculateRouteAndFare();
  }

  Future<void> _confirmRide() async {
    final amount = FareCalculatorService.calculateFare(
      distanceKm: _calculatedDistanceKm,
      rideTypeId: _selectedRideType,
    );

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    setState(() => _isLoading = true);

    try {
      final tripService = ref.read(tripServiceProvider);
      final newTrip = await tripService.requestRide(
        origin: _pickup.name,
        destination: _destination.name,
        fare: amount,
        rideType: _selectedRideType,
        paymentMethod: _paymentMethod,
        distanceKm: _calculatedDistanceKm,
        pickupLat: _pickup.lat,
        pickupLng: _pickup.lng,
        destLat: _destination.lat,
        destLng: _destination.lng,
      );

      ref.read(activeTripStateProvider.notifier).stateTrip = newTrip;

      // Trigger Notification
      ref.read(notificationsProvider.notifier).addNotification(
        title: 'Ride Requested! 🚘',
        body: 'Your ride to ${_destination.name} (R${amount.toStringAsFixed(2)}) was requested. Searching for nearby drivers...',
        type: NotificationType.ride,
        routePath: Routes.rideTracking,
      );

      // Cash rides skip payment and go straight to tracking
      if (_paymentMethod == 'Cash') {
        if (!mounted) return;
        router.go(Routes.rideTracking);
        return;
      }

      // Online payment via Paystack
      final email = Supabase.instance.client.auth.currentUser?.email ?? 'passenger@tryp.app';
      final reference = PaymentService.generateReference();

      await PaymentService.chargeForRide(
        context: context,
        email: email,
        amountRands: amount,
        reference: reference,
        metadata: {
          'ride_id': newTrip.id,
          'ride_type': _selectedRideType,
          'payment_method': _paymentMethod,
          'pickup': _pickup.name,
          'destination': _destination.name,
          'distance_km': _calculatedDistanceKm.toStringAsFixed(1),
        },
        onSuccess: () {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Payment successful! Finding your driver...'),
              backgroundColor: Colors.green,
            ),
          );
          router.go(Routes.rideTracking);
        },
        onCancelled: () {
          messenger.showSnackBar(
            const SnackBar(content: Text('Payment cancelled.')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final String userMessage;
      if (raw.contains('without an authenticated user')) {
        userMessage = 'You must be logged in to request a ride.';
      } else if (raw.contains('permission') || raw.contains('RLS') || raw.contains('policy')) {
        userMessage = 'Permission denied. Please log out and log back in.';
      } else if (raw.contains('network') || raw.contains('SocketException')) {
        userMessage = 'No internet connection. Please check your network.';
      } else {
        userMessage = 'Could not create your ride. Please try again.';
      }
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(userMessage)),
            ],
          ),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setPickupFromMap(LatLng position) async {
    final messenger = ScaffoldMessenger.of(context);
    final locationService = ref.read(locationServiceProvider);
    final geocoded = await locationService.reverseGeocode(position.latitude, position.longitude);
    if (!mounted) return;

    final customPickup = LocationItem(
      name: geocoded.shortName,
      address: geocoded.address,
      lat: geocoded.latitude,
      lng: geocoded.longitude,
      icon: Icons.place_rounded,
      city: '',
    );

    setState(() {
      _pickup = customPickup;
      _pickupSearchController.text = customPickup.name;
      _useCurrentLocation = false;
      _activeSearchField = _SearchField.none;
    });

    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Pickup location updated from map.')),
    );

    await _recalculateRouteAndFare();
  }

  Future<void> _recalculateRouteAndFare() async {
    final locationService = ref.read(locationServiceProvider);
    final routeResult = await locationService.getRealRoute(
      startLat: _pickup.lat,
      startLng: _pickup.lng,
      endLat: _destination.lat,
      endLng: _destination.lng,
    );

    if (!mounted) return;

    final pickupLatLng = LatLng(_pickup.lat, _pickup.lng);
    final destLatLng = LatLng(_destination.lat, _destination.lng);

    setState(() {
      _calculatedDistanceKm = routeResult.distanceKm;
      _calculatedDurationMins = routeResult.durationMins;

      _markers = {
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: 'Pickup Location', snippet: _pickup.name),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: destLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'Destination', snippet: _destination.name),
        ),
      };

      _polylines = {
        Polyline(
          polylineId: const PolylineId('route_line'),
          points: routeResult.polylinePoints,
          color: TRYPColors.secondary,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    });

    if (_mapController != null) {
      _animateMapBounds();
    }
  }

  void _animateMapBounds() {
    if (_mapController == null) return;
    
    final southwestLat = _pickup.lat < _destination.lat ? _pickup.lat : _destination.lat;
    final southwestLng = _pickup.lng < _destination.lng ? _pickup.lng : _destination.lng;
    final northeastLat = _pickup.lat > _destination.lat ? _pickup.lat : _destination.lat;
    final northeastLng = _pickup.lng > _destination.lng ? _pickup.lng : _destination.lng;

    final bounds = LatLngBounds(
      southwest: LatLng(southwestLat - 0.01, southwestLng - 0.01),
      northeast: LatLng(northeastLat + 0.01, northeastLng + 0.01),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 60),
    );
  }

  void _showPaymentPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Payment Method', style: TRYPTypography.headingMedium),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.money_rounded, color: Colors.green, size: 28),
                title: const Text('Cash'),
                subtitle: const Text('Pay driver in cash upon arrival'),
                trailing: _paymentMethod == 'Cash' ? const Icon(Icons.check_circle_rounded, color: TRYPColors.primary) : null,
                onTap: () {
                  setState(() => _paymentMethod = 'Cash');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.credit_card_rounded, color: TRYPColors.secondary, size: 28),
                title: const Text('Paystack Card / Online'),
                subtitle: const Text('Visa, Mastercard, EFT'),
                trailing: _paymentMethod == 'Paystack Card' ? const Icon(Icons.check_circle_rounded, color: TRYPColors.primary) : null,
                onTap: () {
                  setState(() => _paymentMethod = 'Paystack Card');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded, color: Colors.purple, size: 28),
                title: const Text('TRYP Wallet'),
                subtitle: const Text('In-app wallet balance'),
                trailing: _paymentMethod == 'TRYP Wallet' ? const Icon(Icons.check_circle_rounded, color: TRYPColors.primary) : null,
                onTap: () {
                  setState(() => _paymentMethod = 'TRYP Wallet');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFare = FareCalculatorService.calculateFare(
      distanceKm: _calculatedDistanceKm,
      rideTypeId: _selectedRideType,
    );
    final estimatedMins = _calculatedDurationMins;

    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(Routes.passengerHome),
        ),
        title: Text(
          'Destination & Ride Planner',
          style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_pickup.lat, _pickup.lng),
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            style: _mapStyle,
            onMapCreated: (controller) {
              _mapController = controller;
              _animateMapBounds();
            },
            onLongPress: _setPickupFromMap,
          ),
          Container(color: Colors.black.withValues(alpha: 0.14)),
          SafeArea(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: TRYPColors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                              decoration: BoxDecoration(
                                color: TRYPColors.lightGrey,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TRYPColors.greyLight, width: 1),
                              ),
                              child: TextField(
                                controller: _pickupSearchController,
                                focusNode: _pickupFocusNode,
                                onTap: () {
                                  setState(() => _activeSearchField = _SearchField.pickup);
                                },
                                onChanged: (value) {
                                  if (_activeSearchField != _SearchField.pickup) {
                                    setState(() => _activeSearchField = _SearchField.pickup);
                                  }
                                  _onSearchQueryChanged(value);
                                },
                                decoration: InputDecoration(
                                  hintText: _isLoadingLocation ? 'Detecting current location...' : 'Pickup Location',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                  isDense: true,
                                  suffixIcon: _pickupSearchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18, color: TRYPColors.grey),
                                          onPressed: () {
                                            _pickupSearchController.clear();
                                            _onSearchQueryChanged('');
                                          },
                                        )
                                      : null,
                                ),
                                style: TRYPTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: TRYPColors.secondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: _restoreCurrentLocation,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: TRYPColors.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.gps_fixed_rounded, color: TRYPColors.secondary, size: 18),
                            ),
                          ),
                        ],
                      ),
                      if (!_useCurrentLocation && !_isLoadingLocation)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _restoreCurrentLocation,
                            icon: const Icon(Icons.my_location_rounded, size: 16),
                            label: const Text('Use current location'),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: TRYPColors.secondary,
                              shape: BoxShape.rectangle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                              decoration: BoxDecoration(
                                color: TRYPColors.lightGrey,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TRYPColors.primary, width: 1.2),
                              ),
                              child: TextField(
                                controller: _destinationSearchController,
                                focusNode: _destinationFocusNode,
                                onTap: () {
                                  setState(() => _activeSearchField = _SearchField.destination);
                                },
                                onChanged: (value) {
                                  if (_activeSearchField != _SearchField.destination) {
                                    setState(() => _activeSearchField = _SearchField.destination);
                                  }
                                  _onSearchQueryChanged(value);
                                },
                                decoration: InputDecoration(
                                  hintText: 'Destination',
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                                  isDense: true,
                                  suffixIcon: _destinationSearchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18, color: TRYPColors.grey),
                                          onPressed: () {
                                            _destinationSearchController.clear();
                                            _onSearchQueryChanged('');
                                          },
                                        )
                                      : null,
                                ),
                                style: TRYPTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: TRYPColors.secondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      if (_activeSearchField != _SearchField.none)
                        Positioned.fill(
                          child: Container(
                            margin: const EdgeInsets.only(top: 10),
                            decoration: BoxDecoration(
                              color: TRYPColors.white.withValues(alpha: 0.98),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _activeSearchField == _SearchField.pickup
                                              ? 'Search pickup location'
                                              : 'Search destination',
                                          style: TRYPTypography.headingSmall.copyWith(fontSize: 16),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _activeSearchField = _SearchField.none;
                                          });
                                          FocusScope.of(context).unfocus();
                                        },
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: _searchResults.isEmpty
                                      ? Center(
                                          child: Text(
                                            'No matches found. Try another address.',
                                            style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
                                          ),
                                        )
                                      : ListView.separated(
                                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                          itemCount: _searchResults.length,
                                          separatorBuilder: (context, index) => const Divider(height: 1),
                                          itemBuilder: (context, index) {
                                            final item = _searchResults[index];
                                            return ListTile(
                                              leading: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: TRYPColors.primary.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(item.icon, color: TRYPColors.secondary, size: 20),
                                              ),
                                              title: Text(item.name, style: TRYPTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
                                              subtitle: Text('${item.address}${item.city.isNotEmpty ? " · ${item.city}" : ""}', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
                                              onTap: () {
                                                if (_activeSearchField == _SearchField.pickup) {
                                                  _selectPickup(item);
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
                        ),
                      Positioned(
                        top: 18,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: TRYPColors.secondary.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.route_rounded, color: TRYPColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${_calculatedDistanceKm.toStringAsFixed(1)} km • approx $estimatedMins mins',
                                style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.white, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_activeSearchField == _SearchField.none)
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: TRYPColors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 14,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.touch_app_rounded, size: 18, color: TRYPColors.secondary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Long press anywhere on the map to drop a custom pickup pin.',
                                    style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.secondary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
                  decoration: BoxDecoration(
                    color: TRYPColors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          _VehicleTierTile(
                            title: 'TRYP Go',
                            subtitle: 'Everyday',
                            price: FareCalculatorService.calculateFare(distanceKm: _calculatedDistanceKm, rideTypeId: 'Economy'),
                            isSelected: _selectedRideType == 'Economy',
                            icon: Icons.directions_car_rounded,
                            onTap: () => setState(() => _selectedRideType = 'Economy'),
                          ),
                          const SizedBox(width: 8),
                          _VehicleTierTile(
                            title: 'Comfort',
                            subtitle: 'Newer Cars',
                            price: FareCalculatorService.calculateFare(distanceKm: _calculatedDistanceKm, rideTypeId: 'Comfort'),
                            isSelected: _selectedRideType == 'Comfort',
                            icon: Icons.airline_seat_recline_extra_rounded,
                            onTap: () => setState(() => _selectedRideType = 'Comfort'),
                          ),
                          const SizedBox(width: 8),
                          _VehicleTierTile(
                            title: 'TRYP XL',
                            subtitle: '6 Seats',
                            price: FareCalculatorService.calculateFare(distanceKm: _calculatedDistanceKm, rideTypeId: 'XL'),
                            isSelected: _selectedRideType == 'XL',
                            icon: Icons.airport_shuttle_rounded,
                            onTap: () => setState(() => _selectedRideType = 'XL'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _showPaymentPicker,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: TRYPColors.lightGrey,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _paymentMethod == 'Cash'
                                    ? Icons.money_rounded
                                    : (_paymentMethod == 'Paystack Card' ? Icons.credit_card_rounded : Icons.account_balance_wallet_rounded),
                                color: _paymentMethod == 'Cash' ? Colors.green : (_paymentMethod == 'Paystack Card' ? TRYPColors.secondary : Colors.purple),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _paymentMethod,
                                style: TRYPTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              const Icon(Icons.keyboard_arrow_right_rounded, color: TRYPColors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Confirm Ride • R${activeFare.toStringAsFixed(2)}',
                        onPressed: _confirmRide,
                        isLoading: _isLoading,
                        enabled: _pickup.name != 'Getting location...' && _destination.name.isNotEmpty,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TRYPBottomNavBar(currentIndex: 1),
          ),
        ],
      ),
    );
  }
}

class _VehicleTierTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double price;
  final bool isSelected;
  final IconData icon;
  final VoidCallback onTap;

  const _VehicleTierTile({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.isSelected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? TRYPColors.primary.withValues(alpha: 0.15) : TRYPColors.lightGrey,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? TRYPColors.secondary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? TRYPColors.secondary : TRYPColors.grey, size: 24),
              const SizedBox(height: 4),
              Text(
                title,
                style: TRYPTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: TRYPColors.secondary,
                ),
              ),
              Text(
                'R${price.toStringAsFixed(2)}',
                style: TRYPTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? TRYPColors.secondary : TRYPColors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
