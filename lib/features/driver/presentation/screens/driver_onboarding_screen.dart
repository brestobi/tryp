import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/document_storage_service.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends ConsumerState<DriverOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Personal Details
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  String _operatingCity = 'Johannesburg';

  // Step 2: Vehicle Information
  final _vehicleMakeController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  String _vehicleCategory = 'TRYP Go';

  // Step 3: Bank Payout Information
  String _bankName = 'FNB (First National Bank)';
  final _accountNumberController = TextEditingController();
  final _branchCodeController = TextEditingController();
  final _accountHolderController = TextEditingController();

  // Step 4: Documents Status Map
  final Map<String, bool> _uploadedDocuments = {
    'PrDP Driver\'s License': false,
    'Vehicle Registration (RC)': false,
    'Commercial Insurance Cover': false,
    'Roadworthiness Certificate': false,
  };

  @override
  void initState() {
    super.initState();
    _prefillDriverProfile();
  }

  void _prefillDriverProfile() {
    try {
      final user = ref.read(supabaseClientProvider).auth.currentUser;
      if (user != null) {
        final metaName = user.userMetadata?['full_name'] as String?;
        if (metaName != null) _fullNameController.text = metaName;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _idNumberController.dispose();
    _licenseNumberController.dispose();
    _vehicleMakeController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _vehiclePlateController.dispose();
    _accountNumberController.dispose();
    _branchCodeController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _submitDriverRegistration() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;

      if (user != null) {
        await client.from('profiles').upsert({
          'id': user.id,
          'role': 'driver',
          'full_name': _fullNameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'id_number': _idNumberController.text.trim(),
          'license_number': _licenseNumberController.text.trim(),
          'operating_city': _operatingCity,
          'vehicle_make': _vehicleMakeController.text.trim(),
          'vehicle_model': _vehicleModelController.text.trim(),
          'vehicle_year': _vehicleYearController.text.trim(),
          'vehicle_color': _vehicleColorController.text.trim(),
          'vehicle_plate': _vehiclePlateController.text.trim(),
          'vehicle_category': _vehicleCategory,
          'bank_name': _bankName,
          'bank_account_number': _accountNumberController.text.trim(),
          'bank_branch_code': _branchCodeController.text.trim(),
          'bank_account_holder': _accountHolderController.text.trim(),
          'driver_status': 'under_review',
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Error registering driver: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessDialog();
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text('Application Submitted!', style: TRYPTypography.headingSmall.copyWith(fontSize: 18)),
          ],
        ),
        content: Text(
          'Your driver documents and vehicle details are currently under review by our TRYP safety team. Verification takes 24–48 hours.',
          style: TRYPTypography.bodyMedium.copyWith(height: 1.4),
        ),
        actions: [
          PrimaryButton(
            label: 'Go to Driver Portal',
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
          'Driver Onboarding',
          style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Progress Bar Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    _StepItem(step: 0, currentStep: _currentStep, label: 'Personal'),
                    const Expanded(child: Divider(thickness: 2, height: 1)),
                    _StepItem(step: 1, currentStep: _currentStep, label: 'Vehicle'),
                    const Expanded(child: Divider(thickness: 2, height: 1)),
                    _StepItem(step: 2, currentStep: _currentStep, label: 'Payouts'),
                    const Expanded(child: Divider(thickness: 2, height: 1)),
                    _StepItem(step: 3, currentStep: _currentStep, label: 'Documents'),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildStepContent(),
                  ),
                ),
              ),

              // Bottom Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: PrimaryButton(
                  label: _currentStep == 3 ? 'Submit Application' : 'Next Step',
                  onPressed: () {
                    if (_currentStep < 3) {
                      if (_formKey.currentState!.validate()) {
                        setState(() => _currentStep++);
                      }
                    } else {
                      _submitDriverRegistration();
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

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Personal & License Info', style: TRYPTypography.headingLarge.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text('Provide your identity details for safety verification.', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
            const SizedBox(height: 24),
            CustomTextField(
              label: 'Full Legal Name',
              hint: 'e.g. David Khumalo',
              controller: _fullNameController,
              prefixIcon: Icons.person_outline_rounded,
              validator: (v) => (v == null || v.isEmpty) ? 'Full name required' : null,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Phone Number',
              hint: 'e.g. +27 83 987 6543',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              prefixIcon: Icons.phone_outlined,
              validator: (v) => (v == null || v.isEmpty) ? 'Phone number required' : null,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'SA ID / Passport Number',
              hint: 'e.g. 8801015800081',
              controller: _idNumberController,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.badge_outlined,
              validator: (v) => (v == null || v.isEmpty) ? 'ID number required' : null,
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Driving License Number (PrDP)',
              hint: 'e.g. DL982341-ZA',
              controller: _licenseNumberController,
              prefixIcon: Icons.card_membership_rounded,
              validator: (v) => (v == null || v.isEmpty) ? 'License number required' : null,
            ),
            const SizedBox(height: 16),
            Text('Operating City / Area', style: TRYPTypography.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _operatingCity,
              decoration: InputDecoration(
                fillColor: TRYPColors.lightGrey,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              items: ['Johannesburg', 'Pretoria / Tshwane', 'Cape Town', 'Durban / eThekwini', 'Gqeberha']
                  .map((city) => DropdownMenuItem(value: city, child: Text(city)))
                  .toList(),
              onChanged: (val) => setState(() => _operatingCity = val!),
            ),
          ],
        );

      case 1:
        return Column(
          key: const ValueKey(1),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vehicle Details', style: TRYPTypography.headingLarge.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text('Enter vehicle specs to match with passengers.', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Make',
                    hint: 'e.g. Toyota',
                    controller: _vehicleMakeController,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Model',
                    hint: 'e.g. Corolla Quest',
                    controller: _vehicleModelController,
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: 'Year',
                    hint: 'e.g. 2021',
                    controller: _vehicleYearController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomTextField(
                    label: 'Color',
                    hint: 'e.g. Silver',
                    controller: _vehicleColorController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'License Plate Number',
              hint: 'e.g. ND 123-456 / GP',
              controller: _vehiclePlateController,
              prefixIcon: Icons.directions_car_filled_rounded,
              validator: (v) => (v == null || v.isEmpty) ? 'License plate required' : null,
            ),
            const SizedBox(height: 16),
            Text('Vehicle Category Tier', style: TRYPTypography.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _vehicleCategory,
              decoration: InputDecoration(
                fillColor: TRYPColors.lightGrey,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              items: ['TRYP Go', 'TRYP Comfort', 'TRYP XL', 'TRYP Exec']
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                  .toList(),
              onChanged: (val) => setState(() => _vehicleCategory = val!),
            ),
          ],
        );

      case 2:
        return Column(
          key: const ValueKey(2),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bank Payout Details', style: TRYPTypography.headingLarge.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text('Receive your daily trip earnings directly to your bank account.', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
            const SizedBox(height: 24),
            Text('Select Bank', style: TRYPTypography.labelLarge),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _bankName,
              decoration: InputDecoration(
                fillColor: TRYPColors.lightGrey,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
              items: [
                'FNB (First National Bank)',
                'Capitec Bank',
                'Standard Bank',
                'Absa Bank',
                'Nedbank',
                'TymeBank',
                'Discovery Bank',
              ].map((bank) => DropdownMenuItem(value: bank, child: Text(bank))).toList(),
              onChanged: (val) => setState(() => _bankName = val!),
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Account Holder Name',
              hint: 'e.g. D Khumalo',
              controller: _accountHolderController,
              validator: (v) => (v == null || v.isEmpty) ? 'Account holder name required' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: CustomTextField(
                    label: 'Account Number',
                    hint: 'e.g. 62819203910',
                    controller: _accountNumberController,
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.isEmpty) ? 'Account number required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: CustomTextField(
                    label: 'Branch Code',
                    hint: 'e.g. 250655',
                    controller: _branchCodeController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        );

      case 3:
      default:
        return Column(
          key: const ValueKey(3),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Required Documents', style: TRYPTypography.headingLarge.copyWith(fontSize: 22)),
            const SizedBox(height: 4),
            Text('Upload legibly scanned or captured photo documents for safety verification.', style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey)),
            const SizedBox(height: 24),
            ..._uploadedDocuments.keys.map((docName) {
              final isUploaded = _uploadedDocuments[docName]!;
              IconData icon;
              if (docName.contains('PrDP')) {
                icon = Icons.badge_rounded;
              } else if (docName.contains('Vehicle')) {
                icon = Icons.directions_car_rounded;
              } else if (docName.contains('Insurance')) {
                icon = Icons.shield_rounded;
              } else {
                icon = Icons.verified_rounded;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isUploaded ? Colors.green.withValues(alpha: 0.05) : TRYPColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUploaded ? Colors.green.withValues(alpha: 0.4) : TRYPColors.divider,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUploaded ? Colors.green.withValues(alpha: 0.1) : TRYPColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        icon,
                        color: isUploaded ? Colors.green : TRYPColors.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(docName, style: TRYPTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            isUploaded ? 'Document Uploaded • Pending Review' : 'Tap to upload clear scan/photo',
                            style: TRYPTypography.bodySmall.copyWith(
                              color: isUploaded ? Colors.green : TRYPColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _handleDocumentUpload(docName),
                      icon: Icon(isUploaded ? Icons.refresh_rounded : Icons.file_upload_outlined, size: 16),
                      label: Text(isUploaded ? 'Replace' : 'Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isUploaded ? TRYPColors.inputFill : TRYPColors.secondary,
                        foregroundColor: isUploaded ? TRYPColors.secondary : TRYPColors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: TRYPTypography.labelSmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        );
    }
  }

  Future<void> _handleDocumentUpload(String docName) async {
    final storageService = ref.read(documentStorageServiceProvider);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TRYPColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TRYPColors.divider,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Upload $docName', style: TRYPTypography.headingMedium.copyWith(fontSize: 18)),
            const SizedBox(height: 6),
            Text('Ensure document text and details are sharp and fully visible.', style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey)),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: TRYPColors.inputFill,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TRYPColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: TRYPColors.secondary, size: 20),
              ),
              title: Text('Take Photo with Camera', style: TRYPTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: TRYPColors.inputFill,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TRYPColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: TRYPColors.white, size: 20),
              ),
              title: Text('Choose from Photo Gallery', style: TRYPTypography.bodyLarge.copyWith(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (source == null) return;

    final image = await storageService.pickDocumentImage(source: source);
    if (image == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Uploading $docName...'),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    final docKeyMap = {
      'PrDP Driver\'s License': 'prdp',
      'Vehicle Registration (RC)': 'vehicle_registration',
      'Commercial Insurance Cover': 'insurance',
      'Roadworthiness Certificate': 'roadworthiness',
    };
    final docKey = docKeyMap[docName] ?? 'document';

    final url = await storageService.uploadDriverDocument(
      docKey: docKey,
      file: image,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (url != null) {
      setState(() {
        _uploadedDocuments[docName] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ $docName uploaded successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Upload failed for $docName. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _StepItem extends StatelessWidget {
  final int step;
  final int currentStep;
  final String label;

  const _StepItem({
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
          radius: 12,
          backgroundColor: isActive ? TRYPColors.primary : TRYPColors.lightGrey,
          child: Text(
            '${step + 1}',
            style: TextStyle(
              fontSize: 11,
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
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
