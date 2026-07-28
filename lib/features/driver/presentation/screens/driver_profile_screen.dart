import 'package:flutter/material.dart';
import 'package:tryp/app/theme.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      appBar: AppBar(
        backgroundColor: TRYPColors.secondary,
        foregroundColor: TRYPColors.white,
        elevation: 0,
        title: const Text('Driver Profile'),
      ),
      body: const Center(
        child: Text('Driver profile content goes here'),
      ),
    );
  }
}
