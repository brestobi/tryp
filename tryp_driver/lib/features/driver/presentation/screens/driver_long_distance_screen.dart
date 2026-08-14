import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/services/supabase_service.dart';
import 'package:tryp_driver/core/widgets/driver_bottom_nav_bar.dart';

const _driverNavy = TRYPColors.secondary;
const _driverGreen = TRYPColors.primary;
const _driverSky = TRYPColors.primaryAlt;
const _driverGold = TRYPColors.primary;
const _driverLilac = TRYPColors.white;

class DriverLongDistanceScreen extends ConsumerStatefulWidget {
  const DriverLongDistanceScreen({super.key});

  @override
  ConsumerState<DriverLongDistanceScreen> createState() =>
      _DriverLongDistanceScreenState();
}

class _DriverLongDistanceScreenState
    extends ConsumerState<DriverLongDistanceScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _seatsController = TextEditingController(text: '4');
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  bool _isSubmitting = false;
  bool _loadingTrips = true;
  bool _loadingBookings = true;
  List<Map<String, dynamic>> _myTrips = [];
  List<Map<String, dynamic>> _myBookings = [];

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();
  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _fadeController,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _seatsController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    await Future.wait([_fetchMyTrips(), _fetchMyBookings()]);
  }

  Future<void> _fetchMyTrips() async {
    if (mounted) setState(() => _loadingTrips = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user == null) {
        return;
      }
      final data = await client
          .from('long_distance_trips')
          .select()
          .eq('driver_id', user.id)
          .order('departure_at', ascending: false)
          .limit(20);
      if (mounted) {
        setState(() => _myTrips = List<Map<String, dynamic>>.from(data));
      }
    } catch (error) {
      debugPrint('Error fetching long-distance trips: $error');
    } finally {
      if (mounted) setState(() => _loadingTrips = false);
    }
  }

  Future<void> _fetchMyBookings() async {
    if (mounted) setState(() => _loadingBookings = true);
    try {
      final data = await ref
          .read(supabaseClientProvider)
          .rpc('get_my_long_distance_bookings');
      if (mounted) {
        setState(() => _myBookings = List<Map<String, dynamic>>.from(data));
      }
    } catch (error) {
      debugPrint('Error fetching long-distance bookings: $error');
    } finally {
      if (mounted) setState(() => _loadingBookings = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Select departure date',
    );
    if (picked != null && mounted) setState(() => _departureDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _departureTime ?? const TimeOfDay(hour: 6, minute: 0),
      helpText: 'Select departure time',
    );
    if (picked != null && mounted) setState(() => _departureTime = picked);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _submitTrip() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_departureDate == null || _departureTime == null) return;

    setState(() => _isSubmitting = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final departureAt = DateTime(
        _departureDate!.year,
        _departureDate!.month,
        _departureDate!.day,
        _departureTime!.hour,
        _departureTime!.minute,
      ).toUtc();

      await client.from('long_distance_trips').insert({
        'driver_id': user.id,
        'origin': _fromController.text.trim(),
        'destination': _toController.text.trim(),
        'seats_available': int.parse(_seatsController.text.trim()),
        'price_per_seat': double.parse(_priceController.text.trim()),
        'departure_at': departureAt.toIso8601String(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        'status': 'active',
      });

      if (!mounted) return;
      _fromController.clear();
      _toController.clear();
      _seatsController.text = '4';
      _priceController.clear();
      _notesController.clear();
      setState(() {
        _departureDate = null;
        _departureTime = null;
      });
      await _fetchMyTrips();
    } catch (error) {
      debugPrint('Error posting trip: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _cancelTrip(String tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel Trip'),
        content: const Text(
          'Are you sure you want to cancel this long-distance trip listing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: TRYPColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Trip'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(supabaseClientProvider)
          .from('long_distance_trips')
          .update({'status': 'cancelled'})
          .eq('id', tripId);
      await _fetchMyTrips();
    } catch (error) {
      debugPrint('Error cancelling trip: $error');
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
          'Long Distance Trips',
          style: TRYPTypography.headingSmall.copyWith(fontSize: 20),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            _heroBanner(),
            const SizedBox(height: 20),
            _summaryStrip(),
            const SizedBox(height: 24),
            _sectionHeading(
              icon: Icons.add_road_rounded,
              title: 'Create a listing',
              subtitle: 'Share your route and fill empty seats.',
              color: _driverGreen,
            ),
            const SizedBox(height: 12),
            _tripForm(),
            const SizedBox(height: 28),
            _sectionHeader(
              'My posted trips',
              loading: _loadingTrips,
              onRefresh: _fetchMyTrips,
            ),
            const SizedBox(height: 10),
            if (_loadingTrips)
              const _DriverLoadingCard(label: 'Loading your trip listings…')
            else if (_myTrips.isEmpty)
              _emptyCard(
                'No trips posted yet. Your next listing could help someone get home.',
                icon: Icons.route_rounded,
                color: _driverSky,
              )
            else
              ..._myTrips.map(
                (trip) => _TripCard(
                  trip: trip,
                  onCancel: _cancelTrip,
                  formatDate: _formatDate,
                  formatTime: _formatTime,
                ),
              ),
            const SizedBox(height: 24),
            _sectionHeader(
              'Booked passengers',
              loading: _loadingBookings,
              onRefresh: _fetchMyBookings,
            ),
            const SizedBox(height: 10),
            if (_loadingBookings)
              const _DriverLoadingCard(label: 'Checking confirmed passengers…')
            else if (_myBookings.isEmpty)
              _emptyCard(
                'Confirmed passenger bookings will appear here.',
                icon: Icons.groups_rounded,
                color: _driverLilac,
              )
            else
              ..._myBookings.map((booking) => _BookingCard(booking: booking)),
          ],
        ),
      ),
      bottomNavigationBar: const DriverBottomNavBar(currentIndex: 2),
    );
  }

  Widget _heroBanner() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [_driverNavy, TRYPColors.primaryAlt],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: _driverGreen.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: _driverGold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            color: _driverGold,
            size: 32,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Make room for the road',
                style: TRYPTypography.titleLarge.copyWith(
                  color: TRYPColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Share your intercity route and earn from every booked seat.',
                style: TRYPTypography.bodySmall.copyWith(
                  color: TRYPColors.white.withValues(alpha: 0.78),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _summaryStrip() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: TRYPColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _driverGreen.withValues(alpha: 0.18)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _SummaryMetric(
            icon: Icons.route_rounded,
            value: '${_myTrips.length}',
            label: 'Listings',
            color: _driverSky,
          ),
        ),
        Container(width: 1, height: 34, color: TRYPColors.divider),
        Expanded(
          child: _SummaryMetric(
            icon: Icons.groups_rounded,
            value: '${_myBookings.length}',
            label: 'Passengers',
            color: _driverLilac,
          ),
        ),
        Container(width: 1, height: 34, color: TRYPColors.divider),
        Expanded(
          child: _SummaryMetric(
            icon: Icons.event_seat_rounded,
            value:
                '${_myTrips.fold<int>(0, (sum, trip) => sum + (trip['seats_available'] as int? ?? 0))}',
            label: 'Seats offered',
            color: _driverGreen,
          ),
        ),
      ],
    ),
  );

  Widget _sectionHeading({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 19),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TRYPTypography.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _tripForm() => Form(
    key: _formKey,
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: TRYPColors.accentSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _driverGreen.withValues(alpha: 0.18)),
          ),
          child: Column(
            children: [
              _field(
                _fromController,
                'Departure City / Town',
                'e.g. Tzaneen',
                Icons.trip_origin_rounded,
                TRYPColors.primary,
                validator: _required,
              ),
              const Divider(height: 1),
              _field(
                _toController,
                'Destination City / Town',
                'e.g. Johannesburg',
                Icons.location_on_rounded,
                TRYPColors.secondary,
                validator: _required,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: 'Select departure date',
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(18),
                  child: _infoTile(
                    Icons.calendar_today_rounded,
                    'Departure Date',
                    _departureDate == null
                        ? 'Select date'
                        : _formatDate(_departureDate!),
                    _departureDate == null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                button: true,
                label: 'Select departure time',
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(18),
                  child: _infoTile(
                    Icons.access_time_rounded,
                    'Departure Time',
                    _departureTime == null
                        ? 'Select time'
                        : _formatTime(_departureTime!),
                    _departureTime == null,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _card(
                _field(
                  _seatsController,
                  'Seats Available',
                  '1–8',
                  Icons.event_seat_rounded,
                  TRYPColors.secondary,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final seats = int.tryParse(value ?? '');
                    return seats == null || seats < 1 || seats > 8
                        ? '1–8 seats'
                        : null;
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _card(
                _field(
                  _priceController,
                  'Price per Seat (R)',
                  'e.g. 350',
                  Icons.payments_rounded,
                  TRYPColors.primary,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  validator: (value) {
                    final price = double.tryParse(value ?? '');
                    return price == null || price <= 0 ? 'Enter price' : null;
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _card(
          _field(
            _notesController,
            'Additional Notes (optional)',
            'e.g. Pickup at taxi rank, luggage allowed...',
            Icons.notes_rounded,
            TRYPColors.grey,
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitTrip,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.rocket_launch_rounded),
            label: Text(_isSubmitting ? 'Posting...' : 'Post Trip Listing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _driverGreen,
              foregroundColor: TRYPColors.white,
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _sectionHeader(
    String title, {
    required bool loading,
    required VoidCallback onRefresh,
  }) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TRYPTypography.headingSmall.copyWith(fontSize: 19),
        ),
      ),
      if (!loading)
        TextButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
          style: TextButton.styleFrom(foregroundColor: _driverGreen),
        ),
    ],
  );

  Widget _emptyCard(
    String message, {
    required IconData icon,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: TRYPColors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 9),
        Text(
          message,
          style: TRYPTypography.bodySmall.copyWith(
            color: TRYPColors.grey,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _card(Widget child) => Container(
    decoration: BoxDecoration(
      color: TRYPColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: TRYPColors.divider),
    ),
    child: child,
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon,
    Color iconColor, {
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            validator: validator,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: InputBorder.none,
              labelStyle: TRYPTypography.bodySmall.copyWith(
                color: TRYPColors.grey,
              ),
            ),
            style: TRYPTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _infoTile(
    IconData icon,
    String label,
    String value,
    bool placeholder,
  ) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: TRYPColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: placeholder ? TRYPColors.divider : _driverGreen,
        width: placeholder ? 1 : 1.5,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: placeholder ? TRYPColors.grey : _driverGreen,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TRYPTypography.labelSmall.copyWith(
                  color: TRYPColors.grey,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TRYPTypography.titleMedium.copyWith(
            color: placeholder ? TRYPColors.grey : _driverNavy,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final Future<void> Function(String) onCancel;
  final String Function(DateTime) formatDate;
  final String Function(TimeOfDay) formatTime;

  const _TripCard({
    required this.trip,
    required this.onCancel,
    required this.formatDate,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    final status = trip['status'] as String? ?? 'active';
    final total = trip['seats_available'] as int? ?? 0;
    final booked = trip['seats_booked'] as int? ?? 0;
    final reserved = trip['seats_reserved'] as int? ?? 0;
    final left = total - booked - reserved;
    final price = (trip['price_per_seat'] as num?)?.toDouble() ?? 0;
    final departure = trip['departure_at'] == null
        ? null
        : DateTime.tryParse(trip['departure_at'].toString())?.toLocal();
    final statusColor = status == 'active'
        ? TRYPColors.primary
        : status == 'completed'
        ? TRYPColors.primary
        : TRYPColors.error;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: statusColor.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _driverSky.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  size: 17,
                  color: _driverSky,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${trip['origin']} → ${trip['destination']}',
                  style: TRYPTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  softWrap: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == 'active'
                        ? Icons.check_circle_rounded
                        : status == 'completed'
                        ? Icons.flag_rounded
                        : Icons.cancel_rounded,
                    size: 12,
                    color: statusColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status.toUpperCase(),
                    style: TRYPTypography.labelSmall.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.calendar_today_rounded,
                label: departure == null ? '—' : formatDate(departure),
              ),
              _InfoChip(
                icon: Icons.access_time_rounded,
                label: departure == null
                    ? '—'
                    : formatTime(
                        TimeOfDay(
                          hour: departure.hour,
                          minute: departure.minute,
                        ),
                      ),
              ),
              _InfoChip(
                icon: Icons.event_seat_rounded,
                label: '$left/$total seats left',
              ),
              _InfoChip(
                icon: Icons.payments_rounded,
                label: 'R${price.toStringAsFixed(0)}/seat',
                highlight: true,
              ),
            ],
          ),
          if (trip['notes'] != null &&
              (trip['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              trip['notes'] as String,
              style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
            ),
          ],
          if (status == 'active') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => onCancel(trip['id'].toString()),
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel Listing'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: TRYPColors.error,
                  side: const BorderSide(color: TRYPColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  const _BookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'confirmed';
    final paymentStatus = booking['payment_status'] as String? ?? 'paid';
    final origin = booking['origin'] as String? ?? '';
    final destination = booking['destination'] as String? ?? '';
    final name = booking['passenger_name'] as String? ?? 'Passenger';
    final phone = booking['passenger_phone'] as String? ?? '';
    final seats = booking['seats'] as int? ?? 1;
    final amount = (booking['amount_paid'] as num?)?.toDouble() ?? 0;
    final isPaid = paymentStatus == 'paid';
    final statusColor = status == 'confirmed' && isPaid
        ? TRYPColors.primary
        : paymentStatus == 'failed'
        ? TRYPColors.error
        : TRYPColors.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person_pin_rounded,
                color: _driverLilac,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Passenger booking',
                  style: TRYPTypography.labelSmall.copyWith(
                    color: _driverLilac,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _BookingStatusPill(
                label: isPaid ? status : paymentStatus,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: TRYPColors.primary.withValues(alpha: 0.15),
                child: Text(
                  name.isEmpty ? 'P' : name[0].toUpperCase(),
                  style: const TextStyle(
                    color: TRYPColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TRYPTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (origin.isNotEmpty && destination.isNotEmpty)
                      Text(
                        '$origin → $destination',
                        style: TRYPTypography.bodySmall.copyWith(
                          color: TRYPColors.secondary,
                        ),
                      ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: TRYPTypography.bodySmall.copyWith(
                          color: TRYPColors.grey,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      '$seats seat${seats == 1 ? '' : 's'} · R${amount.toStringAsFixed(2)}',
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _BookingStatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label.toUpperCase(),
      style: TRYPTypography.labelSmall.copyWith(
        color: color,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _SummaryMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 19),
      const SizedBox(height: 4),
      Text(
        value,
        style: TRYPTypography.titleMedium.copyWith(fontWeight: FontWeight.w800),
      ),
      Text(label, style: TRYPTypography.bodySmall.copyWith(fontSize: 10)),
    ],
  );
}

class _DriverLoadingCard extends StatelessWidget {
  final String label;
  const _DriverLoadingCard({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: TRYPColors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: TRYPColors.divider),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: _driverGreen,
          ),
        ),
        const SizedBox(width: 11),
        Text(
          label,
          style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
        ),
      ],
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _InfoChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: highlight
          ? _driverGreen.withValues(alpha: 0.12)
          : TRYPColors.inputFill,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: highlight ? _driverGreen : TRYPColors.grey),
        const SizedBox(width: 5),
        Text(
          label,
          style: TRYPTypography.labelSmall.copyWith(
            color: highlight ? _driverGreen : TRYPColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
