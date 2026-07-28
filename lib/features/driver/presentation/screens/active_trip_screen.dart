import 'package:flutter/material.dart';
import 'package:tryp/app/theme.dart';

class ActiveTripScreen extends StatelessWidget {
  const ActiveTripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      appBar: AppBar(
        backgroundColor: TRYPColors.secondary,
        foregroundColor: TRYPColors.white,
        elevation: 0,
        title: const Text('Active Trip'),
      ),
      body: const Center(
        child: Text('Active trip content goes here'),
      ),
    );
  }
}
