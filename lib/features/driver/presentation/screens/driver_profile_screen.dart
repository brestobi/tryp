import 'package:flutter/material.dart';
import 'package:tryp/app/theme.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.primary,
        elevation: 0,
        title: const Text('Driver Profile'),
      ),
      body: const Center(
        child: Text(
          'Driver profile content goes here',
          style: TextStyle(color: TRYPColors.primary),
        ),
      ),
    );
  }
}
