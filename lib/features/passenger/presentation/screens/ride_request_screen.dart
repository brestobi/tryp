import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/fare_calculator.dart';
import 'package:tryp/core/services/payment_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

/// Preset Location Item for Ride Planner
class LocationItem {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final IconData icon;

  const LocationItem({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.icon = Icons.location_on_rounded,
  });
}

class RideRequestScreenPage extends StatefulWidget {
  const RideRequestScreenPage({Key? key}) : super(key: key);

  @override
  State<RideRequestScreenPage> createState() => _RideRequestScreenPageState();
}

class _RideRequestScreenPageState extends State<RideRequestScreenPage> {
  // Available Destinations schema list
  static const LocationItem currentPickupLocation = LocationItem(
    name: 'Current Location',
    address: 'Sandton City, Sandton',
    lat: -26.1076,
    lng: 28.0567,
    icon: Icons.my_location_rounded,
  );

  static const List<LocationItem> popularDestinations = [
    LocationItem(
      name: 'Rosebank Mall',
      address: 'Bath Ave, Rosebank, Johannesburg',
      lat: -26.1464,
      lng: 28.0436,
      icon: Icons.shopping_bag_outlined,
    ),
    LocationItem(
      name: 'O.R. Tambo International Airport',
      address: 'Kempton Park, Johannesburg',
      lat: -26.1367,
      lng: 28.2411,
      icon: Icons.flight_takeoff_rounded,
    ),
    LocationItem(
      name: 'Mall of Africa',
      address: 'Lone Creek Cres, Midrand',
      lat: -26.0152,
      lng: 28.1070,
      icon: Icons.storefront_rounded,
    ),
    LocationItem(
      name: 'Johannesburg Park Station',
      address: 'Rissik St, Braamfontein, Johannesburg',
      lat: -26.1969,
      lng: 28.0416,
      icon: Icons.train_rounded,
    ),
    LocationItem(
      name: 'Vilakazi Street, Soweto',
      address: 'Vilakazi St, Orlando West, Soweto',
      lat: -26.2367,
      lng: 27.9069,
      icon: Icons.restaurant_rounded,
    ),
  ];

  late LocationItem _pickup;
  late LocationItem _destination;
  final TextEditingController _destinationSearchController = TextEditingController();
  
  String _selectedRideType = 'Economy';
  String _paymentMethod = 'Cash';
  bool _isLoading = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double _calculatedDistanceKm = 5.2;

  @override
  void initState() {
    super.initState();
    _pickup = currentPickupLocation;
    _destination = popularDestinations.first;
    _destinationSearchController.text = _destination.name;
    _recalculateRouteAndFare();
  }

  @override
  void dispose() {
    _destinationSearchController.dispose();
    super.dispose();
  }

  void _recalculateRouteAndFare() {
    // Dynamic distance calculation using Geolocator coordinates
    final distance = FareCalculatorService.calculateDistanceKm(
      startLat: _pickup.lat,
      startLng: _pickup.lng,
      endLat: _destination.lat,
      endLng: _destination.lng,
    );

    setState(() {
      _calculatedDistanceKm = distance;
      _updateMapMarkersAndPolyline();
    });

    if (_mapController != null) {
      _animateMapBounds();
    }
  }

