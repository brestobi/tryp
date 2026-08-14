import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp_driver/app/routes.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/constants/service_areas.dart';
import 'package:tryp_driver/core/services/supabase_service.dart';
import 'package:tryp_driver/core/widgets/common_widgets.dart';
import 'package:tryp_driver/core/widgets/driver_bottom_nav_bar.dart';

class DriverAccountScreen extends ConsumerStatefulWidget {
  const DriverAccountScreen({super.key});

  @override
  ConsumerState<DriverAccountScreen> createState() =>
      _DriverAccountScreenState();
}

class _DriverAccountScreenState extends ConsumerState<DriverAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _operatingCityController;
  late final TextEditingController _vehicleMakeController;
  late final TextEditingController _vehicleModelController;
  late final TextEditingController _vehiclePlateController;

  String? _serviceArea;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _saveMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _operatingCityController = TextEditingController();
    _vehicleMakeController = TextEditingController();
    _vehicleModelController = TextEditingController();
    _vehiclePlateController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _operatingCityController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user == null) return;

      final profile = await client
          .from('profiles')
          .select(
            'full_name, phone_number, phone, service_area, operating_city, vehicle_make, vehicle_model, vehicle_plate',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _nameController.text =
            profile?['full_name'] as String? ??
            user.userMetadata?['full_name'] as String? ??
            '';
        _phoneController.text =
            profile?['phone_number'] as String? ??
            profile?['phone'] as String? ??
            user.phone ??
            '';
        _operatingCityController.text =
            profile?['operating_city'] as String? ?? '';
        _vehicleMakeController.text = profile?['vehicle_make'] as String? ?? '';
        _vehicleModelController.text =
            profile?['vehicle_model'] as String? ?? '';
        _vehiclePlateController.text =
            profile?['vehicle_plate'] as String? ?? '';
        final area = profile?['service_area'] as String?;
        _serviceArea = TRYPServiceAreas.byId(area)?.id;
      });
    } catch (error) {
      debugPrint('Error loading driver account: $error');
      if (mounted) {
        setState(() => _saveMessage = 'Could not load account details.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user == null) throw StateError('You must be signed in.');

      await client
          .from('profiles')
          .update({
            'full_name': _nameController.text.trim(),
            'phone_number': _phoneController.text.trim(),
            'service_area': _serviceArea,
            'operating_city': _operatingCityController.text.trim(),
            'vehicle_make': _vehicleMakeController.text.trim(),
            'vehicle_model': _vehicleModelController.text.trim(),
            'vehicle_plate': _vehiclePlateController.text.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      if (mounted) setState(() => _saveMessage = 'Account details saved.');
    } catch (error) {
      debugPrint('Error saving driver account: $error');
      if (mounted) {
        setState(() => _saveMessage = 'Could not save account details.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.surface,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.secondary,
        title: Text(
          'Account',
          style: TRYPTypography.headingSmall.copyWith(fontSize: 20),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TRYPColors.primary),
            )
          : SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    _buildAccountHeader(),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Personal details'),
                    const SizedBox(height: 12),
                    CustomTextField(
                      label: 'Full name',
                      hint: 'Your legal name',
                      controller: _nameController,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (value) =>
                          value == null || value.trim().length < 3
                          ? 'Enter your full name'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Phone number',
                      hint: 'Your mobile number',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.phone_outlined,
                      validator: (value) =>
                          value == null || value.trim().length < 7
                          ? 'Enter a valid phone number'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Service area'),
                    const SizedBox(height: 8),
                    Text(
                      'Requests are matched only within this area and nearby pickup distance.',
                      style: TRYPTypography.bodySmall.copyWith(
                        color: TRYPColors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: TRYPServiceAreas.byId(_serviceArea)?.id,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Driving service area',
                        prefixIcon: const Icon(Icons.map_outlined),
                        filled: true,
                        fillColor: TRYPColors.lightGrey,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: TRYPServiceAreas.all
                          .map(
                            (area) => DropdownMenuItem<String>(
                              value: area.id,
                              child: Text(area.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _serviceArea = value),
                      validator: (value) => value == null
                          ? 'Select your driving service area'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'Primary operating town / area',
                      hint: 'e.g. Phalaborwa or The Oaks',
                      controller: _operatingCityController,
                      prefixIcon: Icons.location_on_outlined,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your primary operating area'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Vehicle details'),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: 'Make',
                            hint: 'Toyota',
                            controller: _vehicleMakeController,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            label: 'Model',
                            hint: 'Corolla',
                            controller: _vehicleModelController,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      label: 'License plate',
                      hint: 'Vehicle registration',
                      controller: _vehiclePlateController,
                      prefixIcon: Icons.directions_car_outlined,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter your license plate'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    if (_saveMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _saveMessage!,
                          style: TextStyle(
                            color: _saveMessage!.startsWith('Account')
                                ? TRYPColors.primary
                                : TRYPColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    PrimaryButton(
                      label: 'Save account details',
                      icon: Icons.save_outlined,
                      onPressed: _saveProfile,
                      isLoading: _isSaving,
                      enabled: !_isSaving,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => context.go(Routes.driverOnboarding),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Manage verification documents'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TRYPColors.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: TRYPColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: const DriverBottomNavBar(currentIndex: 5),
    );
  }

  Widget _buildAccountHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TRYPColors.secondary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TRYPColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Image.asset(
              'assets/images/tryp-logo-green.png',
              fit: BoxFit.contain,
              semanticLabel: 'TRYP Driver logo',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              _nameController.text.isEmpty
                  ? 'Driver account'
                  : _nameController.text,
              style: TRYPTypography.titleLarge.copyWith(
                color: TRYPColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
    );
  }
}
