import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/trip_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class RideCompletionScreen extends ConsumerStatefulWidget {
  final TripModel trip;

  const RideCompletionScreen({super.key, required this.trip});

  @override
  ConsumerState<RideCompletionScreen> createState() =>
      _RideCompletionScreenState();
}

class _RideCompletionScreenState extends ConsumerState<RideCompletionScreen> {
  final TextEditingController _reviewController = TextEditingController();
  int _rating = 5;
  bool _isSubmitting = false;

  TripModel get trip => widget.trip;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() => _isSubmitting = true);
    final saved = await ref
        .read(tripServiceProvider)
        .submitRating(
          rideId: trip.id,
          rating: _rating,
          review: _reviewController.text.trim(),
        );

    if (!mounted) return;
    if (!saved) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save your rating. Please try again.'),
          backgroundColor: TRYPColors.error,
        ),
      );
      return;
    }

    context.go(Routes.passengerHome);
  }

  void _skipRating() => context.go(Routes.passengerHome);

  @override
  Widget build(BuildContext context) {
    final completedAt = trip.completedAt ?? trip.requestedAt;
    final driverName = trip.driverName?.isNotEmpty == true
        ? trip.driverName!
        : 'Your TRYP driver';
    final paymentStatus = _paymentStatusLabel(trip.paymentStatus);

    return Scaffold(
      backgroundColor: TRYPColors.surface,
      appBar: AppBar(
        backgroundColor: TRYPColors.surface,
        automaticallyImplyLeading: false,
        title: const Text('Ride complete'),
        actions: [
          TextButton(onPressed: _skipRating, child: const Text('Done')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: TRYPColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: TRYPColors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: TRYPColors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'You have arrived',
                      style: TRYPTypography.headingMedium.copyWith(
                        color: TRYPColors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Thanks for riding with TRYP',
                      style: TRYPTypography.bodyMedium.copyWith(
                        color: TRYPColors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'R${trip.fare.toStringAsFixed(2)}',
                      style: TRYPTypography.headingLarge.copyWith(
                        color: TRYPColors.white,
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${trip.rideReference.isNotEmpty ? trip.rideReference : 'Trip'} • ${trip.paymentMethod} • $paymentStatus',
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionCard(
                title: 'Trip details',
                child: Column(
                  children: [
                    _RouteRow(
                      icon: Icons.my_location_rounded,
                      color: TRYPColors.success,
                      label: 'Pickup',
                      value: trip.origin,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 11),
                      child: Container(
                        height: 22,
                        width: 1,
                        color: TRYPColors.divider,
                      ),
                    ),
                    _RouteRow(
                      icon: Icons.location_on_rounded,
                      color: TRYPColors.error,
                      label: 'Destination',
                      value: trip.destination,
                    ),
                    const Divider(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailItem(
                            icon: Icons.straighten_rounded,
                            label: 'Distance',
                            value: '${trip.distanceKm.toStringAsFixed(1)} km',
                          ),
                        ),
                        Expanded(
                          child: _DetailItem(
                            icon: Icons.schedule_rounded,
                            label: 'Completed',
                            value: _formatDate(completedAt),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _DetailItem(
                            icon: Icons.local_taxi_rounded,
                            label: 'Ride type',
                            value: trip.rideType,
                          ),
                        ),
                        Expanded(
                          child: _DetailItem(
                            icon: Icons.person_rounded,
                            label: 'Driver',
                            value: driverName,
                          ),
                        ),
                      ],
                    ),
                    if (trip.vehicleDescription != 'TRYP Vehicle') ...[
                      const SizedBox(height: 18),
                      _DetailItem(
                        icon: Icons.directions_car_rounded,
                        label: 'Vehicle',
                        value: trip.vehicleDescription,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionCard(
                title: 'Rate your driver',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How was your trip with $driverName?',
                      style: TRYPTypography.bodyMedium.copyWith(
                        color: TRYPColors.grey,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        return IconButton(
                          tooltip: '$star star${star == 1 ? '' : 's'}',
                          onPressed: () => setState(() => _rating = star),
                          icon: Icon(
                            star <= _rating
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: Colors.amber.shade700,
                            size: 38,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _reviewController,
                      maxLength: 240,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Review (optional)',
                        hintText: 'Tell us about your trip',
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: 'Submit rating',
                      icon: Icons.send_rounded,
                      isLoading: _isSubmitting,
                      onPressed: _submitRating,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _isSubmitting ? null : _skipRating,
                        child: const Text('Skip for now'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SecondaryButton(
                label: 'View past trips',
                onPressed: () => context.go(Routes.passengerActivity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TRYPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TRYPTypography.titleLarge),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  String _paymentStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'processing':
        return 'Verifying payment';
      case 'failed':
        return 'Payment failed';
      case 'cancelled':
        return 'Payment cancelled';
      default:
        return 'Pending';
    }
  }

  String _formatDate(DateTime dateTime) {
    final date =
        '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year}';
    final time =
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';

    return '$date, $time';
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;

  const _RouteRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TRYPTypography.labelSmall),
              const SizedBox(height: 3),
              Text(
                value,
                style: TRYPTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: TRYPColors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TRYPTypography.labelSmall),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TRYPTypography.bodySmall.copyWith(
                  color: TRYPColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
