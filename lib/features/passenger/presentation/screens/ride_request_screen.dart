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

class RideRequestScreenPage extends ConsumerStatefulWidget {
  const RideRequestScreenPage({Key? key}) : super(key: key);

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
  final TextEditingController _destinationSearchController = TextEditingController();
  
  List<LocationItem> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingLocation = true;  // True while GPS resolves
  String _selectedRideType = 'Economy';
  String _paymentMethod = 'Cash';
  bool _isLoading = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _calculatedDistanceKm = 5.2;
  int _calculatedDurationMins = 10;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _destination = allSouthAfricanLandmarks.first;
    _destinationSearchController.text = _destination.name;
    _searchResults = allSouthAfricanLandmarks;
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final userLoc = await locationService.getUserLocationWithAddress();
      if (!mounted) return;
      setState(() {
        _pickup = LocationItem(
          name: userLoc.shortName,
          address: userLoc.address,
          lat: userLoc.latitude,
          lng: userLoc.longitude,
          icon: Icons.gps_fixed_rounded,
          city: '',
        );
        _isLoadingLocation = false;
      });
      _recalculateRouteAndFare();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
        _pickup = currentPickupLocation;
      });
      _recalculateRouteAndFare();
    }
  }

  @override
  void dispose() {
    _destinationSearchController.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchQueryChanged(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = allSouthAfricanLandmarks;
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    final localMatches = allSouthAfricanLandmarks.where((item) {
      return item.name.toLowerCase().contains(lowercaseQuery) ||
          item.address.toLowerCase().contains(lowercaseQuery) ||
          item.city.toLowerCase().contains(lowercaseQuery);
    }).toList();

    setState(() {
      _isSearching = true;
      _searchResults = localMatches;
    });

    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final locationService = ref.read(locationServiceProvider);
      final apiResults = await locationService.searchLocations(query);
      if (!mounted || query != _destinationSearchController.text) return;

      if (apiResults.isNotEmpty) {
        final apiItems = apiResults.map((loc) => LocationItem(
          name: loc.shortName,
          address: loc.address,
          lat: loc.latitude,
          lng: loc.longitude,
          icon: Icons.place_rounded,
          city: 'Real World Search',
        )).toList();

        setState(() {
          final existingNames = localMatches.map((e) => e.name.toLowerCase()).toSet();
          final filteredApi = apiItems.where((item) => !existingNames.contains(item.name.toLowerCase()));
          _searchResults = [...localMatches, ...filteredApi];
        });
      }
    });
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

  void _selectDestination(LocationItem item) {
    setState(() {
      _destination = item;
      _destinationSearchController.text = item.name;
      _isSearching = false;
    });
    FocusScope.of(context).unfocus();
    _recalculateRouteAndFare();
  }

  Future<void> _confirmRide() async {
    final amount = FareCalculatorService.calculateFare(
      distanceKm: _calculatedDistanceKm,
      rideTypeId: _selectedRideType,
    );

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
        context.go(Routes.rideTracking);
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
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment successful! Finding your driver...'),
              backgroundColor: Colors.green,
            ),
          );
          context.go(Routes.rideTracking);
        },
        onCancelled: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment cancelled.')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating ride: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      body: Column(
        children: [
          // Top Search & Location Inputs Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: TRYPColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pickup Input
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: _isLoadingLocation ? null : _fetchUserLocation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: TRYPColors.lightGrey,
                            borderRadius: BorderRadius.circular(12),
                            border: _isLoadingLocation
                                ? Border.all(color: TRYPColors.primary.withValues(alpha: 0.5), width: 1)
                                : null,
                          ),
                          child: Row(
                            children: [
                              if (_isLoadingLocation) ...[
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: TRYPColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Detecting your location...',
                                  style: TRYPTypography.bodyMedium.copyWith(
                                    color: TRYPColors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ] else ...[
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _pickup.name,
                                        style: TRYPTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: TRYPColors.secondary,
                                        ),
                                         maxLines: 1,
                                         overflow: TextOverflow.ellipsis,
                                       ),
                                      if (_pickup.address.isNotEmpty && _pickup.address != _pickup.name)
                                        Text(
                                          _pickup.address,
                                          style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _fetchUserLocation,
                                  child: const Icon(Icons.gps_fixed_rounded, size: 18, color: TRYPColors.primary),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Connecting line
                Container(
                  margin: const EdgeInsets.only(left: 5, top: 4, bottom: 4),
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 2,
                    height: 16,
                    color: TRYPColors.grey.withValues(alpha: 0.4),
                  ),
                ),

                // Destination Input with Live Autocomplete Search
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: TRYPColors.secondary,
                        shape: BoxShape.rectangle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: TRYPColors.lightGrey,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: TRYPColors.primary, width: 1.5),
                        ),
                        child: TextField(
                          controller: _destinationSearchController,
                          onChanged: _onSearchQueryChanged,
                          decoration: InputDecoration(
                            hintText: 'Search landmark or address...',
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
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

          // LIVE AUTOCOMPLETE SUGGESTION LIST OVERLAY
          if (_isSearching || _destinationSearchController.text.isEmpty)
            Expanded(
              child: Container(
                color: TRYPColors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Text(
                        'Nearby South African Landmarks & Locations',
                        style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            subtitle: Text('${item.address} • ${item.city}', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
                            onTap: () => _selectDestination(item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // MAP PREVIEW WITH LIVE ROUTE POLYLINE LINE
            Expanded(
              child: Stack(
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
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _animateMapBounds();
                    },
                  ),

                  // Distance & Duration Floating Pill
                  Positioned(
                    top: 14,
                    left: 20,
                    right: 20,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: TRYPColors.secondary,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
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
                  ),
                ],
              ),
            ),

            // RIDE OPTIONS & CONFIRMATION SHEET
            Container(
              padding: const EdgeInsets.all(20),
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
                  // Vehicle Tier Selector
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

                  // Payment Method Bar
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

                  // Confirm Button
                  PrimaryButton(
                    label: 'Confirm Ride • R${activeFare.toStringAsFixed(2)}',
                    onPressed: _confirmRide,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            ),
          ],
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
