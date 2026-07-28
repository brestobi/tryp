import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({Key? key}) : super(key: key);

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  int _tripStateIndex = 0; // 0: En Route to Pickup, 1: Arrived at Pickup, 2: On Trip to Destination, 3: Completed

  final List<String> _stateLabels = [
    'En Route to Pickup',
    'Arrived at Pickup',
    'Trip in Progress',
    'Trip Completed',
  ];

  void _nextState() {
    if (_tripStateIndex < 2) {
      setState(() => _tripStateIndex++);
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text('Trip Complete!', style: TRYPTypography.headingSmall.copyWith(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fare Collected: R82.50', style: TRYPTypography.headingMedium.copyWith(color: TRYPColors.secondary)),
            const SizedBox(height: 4),
            Text('Payment Method: Paystack Online Card', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
            const SizedBox(height: 12),
            Text('R82.50 has been credited to your TRYP Driver earnings balance.', style: TRYPTypography.bodyMedium),
          ],
        ),
        actions: [
          PrimaryButton(
            label: 'Back to Driver Home',
            onPressed: () {
              Navigator.pop(context);
              context.go(Routes.driverHome);
            },
          ),
        ],
      ),
    );
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
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(Routes.driverHome),
        ),
        title: Text(
          _stateLabels[_tripStateIndex],
          style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Map Preview Placeholder
            Expanded(
              child: Container(
                color: TRYPColors.lightGrey,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map_rounded, size: 64, color: TRYPColors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'Turn-by-turn Navigation Active',
                        style: TRYPTypography.headingSmall.copyWith(color: TRYPColors.secondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tripStateIndex < 2 ? 'Heading to Sandton City Mall' : 'Heading to Rosebank Mall',
                        style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Passenger & Action Panel
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: TRYPColors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: TRYPColors.primary,
                        child: Icon(Icons.person_rounded, color: TRYPColors.secondary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sipho Nkosi', style: TRYPTypography.headingSmall),
                            Text('Pickup: Sandton City Mall', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Calling passenger +27 82 123 4567...')),
                          );
                        },
                        icon: const Icon(Icons.phone_rounded, color: TRYPColors.primary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  PrimaryButton(
                    label: _tripStateIndex == 0
                        ? 'Arrived at Pickup Location'
                        : _tripStateIndex == 1
                            ? 'Start Trip with Passenger'
                            : 'Complete Trip & Collect R82.50',
                    onPressed: _nextState,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
