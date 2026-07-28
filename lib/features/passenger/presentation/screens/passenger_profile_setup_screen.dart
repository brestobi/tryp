import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class PassengerProfileSetupScreen extends ConsumerStatefulWidget {
  const PassengerProfileSetupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<PassengerProfileSetupScreen> createState() =>
      _PassengerProfileSetupScreenState();
}

class _PassengerProfileSetupScreenState
    extends ConsumerState<PassengerProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _homeAddressController = TextEditingController();
  final _workAddressController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  
  String _preferredPayment = 'Cash';
  bool _isLoading = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _prefillFromAuth();
  }

  void _prefillFromAuth() {
    try {
      final user = ref.read(supabaseClientProvider).auth.currentUser;
      if (user != null) {
        final metaName = user.userMetadata?['full_name'] as String?;
        if (metaName != null && metaName.isNotEmpty) {
          _nameController.text = metaName;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _homeAddressController.dispose();
    _workAddressController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

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
          'emergency_contact_name': _emergencyNameController.text.trim(),
          'emergency_contact_phone': _emergencyPhoneController.text.trim(),
          'preferred_payment': _preferredPayment,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error saving setup profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        context.go(Routes.passengerHome);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TRYPColors.white,
      appBar: AppBar(
        backgroundColor: TRYPColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TRYPColors.secondary),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.go(Routes.roleSelection);
            }
          },
        ),
        title: Text(
          'Complete Your Profile',
          style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go(Routes.passengerHome),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Step Progress Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    _StepIndicator(step: 0, currentStep: _currentStep, label: 'Personal'),
                    const Expanded(child: Divider(thickness: 2, height: 1)),
                    _StepIndicator(step: 1, currentStep: _currentStep, label: 'Places'),
                    const Expanded(child: Divider(thickness: 2, height: 1)),
                    _StepIndicator(step: 2, currentStep: _currentStep, label: 'Safety'),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildCurrentStepContent(),
                  ),
                ),
              ),

              // Bottom Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: PrimaryButton(
                  label: _currentStep == 2 ? 'Finish & Start Riding' : 'Continue',
                  onPressed: () {
                    if (_currentStep < 2) {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _currentStep++);
                      }
                    } else {
                      _saveAndContinue();
                    }
                  },
                  isLoading: _isLoading,
                  enabled: !_isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Details',
              style: TRYPTypography.headingLarge.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 6),
            Text(
              'Let drivers know who they are picking up.',
              style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              label: 'Full Name',
              hint: 'e.g. Sipho Nkosi',
              controller: _nameController,
              prefixIcon: Icons.person_outline_rounded,
              validator: (v) => (v == null || v.isEmpty) ? 'Full name is required' : null,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Phone Number',
              hint: 'e.g. +27 82 123 4567',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              validator: (v) => (v == null || v.isEmpty) ? 'Phone number is required' : null,
            ),
            const SizedBox(height: 20),
            Text(
              'Preferred Payment Method',
              style: TRYPTypography.labelLarge,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _PaymentChip(
                  title: 'Cash',
                  icon: Icons.money_rounded,
                  selected: _preferredPayment == 'Cash',
                  onTap: () => setState(() => _preferredPayment = 'Cash'),
                ),
                const SizedBox(width: 10),
                _PaymentChip(
                  title: 'Card / Paystack',
                  icon: Icons.credit_card_rounded,
                  selected: _preferredPayment == 'Card',
                  onTap: () => setState(() => _preferredPayment = 'Card'),
                ),
              ],
            ),
          ],
        );

      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Locations',
              style: TRYPTypography.headingLarge.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 6),
            Text(
              'Add your frequent spots for one-tap booking.',
              style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              label: 'Home Address',
              hint: 'e.g. 123 Main Street, Sandton',
              controller: _homeAddressController,
              prefixIcon: Icons.home_outlined,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Work Address',
              hint: 'e.g. 456 Office Park, Rosebank',
              controller: _workAddressController,
              prefixIcon: Icons.work_outline,
            ),
          ],
        );

      case 2:
      default:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Contact',
              style: TRYPTypography.headingLarge.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 6),
            Text(
              'Share live ride status with trusted contacts for safety.',
              style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
            ),
            const SizedBox(height: 24),
            CustomTextField(
              label: 'Contact Name',
              hint: 'e.g. Sarah (Spouse / Parent)',
              controller: _emergencyNameController,
              prefixIcon: Icons.contact_phone_outlined,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              label: 'Contact Phone',
              hint: 'e.g. +27 71 987 6543',
              controller: _emergencyPhoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_iphone_rounded,
            ),
          ],
        );
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  final int currentStep;
  final String label;

  const _StepIndicator({
    required this.step,
    required this.currentStep,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = step <= currentStep;
    return Column(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: isActive ? TRYPColors.primary : TRYPColors.lightGrey,
          child: Text(
            '${step + 1}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isActive ? TRYPColors.secondary : TRYPColors.grey,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TRYPTypography.bodySmall.copyWith(
            color: isActive ? TRYPColors.secondary : TRYPColors.grey,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _PaymentChip extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentChip({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? TRYPColors.primary.withValues(alpha: 0.2) : TRYPColors.lightGrey,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? TRYPColors.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: TRYPColors.secondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TRYPTypography.bodyMedium.copyWith(
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
