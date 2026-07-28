import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class PassengerProfileScreen extends ConsumerStatefulWidget {
  const PassengerProfileScreen({super.key});

  @override
  ConsumerState<PassengerProfileScreen> createState() => _PassengerProfileScreenState();
}

class _PassengerProfileScreenState extends ConsumerState<PassengerProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _homeAddressController = TextEditingController();
  final _workAddressController = TextEditingController();
  final _emergencyContactController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _pinVerificationEnabled = false;
  bool _shareTripEnabled = true;
  double _walletBalance = 150.00;
  double _userRating = 4.9;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _homeAddressController.dispose();
    _workAddressController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user != null) {
        final data = await client.from('profiles').select().eq('id', user.id).maybeSingle();
        setState(() {
          _nameController.text = data?['full_name'] ?? 'Sipho Nkosi';
          _emailController.text = data?['email'] ?? user.email ?? 'sipho@example.com';
          _phoneController.text = data?['phone_number'] ?? '+27 82 123 4567';
          _homeAddressController.text = data?['home_address'] ?? '123 Main Street, Sandton';
          _workAddressController.text = data?['work_address'] ?? '456 Office Park, Rosebank';
          _emergencyContactController.text = data?['emergency_contact_phone'] ?? '+27 71 987 6543';
        });
      } else {
        _setDefaults();
      }
    } catch (_) {
      _setDefaults();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setDefaults() {
    setState(() {
      _nameController.text = 'Sipho Nkosi';
      _emailController.text = 'passenger@tryp.app';
      _phoneController.text = '+27 82 123 4567';
      _homeAddressController.text = '123 Main Street, Sandton';
      _workAddressController.text = '456 Office Park, Rosebank';
      _emergencyContactController.text = '+27 71 987 6543';
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user != null) {
        await client.from('profiles').upsert({
          'id': user.id,
          'full_name': _nameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'home_address': _homeAddressController.text.trim(),
          'work_address': _workAddressController.text.trim(),
          'emergency_contact_phone': _emergencyContactController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
    } catch (_) {}
    if (mounted) {
      context.go(Routes.login);
    }
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
          onPressed: () => context.go(Routes.passengerHome),
        ),
        title: Text('Account & Profile', style: TRYPTypography.headingSmall.copyWith(fontSize: 18)),
        actions: [
          IconButton(
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
            icon: Icon(_isEditing ? Icons.check_circle_rounded : Icons.edit_rounded, color: TRYPColors.primary),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TRYPColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Header Card
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            const CircleAvatar(
                              radius: 46,
                              backgroundColor: TRYPColors.primary,
                              child: Icon(Icons.person_rounded, size: 54, color: TRYPColors.secondary),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: TRYPColors.secondary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 14, color: TRYPColors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _nameController.text,
                          style: TRYPTypography.headingMedium.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: TRYPColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 14, color: TRYPColors.secondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_userRating ★ Gold Member',
                                    style: TRYPTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.bold,
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
                  ),

                  const SizedBox(height: 24),

                  // Wallet Balance Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: TRYPColors.secondary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TRYP Wallet Balance',
                              style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'R${_walletBalance.toStringAsFixed(2)}',
                              style: TRYPTypography.headingMedium.copyWith(color: TRYPColors.primary),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Wallet Top Up powered by Paystack')),
                            );
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Top Up'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TRYPColors.primary,
                            foregroundColor: TRYPColors.secondary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Personal Info Section
                  _SectionHeader(title: 'Personal Info', isEditing: _isEditing),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    prefixIcon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Email',
                    controller: _emailController,
                    prefixIcon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    prefixIcon: Icons.phone_outlined,
                  ),

                  const SizedBox(height: 24),

                  // Saved Places Section
                  _SectionHeader(title: 'Saved Places', isEditing: _isEditing),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Home Address',
                    controller: _homeAddressController,
                    prefixIcon: Icons.home_outlined,
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    label: 'Work Address',
                    controller: _workAddressController,
                    prefixIcon: Icons.work_outline,
                  ),

                  const SizedBox(height: 24),

                  // Safety & Security
                  Text('Safety & Security', style: TRYPTypography.headingSmall.copyWith(fontSize: 16)),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: TRYPColors.lightGrey,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          activeTrackColor: TRYPColors.primary,
                          title: const Text('PIN Verification'),
                          subtitle: const Text('Require 4-digit PIN before ride starts'),
                          value: _pinVerificationEnabled,
                          onChanged: (val) => setState(() => _pinVerificationEnabled = val),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          activeTrackColor: TRYPColors.primary,
                          title: const Text('Share Trip Status'),
                          subtitle: const Text('Auto-share live location with emergency contact'),
                          value: _shareTripEnabled,
                          onChanged: (val) => setState(() => _shareTripEnabled = val),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Become a Driver Promo Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          TRYPColors.secondary,
                          TRYPColors.secondary.withValues(alpha: 0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: TRYPColors.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.time_to_leave_rounded,
                                color: TRYPColors.secondary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Become a TRYP Driver',
                                    style: TRYPTypography.headingSmall.copyWith(
                                      color: TRYPColors.white,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Earn daily with flexible hours',
                                    style: TRYPTypography.bodySmall.copyWith(
                                      color: TRYPColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Drive on your own schedule. Keep your earnings and get payouts directly to your bank.',
                          style: TRYPTypography.bodySmall.copyWith(
                            color: TRYPColors.grey,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.go(Routes.driverOnboarding),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: const Text('Start Driver Onboarding'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TRYPColors.primary,
                              foregroundColor: TRYPColors.secondary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: TRYPTypography.labelLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Shortcuts
                  ListTile(
                    tileColor: TRYPColors.lightGrey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: const Icon(Icons.directions_car_filled_rounded, color: TRYPColors.primary),
                    title: const Text('Become a Driver / Switch Role'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => context.go(Routes.driverOnboarding),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    tileColor: TRYPColors.lightGrey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: const Icon(Icons.history_rounded, color: TRYPColors.primary),
                    title: const Text('Trip History & Receipts'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () => context.go(Routes.passengerActivity),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    tileColor: TRYPColors.lightGrey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: const Icon(Icons.support_agent_rounded, color: TRYPColors.primary),
                    title: const Text('24/7 Safety Support & Help'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contacting TRYP 24/7 Safety Support...')),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Logout Button
                  SecondaryButton(
                    label: 'Log Out',
                    onPressed: _logout,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isEditing;

  const _SectionHeader({required this.title, required this.isEditing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: TRYPTypography.headingSmall.copyWith(fontSize: 16)),
        if (isEditing)
          Text(
            'Editing Enabled',
            style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.primary, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }
}
