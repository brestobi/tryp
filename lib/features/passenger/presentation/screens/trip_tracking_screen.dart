import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class TripTrackingScreenPage extends StatefulWidget {
  const TripTrackingScreenPage({Key? key}) : super(key: key);

  @override
  State<TripTrackingScreenPage> createState() => _TripTrackingScreenPageState();
}

class _TripTrackingScreenPageState extends State<TripTrackingScreenPage> {
  bool _driverAssigned = false;

  @override
  void initState() {
    super.initState();
    // Simulate finding a driver after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _driverAssigned = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.passengerHome),
        ),
        title: Text(_driverAssigned ? 'Driver En Route' : 'Searching Driver'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(-26.2041, 28.0473),
                  zoom: 15,
                ),
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                markers: _driverAssigned
                    ? {
                        const Marker(
                          markerId: MarkerId('driver'),
                          position: LatLng(-26.2025, 28.0450),
                          infoWindow: InfoWindow(title: 'Driver - Sipho (Toyota Corolla)'),
                        ),
                      }
                    : {},
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: TRYPColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_driverAssigned) ...[
                    const LoadingIndicator(message: 'Searching for nearby TRYP drivers...'),
                    const SizedBox(height: 20),
                    SecondaryButton(
                      label: 'Cancel Search',
                      onPressed: () => context.go(Routes.passengerHome),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: TRYPColors.primary,
                          child: Icon(Icons.person, size: 32, color: TRYPColors.secondary),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Sipho M.', style: TRYPTypography.headingSmall),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 18),
                                  const SizedBox(width: 4),
                                  Text('4.9 (124 rides)', style: TRYPTypography.bodyMedium),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: TRYPColors.lightGrey,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'GP 88 AB',
                            style: TRYPTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Vehicle:', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
                        Text('Toyota Corolla (Silver)', style: TRYPTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimated Arrival:', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
                        Text('3 mins', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Cancel Ride',
                            onPressed: () => context.go(Routes.passengerHome),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Arrived',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Trip Completed! Thank you for riding with TRYP.')),
                              );
                              context.go(Routes.passengerHome);
                            },
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
