import 'package:flutter/material.dart';
import 'package:tryp/features/passenger/presentation/screens/passenger_home_screen.dart';

/// Ride Request Screen Page — Delegates directly to PassengerHomeScreenPage
/// as the Home Screen is the primary Bolt-style Ride Screen.
class RideRequestScreenPage extends StatelessWidget {
  const RideRequestScreenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PassengerHomeScreenPage();
  }
}
