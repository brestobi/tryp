import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/location_service.dart';
import 'package:tryp/core/services/notification_service.dart';
import 'package:tryp/core/services/trip_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class TripTrackingScreenPage extends ConsumerStatefulWidget {
  const TripTrackingScreenPage({Key? key}) : super(key: key);

  @override
  ConsumerState<TripTrackingScreenPage> createState() => _TripTrackingScreenPageState();
}

class _TripTrackingScreenPageState extends ConsumerState<TripTrackingScreenPage> {
  TripModel? _currentTrip;
  RealtimeChannel? _rideSubscription;
  bool _isLoading = true;

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadAndSubscribeToActiveRide();
  }

  @override
  void dispose() {
    _rideSubscription?.unsubscribe();
    super.dispose();
  }

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

    _subscribeToRideUpdates(trip.id);
    _updateMapMarkersAndRoute(trip);
  }

  void _subscribeToRideUpdates(String rideId) {
    _rideSubscription?.unsubscribe();
    final tripService = ref.read(tripServiceProvider);

    _rideSubscription = tripService.subscribeToRide(
      rideId: rideId,
      onUpdate: (payload) async {
        if (!mounted) return;

        final fullTrip = await tripService.getPassengerActiveTrip();
        if (fullTrip != null && mounted) {
          final previousStatus = _currentTrip?.status;
          setState(() {
            _currentTrip = fullTrip;
          });
          ref.read(activeTripStateProvider.notifier).stateTrip = fullTrip;
          _updateMapMarkersAndRoute(fullTrip);

          if (previousStatus != fullTrip.status) {
            _handleStatusChangeNotifications(fullTrip);
          }
        }
      },
    );
  }

  void _handleStatusChangeNotifications(TripModel trip) {
    final driverName = trip.driverName ?? 'Your driver';
    switch (trip.status) {
      case TripStatus.accepted:
        ref.read(notificationsProvider.notifier).addNotification(
          title: 'Driver Assigned! 🚙',
          body: '$driverName accepted your ride request and is en route to pickup.',
          type: NotificationType.ride,
          routePath: Routes.rideTracking,
        );
        break;
      case TripStatus.arrived:
        ref.read(notificationsProvider.notifier).addNotification(
          title: 'Driver Arrived! 📌',
          body: '$driverName has arrived outside your pickup location.',
          type: NotificationType.ride,
          routePath: Routes.rideTracking,
        );
        break;
      case TripStatus.inTrip:
        ref.read(notificationsProvider.notifier).addNotification(
          title: 'Trip Started! 🟢',
          body: 'Your ride to ${trip.destination} is in progress.',
          type: NotificationType.ride,
          routePath: Routes.rideTracking,
        );
        break;
      case TripStatus.completed:
        ref.read(notificationsProvider.notifier).addNotification(
          title: 'Trip Completed! 🏁',
          body: 'You have arrived at ${trip.destination}. Thank you for riding with TRYP!',
          type: NotificationType.ride,
          routePath: Routes.passengerActivity,
        );
        _showRatingModal();
        break;
      case TripStatus.cancelled:
        ref.read(notificationsProvider.notifier).addNotification(
          title: 'Ride Cancelled ⚠️',
          body: 'Your ride request was cancelled.',
          type: NotificationType.system,
        );
        break;
      default:
        break;
    }
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
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
          infoWindow: InfoWindow(title: trip.driverName ?? 'Driver', snippet: trip.vehicleDescription),
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
      await tripService.updateTripStatus(
        rideId: _currentTrip!.id,
        status: TripStatus.cancelled,
      );
      ref.read(activeTripStateProvider.notifier).stateTrip = null;
      if (!mounted) return;
      context.go(Routes.passengerHome);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel ride: $e'), backgroundColor: TRYPColors.error),
      );
    }
  }

  void _showRatingModal() {
    int rating = 5;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                const SizedBox(height: 12),
                Text('You have arrived!', style: TRYPTypography.headingMedium),
                const SizedBox(height: 4),
                Text('How was your trip with your TRYP driver?', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      icon: Icon(
                        starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber,
                        size: 36,
                      ),
                      onPressed: () => setModalState(() => rating = starIndex),
                    );
                  }),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Submit Rating & Back Home',
                  onPressed: () {
                    ref.read(activeTripStateProvider.notifier).stateTrip = null;
                    Navigator.pop(context);
                    context.go(Routes.passengerHome);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _makeCall(String phone) {
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver phone number not available')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Calling driver: $phone')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: TRYPColors.primary,
        body: Center(child: CircularProgressIndicator(color: TRYPColors.accent)),
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
              const Icon(Icons.directions_car_rounded, size: 48, color: TRYPColors.accent),
              const SizedBox(height: 12),
              Text('No active trip to track', style: TRYPTypography.headingSmall.copyWith(color: TRYPColors.white)),
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
        statusSubtitle = 'We are notifying active, verified drivers near your pickup.';
        break;
      case TripStatus.accepted:
        headerTitle = 'Driver En Route';
        statusSubtitle = '${trip.driverName ?? "Your driver"} is heading to pickup location.';
        break;
      case TripStatus.arrived:
        headerTitle = 'Driver Has Arrived!';
        statusSubtitle = 'Your driver is waiting outside. Share PIN code to start.';
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
            Text(headerTitle, style: TRYPTypography.headingSmall.copyWith(fontSize: 16, color: TRYPColors.white)),
            Text(statusSubtitle, style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.muted, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sos_rounded, color: Colors.red),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('EMERGENCY SOS: Contacting TRYP 24/7 Safety Center...'),
                  backgroundColor: Colors.red,
                ),
              );
            },
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -6)),
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
                      style: TRYPTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: TRYPColors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drivers in your area have received your request',
                      style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.muted),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: _cancelRide,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TRYPColors.accent,
                        side: const BorderSide(color: TRYPColors.accent, width: 1.4),
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel Ride Request'),
                    ),
                  ] else ...[
                    // Assigned Driver Card
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: TRYPColors.accent,
                          backgroundImage: (trip.driverAvatar != null && trip.driverAvatar!.isNotEmpty)
                              ? NetworkImage(trip.driverAvatar!)
                              : null,
                          child: (trip.driverAvatar == null || trip.driverAvatar!.isEmpty)
                              ? const Icon(Icons.person_rounded, color: TRYPColors.primary, size: 28)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.driverName ?? 'Assigned TRYP Driver',
                                style: TRYPTypography.headingSmall.copyWith(fontSize: 17, color: TRYPColors.white),
                              ),
                              Text(
                                trip.vehicleDescription,
                                style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.muted, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _makeCall(trip.driverPhone ?? ''),
                          icon: const Icon(Icons.phone_rounded, color: TRYPColors.accent, size: 28),
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
                                Text('YOUR SAFETY PIN', style: TRYPTypography.labelSmall.copyWith(fontWeight: FontWeight.bold, color: TRYPColors.primary)),
                                Text('Give this 4-digit PIN to your driver to start ride', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.primary, fontSize: 11)),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: TRYPColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                trip.pinCode,
                                style: TRYPTypography.headingMedium.copyWith(color: TRYPColors.white, letterSpacing: 4, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Fare (${trip.paymentMethod}):', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.muted)),
                        Text('R${trip.fare.toStringAsFixed(2)}', style: TRYPTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: TRYPColors.accent)),
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