  void _updateMapMarkersAndPolyline() {
    final pickupLatLng = LatLng(_pickup.lat, _pickup.lng);
    final destLatLng = LatLng(_destination.lat, _destination.lng);

    _markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickupLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Pickup', snippet: _pickup.address),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Destination', snippet: _destination.address),
      ),
    };

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [pickupLatLng, destLatLng],
        color: TRYPColors.primary,
        width: 4,
        patterns: [PatternItem.dash(12), PatternItem.gap(6)],
      ),
    };
  }

  void _animateMapBounds() {
    if (_mapController == null) return;
    
    final southwestLat = _pickup.lat < _destination.lat ? _pickup.lat : _destination.lat;
    final southwestLng = _pickup.lng < _destination.lng ? _pickup.lng : _destination.lng;
    final northeastLat = _pickup.lat > _destination.lat ? _pickup.lat : _destination.lat;
    final northeastLng = _pickup.lng > _destination.lng ? _pickup.lng : _destination.lng;

    final bounds = LatLngBounds(
      southwest: LatLng(southwestLat, southwestLng),
      northeast: LatLng(northeastLat, northeastLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 70),
    );
  }

  void _selectDestination(LocationItem item) {
    setState(() {
      _destination = item;
      _destinationSearchController.text = item.name;
    });
    _recalculateRouteAndFare();
  }

  Future<void> _confirmRide() async {
    final amount = FareCalculatorService.calculateFare(
      distanceKm: _calculatedDistanceKm,
      rideTypeId: _selectedRideType,
    );

    // Cash rides skip payment and go straight to tracking
    if (_paymentMethod == 'Cash') {
      if (!mounted) return;
      context.go(Routes.rideTracking);
      return;
    }

    // Online payment via Paystack
    setState(() => _isLoading = true);
    try {
      final email = Supabase.instance.client.auth.currentUser?.email ?? 'passenger@tryp.app';
      final reference = PaymentService.generateReference();

      await PaymentService.chargeForRide(
        context: context,
        email: email,
        amountRands: amount,
        reference: reference,
        metadata: {
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
        SnackBar(content: Text('Payment error: $e')),
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
              Text('Select Payment Method', style: TRYPTypography.headingSmall),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.money_rounded, color: TRYPColors.primary),
                title: const Text('Cash'),
                subtitle: const Text('Pay driver in cash upon completion'),
                trailing: _paymentMethod == 'Cash' ? const Icon(Icons.check_circle_rounded, color: TRYPColors.primary) : null,
                onTap: () {
                  setState(() => _paymentMethod = 'Cash');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.credit_card_rounded, color: TRYPColors.primary),
                title: const Text('Paystack (Card / EFT)'),
                subtitle: const Text('Secure instant online payment'),
                trailing: _paymentMethod == 'Card' ? const Icon(Icons.check_circle_rounded, color: TRYPColors.primary) : null,
                onTap: () {
                  setState(() => _paymentMethod = 'Card');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded, color: TRYPColors.primary),
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
    final estimatedMins = FareCalculatorService.estimateDurationMinutes(_calculatedDistanceKm);

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
          // Top Search & Location Inputs Container (Uber Style)
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: TRYPColors.lightGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _pickup.name,
                              style: TRYPTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: TRYPColors.secondary,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.my_location_rounded, size: 18, color: TRYPColors.grey),
                          ],
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

                // Destination Input
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
                          decoration: const InputDecoration(
                            hintText: 'Where to?',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                            isDense: true,
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

                const SizedBox(height: 12),

                // Popular Destination Suggestion Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: popularDestinations.map((dest) {
                      final isSelected = _destination.name == dest.name;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          avatar: Icon(
                            dest.icon,
                            size: 16,
                            color: isSelected ? TRYPColors.secondary : TRYPColors.grey,
                          ),
                          label: Text(dest.name),
                          selected: isSelected,
                          selectedColor: TRYPColors.primary,
                          backgroundColor: TRYPColors.lightGrey,
                          labelStyle: TRYPTypography.bodySmall.copyWith(
                            color: isSelected ? TRYPColors.secondary : TRYPColors.darkGrey,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (_) => _selectDestination(dest),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Main Map & Options Scroll Area
          Expanded(
            child: Stack(
              children: [
                // Google Map Route View
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(_pickup.lat, _pickup.lng),
                    zoom: 13,
                  ),
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _animateMapBounds();
                  },
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),

                // Fare Pricing Formula Info Banner
                Positioned(
                  top: 14,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: TRYPColors.secondary.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calculate_outlined, color: TRYPColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Rate: Base R15 + R5/km',
                              style: TRYPTypography.bodySmall.copyWith(
                                color: TRYPColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: TRYPColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_calculatedDistanceKm.toStringAsFixed(1)} km (~$estimatedMins min)',
                            style: TRYPTypography.labelMedium.copyWith(
                              color: TRYPColors.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Ride Options Sheet
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            decoration: BoxDecoration(
              color: TRYPColors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available TRYP Options',
                    style: TRYPTypography.headingSmall.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  // Ride Options List
                  Column(
                    children: FareCalculatorService.availableRideTypes.map((option) {
                      final isSelected = _selectedRideType == option.id;
                      final fare = FareCalculatorService.calculateFare(
                        distanceKm: _calculatedDistanceKm,
                        rideTypeId: option.id,
                      );

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedRideType = option.id);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? TRYPColors.primary.withValues(alpha: 0.15)
                                : TRYPColors.lightGrey,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? TRYPColors.primary : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected ? TRYPColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  option.icon,
                                  color: TRYPColors.secondary,
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
                                          option.name,
                                          style: TRYPTypography.bodyLarge.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(Icons.person, size: 14, color: TRYPColors.grey),
                                        Text(
                                          '${option.capacity}',
                                          style: TRYPTypography.bodySmall,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      option.description,
                                      style: TRYPTypography.bodySmall.copyWith(
                                        color: TRYPColors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'R${fare.toStringAsFixed(2)}',
                                style: TRYPTypography.headingSmall.copyWith(
                                  fontSize: 16,
                                  color: TRYPColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 10),

                  // Payment Selector Row
                  GestureDetector(
                    onTap: _showPaymentPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: TRYPColors.lightGrey,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _paymentMethod == 'Cash'
                                ? Icons.money_rounded
                                : Icons.credit_card_rounded,
                            color: TRYPColors.secondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _paymentMethod,
                            style: TRYPTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Change',
                            style: TRYPTypography.bodySmall,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: TRYPColors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // CTA Button
                  PrimaryButton(
                    label: _paymentMethod == 'Cash'
                        ? 'Confirm $_selectedRideType • R${activeFare.toStringAsFixed(2)}'
                        : 'Paystack Pay • R${activeFare.toStringAsFixed(2)}',
                    onPressed: _confirmRide,
                    isLoading: _isLoading,
                    enabled: !_isLoading,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
