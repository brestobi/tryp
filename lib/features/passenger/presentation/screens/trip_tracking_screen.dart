import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/notification_service.dart';
import 'package:tryp/core/services/trip_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class TripTrackingScreenPage extends ConsumerStatefulWidget {
  const TripTrackingScreenPage({Key? key}) : super(key: key);

  @override
  ConsumerState<TripTrackingScreenPage> createState() => _TripTrackingScreenPageState();
}

class _TripTrackingScreenPageState extends ConsumerState<TripTrackingScreenPage> {
  int _simulationStep = 0; // 0: Searching, 1: Driver Accepted, 2: Driver Arrived, 3: In Trip, 4: Completed, 5: No Driver Available
  int _searchCountdown = 15;
  Timer? _searchTimer;
  bool _noDriversAvailable = false;

  @override
  void initState() {
    super.initState();
    _startSearchCountdown();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  void _startSearchCountdown() {
    setState(() {
      _simulationStep = 0;
      _searchCountdown = 15;
      _noDriversAvailable = false;
    });

    _searchTimer?.cancel();
    _searchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_searchCountdown > 1) {
        setState(() => _searchCountdown--);

        // Simulate driver acceptance at countdown 10 (normal flow)
        if (_searchCountdown == 10 && !_noDriversAvailable) {
          _searchTimer?.cancel();
          setState(() => _simulationStep = 1);

          _syncTripStatus(TripStatus.accepted);
          ref.read(notificationsProvider.notifier).addNotification(
            title: 'Driver Matched! 🚙',
            body: 'A driver accepted your ride request and is heading to your pickup location.',
            type: NotificationType.ride,
            routePath: Routes.rideTracking,
          );

          _startDriverApproach();
        }
      } else {
        // Countdown reached 0 with no driver available!
        _searchTimer?.cancel();
        setState(() {
          _noDriversAvailable = true;
          _simulationStep = 5;
        });

        ref.read(notificationsProvider.notifier).addNotification(
          title: 'No Drivers Found ⚠️',
          body: 'No nearby drivers were available for your request. Please try again.',
          type: NotificationType.system,
        );
      }
    });
  }

  void _syncTripStatus(TripStatus status) {
    final activeTrip = ref.read(activeTripStateProvider);
    if (activeTrip != null) {
      ref.read(tripServiceProvider).updateTripStatus(
        rideId: activeTrip.id,
        status: status,
      );
    }
  }

  void _triggerNoDriverScenario() {
    _searchTimer?.cancel();
    setState(() {
      _noDriversAvailable = true;
      _simulationStep = 5;
    });

    ref.read(notificationsProvider.notifier).addNotification(
      title: 'No Drivers Available ⚠️',
      body: 'No drivers found nearby. Please try booking again.',
      type: NotificationType.system,
    );
  }

  void _startDriverApproach() {
    // Step 2: Arrived after 6 seconds
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _simulationStep == 1) {
        setState(() => _simulationStep = 2);

        _syncTripStatus(TripStatus.arrived);
        ref.read(notificationsProvider.notifier).addNotification(
          title: 'Driver Arrived! 📌',
          body: 'Your driver has arrived at the pickup location. Please meet your driver.',
          type: NotificationType.ride,
          routePath: Routes.rideTracking,
        );
      }
    });
  }

  void _startTripWithPin() {
    setState(() => _simulationStep = 3);

    _syncTripStatus(TripStatus.inTrip);
    ref.read(notificationsProvider.notifier).addNotification(
      title: 'Trip Started! 🟢',
      body: 'Your trip is now in progress. Sit back and enjoy your ride with TRYP!',
      type: NotificationType.ride,
      routePath: Routes.rideTracking,
    );
  }

  void _completeRide() {
    setState(() => _simulationStep = 4);

    _syncTripStatus(TripStatus.completed);
    ref.read(notificationsProvider.notifier).addNotification(
      title: 'Trip Completed! 🏁',
      body: 'You have arrived at your destination. Thank you for riding with TRYP!',
      type: NotificationType.ride,
      routePath: Routes.passengerActivity,
    );

    _showRatingModal();
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
                Text('How was your trip with your driver?', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
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

  @override
  Widget build(BuildContext context) {
    final activeTrip = ref.watch(activeTripStateProvider);
    final pinCode = activeTrip?.pinCode ?? '4829';
    final fareAmount = activeTrip?.fare ?? 82.50;

    String headerTitle;
    switch (_simulationStep) {
      case 0:
        headerTitle = 'Searching for Drivers ($_searchCountdown s)';
        break;
      case 1:
        headerTitle = 'Driver En Route (3 min)';
        break;
      case 2:
        headerTitle = 'Driver Waiting Outside!';
        break;
      case 3:
        headerTitle = 'On Trip to Destination';
        break;
      case 5:
        headerTitle = 'No Drivers Available';
        break;
      case 4:
      default:
        headerTitle = 'Trip Completed';
        break;
    }

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
        title: Text(headerTitle, style: TRYPTypography.headingSmall.copyWith(fontSize: 18)),
        actions: [
          if (_simulationStep != 5)
            IconButton(
              icon: const Icon(Icons.sos_rounded, color: Colors.red),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('EMERGENCY SOS: Contacting 24/7 Safety & Dispatch...'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
              tooltip: 'Emergency SOS',
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Google Map View
            Expanded(
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(-26.2041, 28.0473),
                  zoom: 14.5,
                ),
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                markers: (_simulationStep > 0 && _simulationStep != 5)
                    ? {
                        const Marker(
                          markerId: MarkerId('driver'),
                          position: LatLng(-26.2025, 28.0450),
                          infoWindow: InfoWindow(title: 'Driver (Toyota Corolla)'),
                        ),
                      }
                    : {},
              ),
            ),

            // Live Tracking / No Driver Panel
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: TRYPColors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                  // STATE 5: NO DRIVERS AVAILABLE ALERT
                  if (_simulationStep == 5) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.car_crash_rounded, color: Colors.orange, size: 42),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Drivers Available Nearby',
                      style: TRYPTypography.headingMedium.copyWith(fontSize: 20),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All TRYP drivers in your area are currently busy on other rides or offline. Please try again in a moment or select a different vehicle tier.',
                      style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Retry Searching for Drivers',
                      onPressed: _startSearchCountdown,
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: 'Change Vehicle Tier',
                      onPressed: () => context.go(Routes.rideRequest),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => context.go(Routes.passengerHome),
                      child: const Text('Cancel Request', style: TextStyle(color: TRYPColors.grey)),
                    ),
                  ]
                  // STATE 0: SEARCHING FOR DRIVERS
                  else if (_simulationStep == 0) ...[
                    LoadingIndicator(message: 'Searching for nearby verified TRYP drivers... ($_searchCountdown s)'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Cancel Request',
                            onPressed: () => context.go(Routes.passengerHome),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.orange),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _triggerNoDriverScenario,
                            child: const Text(
                              'Test: No Drivers',
                              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ]
                  // STATES 1-4: DRIVER MATCHED & IN PROGRESS
                  else ...[
                    // Safety PIN Code Display Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: TRYPColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: TRYPColors.primary),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_rounded, color: TRYPColors.secondary, size: 20),
                              const SizedBox(width: 8),
                              Text('Safety PIN Code:', style: TRYPTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: TRYPColors.secondary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              pinCode,
                              style: TRYPTypography.headingSmall.copyWith(color: TRYPColors.primary, letterSpacing: 3),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Driver Details Card
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 26,
                          backgroundColor: TRYPColors.primary,
                          child: Icon(Icons.person_rounded, size: 30, color: TRYPColors.secondary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text('Verified Driver', style: TRYPTypography.headingSmall.copyWith(fontSize: 17)),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.verified_rounded, color: Colors.blueAccent, size: 18),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                  const SizedBox(width: 4),
                                  Text('4.9 ★ (124 rides)', style: TRYPTypography.bodySmall),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Calling driver (+27 82 123 4567)...')),
                            );
                          },
                          icon: const Icon(Icons.phone_rounded, color: TRYPColors.primary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Vehicle & Fare Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Vehicle:', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
                        Text('Toyota Corolla Quest (Silver) • ND 123-456', style: TRYPTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Fare:', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
                        Text('R${fareAmount.toStringAsFixed(2)} (Paystack Card)', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Step Action Buttons
                    if (_simulationStep == 1)
                      SecondaryButton(
                        label: 'Cancel Ride',
                        onPressed: () => context.go(Routes.passengerHome),
                      )
                    else if (_simulationStep == 2)
                      PrimaryButton(
                        label: 'Provide PIN & Start Ride',
                        onPressed: _startTripWithPin,
                      )
                    else if (_simulationStep == 3)
                      PrimaryButton(
                        label: 'Complete Trip',
                        onPressed: _completeRide,
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
