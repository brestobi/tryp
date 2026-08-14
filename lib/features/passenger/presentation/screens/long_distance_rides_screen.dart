import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/payment_service.dart';
import 'package:tryp/core/services/payment_checkout_result.dart';

const _passengerHero = TRYPColors.secondary;
const _passengerRed = TRYPColors.primary;
const _passengerBorder = TRYPColors.accentSoft;

class LongDistanceRidesScreen extends StatefulWidget {
  const LongDistanceRidesScreen({super.key});

  @override
  State<LongDistanceRidesScreen> createState() =>
      _LongDistanceRidesScreenState();
}

class _LongDistanceRidesScreenState extends State<LongDistanceRidesScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _trips = [];
  bool _isLoading = true;
  bool _isRecoveringPendingPayment = false;
  String _filterFrom = '';
  String _filterTo = '';
  final _pendingBookingIds = <String>{};
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchTrips();
    unawaited(_recoverPendingPayments());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_recoverPendingPayments());
      unawaited(_fetchTrips());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchTrips() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final data = await client.rpc('get_active_long_distance_trips');
      var trips = List<Map<String, dynamic>>.from(data);

      if (_filterFrom.isNotEmpty) {
        trips = trips
            .where(
              (t) => (t['origin'] as String? ?? '').toLowerCase().contains(
                _filterFrom.toLowerCase(),
              ),
            )
            .toList();
      }
      if (_filterTo.isNotEmpty) {
        trips = trips
            .where(
              (t) => (t['destination'] as String? ?? '').toLowerCase().contains(
                _filterTo.toLowerCase(),
              ),
            )
            .toList();
      }

      if (mounted) setState(() => _trips = trips);
    } catch (e) {
      debugPrint('Error fetching long distance trips: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _filterFrom = _fromCtrl.text.trim();
      _filterTo = _toCtrl.text.trim();
    });
    _fetchTrips();
  }

  Future<void> _recoverPendingPayments() async {
    if (!mounted || _isRecoveringPendingPayment) return;
    _isRecoveringPendingPayment = true;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final response = await Supabase.instance.client
          .from('long_distance_bookings')
          .select('id, payment_status, payment_reference')
          .eq('passenger_id', user.id)
          .inFilter('payment_status', ['pending', 'processing']);
      final rows = (response as List<dynamic>)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .where(
            (row) => (row['payment_reference'] as String?)?.isNotEmpty ?? false,
          )
          .toList();
      _pendingBookingIds.addAll(rows.map((row) => row['id'].toString()));

      var changed = false;
      for (final bookingId in _pendingBookingIds.toList()) {
        final status = await PaymentService.verifyLongDistanceBooking(
          bookingId: bookingId,
        );
        final normalized = status.trim().toLowerCase();
        if (normalized == 'paid' ||
            normalized == 'failed' ||
            normalized == 'cancelled') {
          _pendingBookingIds.remove(bookingId);
          changed = true;
        }
      }

      if (!mounted || !changed) return;
      await _fetchTrips();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pending booking payment status refreshed.'),
          backgroundColor: TRYPColors.secondary,
        ),
      );
    } catch (error) {
      debugPrint('Long-distance payment recovery failed: $error');
    } finally {
      _isRecoveringPendingPayment = false;
    }
  }

  Future<void> _bookSeat(Map<String, dynamic> trip) async {
    final seatsTotal = trip['seats_available'] as int? ?? 0;
    final seatsBooked = trip['seats_booked'] as int? ?? 0;
    final seatsReserved = trip['seats_reserved'] as int? ?? 0;
    if (seatsTotal - seatsBooked - seatsReserved <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No seats available for this trip.'),
          backgroundColor: TRYPColors.error,
        ),
      );
      return;
    }

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookingConfirmSheet(trip: trip),
    );
    if (confirm != true || !mounted) return;

    String? createdBookingId;
    var paymentSettled = false;
    var paymentOutcomeKnown = false;
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;

      final tripId = trip['id'].toString();
      final bookingId = await client.rpc(
        'create_long_distance_booking',
        params: {'p_trip_id': tripId, 'p_seats': 1},
      );

      final bookingIdString = bookingId.toString();
      createdBookingId = bookingIdString;
      _pendingBookingIds.add(bookingIdString);
      if (!mounted) {
        await PaymentService.cancelLongDistanceBooking(
          bookingId: bookingIdString,
        );
        _pendingBookingIds.remove(bookingIdString);
        return;
      }
      final checkoutNavigator = Navigator.of(context);
      final result = await PaymentService.chargeForLongDistanceBooking(
        navigator: checkoutNavigator,
        bookingId: bookingIdString,
      );
      paymentOutcomeKnown = true;

      if (!mounted) return;
      if (result == PaymentCheckoutResult.paid) {
        paymentSettled = true;
        paymentOutcomeKnown = true;
        _pendingBookingIds.remove(bookingIdString);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Seat booked. Check your inbox for details.'),
            backgroundColor: TRYPColors.primary,
          ),
        );
        await _fetchTrips();
      } else if (result == PaymentCheckoutResult.failed ||
          result == PaymentCheckoutResult.cancelled) {
        await PaymentService.cancelLongDistanceBooking(
          bookingId: bookingIdString,
        );
        _pendingBookingIds.remove(bookingIdString);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment was not completed. The seat was released.'),
            backgroundColor: TRYPColors.error,
          ),
        );
        await _fetchTrips();
      } else {
        // Keep the reservation and let the resume/recovery path verify it.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Payment is still being verified. Your seat is reserved temporarily.',
            ),
            backgroundColor: TRYPColors.secondary,
          ),
        );
        await _fetchTrips();
      }
    } catch (e) {
      if (paymentSettled || paymentOutcomeKnown) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                paymentSettled
                    ? 'Booking confirmed. Refresh to view the latest seat status.'
                    : 'Payment status is still being verified. Your seat remains reserved temporarily.',
              ),
              backgroundColor: paymentSettled
                  ? TRYPColors.primary
                  : TRYPColors.secondary,
            ),
          );
        }
        return;
      }

      // Release a reservation if initialization or checkout setup failed.
      // The server RPC is idempotent and will refuse to regress a confirmed
      // booking if a webhook settled it concurrently.
      if (createdBookingId != null && !paymentSettled) {
        try {
          await PaymentService.cancelLongDistanceBooking(
            bookingId: createdBookingId,
          );
          _pendingBookingIds.remove(createdBookingId);
        } catch (cleanupError) {
          debugPrint('Long-distance booking cleanup failed: $cleanupError');
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking error: $e'),
          backgroundColor: TRYPColors.error,
        ),
      );
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _fmtTime(DateTime d) {
    final h = d.hour == 0
        ? 12
        : d.hour > 12
        ? d.hour - 12
        : d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final p = d.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $p';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.surface,
      appBar: AppBar(
        backgroundColor: _passengerHero,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Long-distance rides',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchTrips,
            tooltip: 'Refresh trips',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: _passengerHero,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Where are you headed?',
                  style: TRYPTypography.headingSmall.copyWith(
                    color: Colors.white,
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Find a comfortable seat for your next adventure.',
                  style: TRYPTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    children: [
                      _SearchField(
                        controller: _fromCtrl,
                        hint: 'Leaving from',
                        icon: Icons.trip_origin_rounded,
                        iconColor: _passengerRed,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 1,
                            height: 12,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      _SearchField(
                        controller: _toCtrl,
                        hint: 'Going to',
                        icon: Icons.location_on_rounded,
                        iconColor: TRYPColors.white,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _applyFilter,
                          icon: const Icon(Icons.search_rounded, size: 19),
                          label: const Text('Find available rides'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _passengerRed,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const _PassengerLoadingState()
                : _trips.isEmpty
                ? const _EmptyState()
                : RefreshIndicator(
                    color: _passengerRed,
                    onRefresh: _fetchTrips,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      itemCount: _trips.length + 1,
                      itemBuilder: (ctx, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '${_trips.length} ride${_trips.length == 1 ? '' : 's'} ready to explore',
                              style: TRYPTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        }
                        final trip = _trips[i - 1];
                        return _TripListCard(
                          trip: trip,
                          onBook: () => _bookSeat(trip),
                          fmtDate: _fmtDate,
                          fmtTime: _fmtTime,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Color iconColor;

  const _SearchField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.58)),
      prefixIcon: Icon(icon, color: iconColor, size: 19),
      border: InputBorder.none,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    ),
  );
}

class _PassengerLoadingState extends StatelessWidget {
  const _PassengerLoadingState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _passengerRed.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const CircularProgressIndicator(color: _passengerRed),
        ),
        const SizedBox(height: 16),
        Text(
          'Finding great rides for you…',
          style: TRYPTypography.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

// ─── Empty state ──────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _passengerHero.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.explore_rounded,
                size: 52,
                color: _passengerHero,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No rides found yet',
              style: TRYPTypography.headingSmall.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different route or clear your search.\nNew adventures may be listed soon!',
              style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Single trip card ─────────────────────────────────────────
class _TripListCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final VoidCallback onBook;
  final String Function(DateTime) fmtDate;
  final String Function(DateTime) fmtTime;

  const _TripListCard({
    required this.trip,
    required this.onBook,
    required this.fmtDate,
    required this.fmtTime,
  });

  @override
  Widget build(BuildContext context) {
    final seatsTotal = trip['seats_available'] as int? ?? 0;
    final seatsBooked = trip['seats_booked'] as int? ?? 0;
    final seatsReserved = trip['seats_reserved'] as int? ?? 0;
    final seatsLeft = seatsTotal - seatsBooked - seatsReserved;
    final price = (trip['price_per_seat'] as num?)?.toDouble() ?? 0;
    final depAt = trip['departure_at'] != null
        ? DateTime.tryParse(trip['departure_at'].toString())?.toLocal()
        : null;
    final driverName = trip['driver_name'] as String? ?? 'Driver';
    final vehicle =
        '${trip['vehicle_make'] ?? ''} ${trip['vehicle_model'] ?? ''}'.trim();
    final plate = trip['vehicle_plate'] as String? ?? '';
    final rating = (trip['driver_rating'] as num?)?.toDouble() ?? 0.0;
    final isFull = seatsLeft <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _passengerBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Route header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_passengerHero, TRYPColors.primaryAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.trip_origin_rounded,
                          size: 14,
                          color: _passengerRed,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            trip['origin'] as String? ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: TRYPColors.white,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            trip['destination'] as String? ?? '',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'R${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: _passengerRed,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'per seat',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Driver info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: TRYPColors.inputFill,
                      child: Text(
                        driverName.isNotEmpty
                            ? driverName[0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          color: TRYPColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driverName,
                            style: TRYPTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (vehicle.isNotEmpty)
                            Text(
                              '$vehicle${plate.isNotEmpty ? ' • $plate' : ''}',
                              style: TRYPTypography.bodySmall.copyWith(
                                color: TRYPColors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (rating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: TRYPColors.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: TRYPColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Departure & seats
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      icon: Icons.calendar_today_rounded,
                      label: depAt != null
                          ? fmtDate(depAt)
                          : 'Date to be confirmed',
                      color: _passengerHero,
                    ),
                    _Chip(
                      icon: Icons.access_time_rounded,
                      label: depAt != null
                          ? fmtTime(depAt)
                          : 'Time to be confirmed',
                      color: TRYPColors.white,
                    ),
                    _Chip(
                      icon: Icons.event_seat_rounded,
                      label: '$seatsLeft seat${seatsLeft == 1 ? '' : 's'} left',
                      highlight: seatsLeft > 0,
                      color: _passengerRed,
                    ),
                  ],
                ),

                if (trip['notes'] != null &&
                    (trip['notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: TRYPColors.inputFill,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      trip['notes'] as String,
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.secondary,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isFull ? null : onBook,
                    icon: Icon(
                      isFull ? Icons.block_rounded : Icons.credit_card_rounded,
                    ),
                    label: Text(
                      isFull ? 'Fully Booked' : 'Book Seat — Card Only',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFull ? TRYPColors.grey : _passengerRed,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final Color color;
  const _Chip({
    required this.icon,
    required this.label,
    this.highlight = false,
    this.color = _passengerHero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: highlight ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: TRYPColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Booking confirmation bottom sheet ───────────────────────
class _BookingConfirmSheet extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _BookingConfirmSheet({required this.trip});

  @override
  Widget build(BuildContext context) {
    final price = (trip['price_per_seat'] as num?)?.toDouble() ?? 0;
    final origin = trip['origin'] as String? ?? '';
    final destination = trip['destination'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: TRYPColors.divider,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TRYPColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.credit_card_rounded,
              color: TRYPColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Confirm Booking',
            style: TRYPTypography.headingMedium.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            '$origin → $destination',
            style: TRYPTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: TRYPColors.secondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TRYPColors.inputFill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _Row(label: '1 Seat', value: 'R${price.toStringAsFixed(2)}'),
                const SizedBox(height: 6),
                _Row(label: 'Payment', value: 'Card (Paystack)'),
                const Divider(height: 18),
                _Row(
                  label: 'Total',
                  value: 'R${price.toStringAsFixed(2)}',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '🔒 Card only. No cash accepted for long distance bookings.',
            style: TextStyle(fontSize: 12, color: TRYPColors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.lock_rounded),
              label: const Text('Pay & Book Seat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: TRYPColors.secondary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: TRYPColors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _Row({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? TRYPTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)
        : TRYPTypography.bodyMedium;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style.copyWith(color: TRYPColors.grey)),
        Text(value, style: style),
      ],
    );
  }
}
