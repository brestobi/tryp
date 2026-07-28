import 'package:flutter/material.dart';
import 'package:tryp/app/theme.dart';

class DriverDocumentsScreen extends StatelessWidget {
  const DriverDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.secondary,
      appBar: AppBar(
        backgroundColor: TRYPColors.secondary,
        foregroundColor: TRYPColors.white,
        elevation: 0,
        title: const Text('Driver Documents'),
      ),
      body: const Center(
        child: Text('Driver documents content goes here'),
      ),
    );
  }
}
