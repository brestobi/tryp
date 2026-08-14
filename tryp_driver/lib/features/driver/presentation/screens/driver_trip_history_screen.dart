import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/services/trip_service.dart';
import 'package:tryp_driver/core/widgets/driver_bottom_nav_bar.dart';

class DriverTripHistoryScreen extends ConsumerStatefulWidget {
  const DriverTripHistoryScreen({super.key});

  @override
  ConsumerState<DriverTripHistoryScreen> createState() =>
      _DriverTripHistoryScreenState();
}

class _DriverTripHistoryScreenState
    extends ConsumerState<DriverTripHistoryScreen> {
  List<TripModel> _rides = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final rides = await ref.read(tripServiceProvider).getDriverTripHistory();
      if (!mounted) return;
      setState(() {
        _rides = rides;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load your ride history. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.surface,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        elevation: 0,
        title: Text(
          'Ride History',
          style: TRYPTypography.headingSmall.copyWith(fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadHistory,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh ride history',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: _rides.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                      itemCount: _rides.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _HistoryRideCard(trip: _rides[index]),
                    ),
            ),
      bottomNavigationBar: const DriverBottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        const Icon(
          Icons.history_rounded,
          size: 72,
          color: TRYPColors.grey,
        ),
        const SizedBox(height: 18),
        Text(
          _error == null ? 'No ride history yet' : _error!,
          textAlign: TextAlign.center,
          style: TRYPTypography.headingSmall.copyWith(color: TRYPColors.grey),
        ),
        const SizedBox(height: 8),
        Text(
          _error == null
              ? 'Completed and cancelled rides will appear here.'
              : 'Check your connection and pull down to retry.',
          textAlign: TextAlign.center,
          style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
        ),
        if (_error != null) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton(
              onPressed: _loadHistory,
              child: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryRideCard extends StatelessWidget {
  final TripModel trip;

  const _HistoryRideCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final cancelled = trip.status == TripStatus.cancelled;
    final statusColor = cancelled ? TRYPColors.error : TRYPColors.success;
    final statusLabel = cancelled ? 'Cancelled' : 'Completed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TRYPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  cancelled
                      ? Icons.cancel_outlined
                      : Icons.check_circle_outline_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trip.passengerName ?? 'Passenger',
                      style: TRYPTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(trip.requestedAt),
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cancelled ? '—' : 'R${trip.fare.toStringAsFixed(2)}',
                    style: TRYPTypography.titleMedium.copyWith(
                      color: cancelled ? TRYPColors.grey : TRYPColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusLabel,
                    style: TRYPTypography.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _RouteLine(
            icon: Icons.my_location_rounded,
            color: TRYPColors.primary,
            text: trip.origin,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(
              height: 16,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: TRYPColors.divider)),
              ),
            ),
          ),
          _RouteLine(
            icon: Icons.location_on_rounded,
            color: TRYPColors.secondary,
            text: trip.destination,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _InfoChip(
                icon: Icons.directions_car_filled_outlined,
                label: trip.rideType,
              ),
              const SizedBox(width: 8),
              _InfoChip(
                icon: Icons.route_rounded,
                label: '${trip.distanceKm.toStringAsFixed(1)} km',
              ),
              if (trip.rideReference.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.rideReference,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TRYPTypography.bodySmall.copyWith(
                      color: TRYPColors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} at $hour:$minute';
  }
}

class _RouteLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _RouteLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TRYPTypography.bodyMedium.copyWith(
              color: TRYPColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: TRYPColors.inputFill,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TRYPColors.grey),
          const SizedBox(width: 5),
          Text(
            label,
            style: TRYPTypography.labelSmall.copyWith(color: TRYPColors.grey),
          ),
        ],
      ),
    );
  }
}
