import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tryp_driver/app/router.dart';
import 'package:tryp_driver/app/theme.dart';
import 'package:tryp_driver/core/services/document_storage_service.dart';
import 'package:tryp_driver/core/widgets/common_widgets.dart';
import 'package:tryp_driver/features/driver/data/repositories/driver_onboarding_repository.dart';
import 'package:tryp_driver/features/driver/presentation/screens/live_selfie_screen.dart';
import 'package:tryp_driver/core/utils/validators.dart';
import 'package:tryp_driver/features/driver/domain/models/driver_onboarding_config.dart';

class DriverOnboardingScreen extends ConsumerStatefulWidget {
  const DriverOnboardingScreen({super.key});

  @override
  ConsumerState<DriverOnboardingScreen> createState() =>
      _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState
    extends ConsumerState<DriverOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSubmitting = false;
  String? _uploadingDocKey;

  // Controllers for Step 1: Personal Details
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _idNumberController;
  late final TextEditingController _licenseNumberController;
  String _selectedCity = DriverOnboardingConfig.operatingCities.first;

  // Controllers for Step 2: Vehicle Details
  late final TextEditingController _vehicleMakeController;
  late final TextEditingController _vehicleModelController;
  late final TextEditingController _vehicleYearController;
  late final TextEditingController _vehicleColorController;
  late final TextEditingController _vehiclePlateController;
  String _selectedVehicleCategory =
      DriverOnboardingConfig.vehicleCategories.first.id;

  // Controllers for Step 3: Bank Payouts
  String _selectedBank = DriverOnboardingConfig.supportedBanks.first.name;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _branchCodeController;
  late final TextEditingController _accountHolderController;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _idNumberController = TextEditingController();
    _licenseNumberController = TextEditingController();

    _vehicleMakeController = TextEditingController();
    _vehicleModelController = TextEditingController();
    _vehicleYearController = TextEditingController();
    _vehicleColorController = TextEditingController();
    _vehiclePlateController = TextEditingController();

    _accountNumberController = TextEditingController();
    _branchCodeController = TextEditingController(
      text: DriverOnboardingConfig.supportedBanks.first.defaultBranchCode,
    );
    _accountHolderController = TextEditingController();
  }

  void _populateFromData(DriverOnboardingData data) {
    if (_isInitialized) return;
    _isInitialized = true;

    if (data.fullName.isNotEmpty) _fullNameController.text = data.fullName;
    if (data.phone.isNotEmpty) _phoneController.text = data.phone;
    if (data.idNumber.isNotEmpty) _idNumberController.text = data.idNumber;
    if (data.licenseNumber.isNotEmpty)
      _licenseNumberController.text = data.licenseNumber;
    if (data.operatingCity.isNotEmpty &&
        DriverOnboardingConfig.operatingCities.contains(data.operatingCity)) {
      _selectedCity = data.operatingCity;
    }

    if (data.vehicleMake.isNotEmpty)
      _vehicleMakeController.text = data.vehicleMake;
    if (data.vehicleModel.isNotEmpty)
      _vehicleModelController.text = data.vehicleModel;
    if (data.vehicleYear.isNotEmpty)
      _vehicleYearController.text = data.vehicleYear;
    if (data.vehicleColor.isNotEmpty)
      _vehicleColorController.text = data.vehicleColor;
    if (data.vehiclePlate.isNotEmpty)
      _vehiclePlateController.text = data.vehiclePlate;
    if (data.vehicleCategory.isNotEmpty &&
        DriverOnboardingConfig.vehicleCategories.any(
          (c) => c.id == data.vehicleCategory,
        )) {
      _selectedVehicleCategory = data.vehicleCategory;
    }

    if (data.bankName.isNotEmpty &&
        DriverOnboardingConfig.supportedBanks.any(
          (b) => b.name == data.bankName,
        )) {
      _selectedBank = data.bankName;
    }
    if (data.bankAccountNumber.isNotEmpty)
      _accountNumberController.text = data.bankAccountNumber;
    if (data.bankBranchCode.isNotEmpty) {
      _branchCodeController.text = data.bankBranchCode;
    } else {
      final bank = DriverOnboardingConfig.supportedBanks.firstWhere(
        (b) => b.name == _selectedBank,
        orElse: () => DriverOnboardingConfig.supportedBanks.first,
      );
      _branchCodeController.text = bank.defaultBranchCode;
    }
    if (data.bankAccountHolder.isNotEmpty)
      _accountHolderController.text = data.bankAccountHolder;

    // Auto-advance step if user has completed earlier steps
    if (data.driverStatus == DriverVerificationStatus.underReview ||
        data.driverStatus == DriverVerificationStatus.approved ||
        data.driverStatus == DriverVerificationStatus.rejected) {
      _currentStep = 4; // Review / Status View
    } else if (data.isPersonalDetailsComplete &&
        data.isVehicleDetailsComplete &&
        data.isBankDetailsComplete) {
      _currentStep = 3; // Documents Step
    }
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

  Future<void> _saveCurrentStepData() async {
    final notifier = ref.read(driverOnboardingStateProvider.notifier);
    if (_currentStep == 0) {
      await notifier.updatePersonalDetails(
        fullName: _fullNameController.text.trim(),
        phone: _phoneController.text.trim(),
        idNumber: _idNumberController.text.trim(),
        licenseNumber: _licenseNumberController.text.trim(),
        operatingCity: _selectedCity,
      );
    } else if (_currentStep == 1) {
      await notifier.updateVehicleDetails(
        make: _vehicleMakeController.text.trim(),
        model: _vehicleModelController.text.trim(),
        year: _vehicleYearController.text.trim(),
        color: _vehicleColorController.text.trim(),
        plate: _vehiclePlateController.text.trim(),
        category: _selectedVehicleCategory,
      );
    } else if (_currentStep == 2) {
      await notifier.updateBankDetails(
        bankName: _selectedBank,
        accountNumber: _accountNumberController.text.trim(),
        branchCode: _branchCodeController.text.trim(),
        accountHolder: _accountHolderController.text.trim(),
      );
    }
  }

  Future<void> _submitApplication() async {
    final state = ref.read(driverOnboardingStateProvider).value;
    if (state == null) return;

    if (!state.areAllDocumentsUploaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Please upload all required driver verification documents before submitting.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _saveCurrentStepData();
      final success = await ref
          .read(driverOnboardingStateProvider.notifier)
          .submitApplication();

      if (!mounted) return;
      if (success) {
        setState(() {
          _currentStep = 4; // Move to Status Dashboard
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 Application submitted successfully for admin review!',
            ),
            backgroundColor: TRYPColors.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '❌ Submission failed. Please check network connection and try again.',
            ),
            backgroundColor: TRYPColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickAndUploadDocument(RequiredDocumentType doc) async {
    final storageService = ref.read(documentStorageServiceProvider);

    if (doc.key == 'selfie') {
      final selfie = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(builder: (_) => const LiveSelfieScreen()),
      );
      if (selfie == null) return;
      await _uploadSelectedDocument(doc, selfie);
      return;
    }

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
            Text(
              'Upload ${doc.title}',
              style: TRYPTypography.headingMedium.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              doc.requirement,
              style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
            ),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: TRYPColors.inputFill,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TRYPColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: TRYPColors.secondary,
                  size: 20,
                ),
              ),
              title: Text(
                'Take Photo with Camera',
                style: TRYPTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: TRYPColors.inputFill,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TRYPColors.secondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: TRYPColors.white,
                  size: 20,
                ),
              ),
              title: Text(
                'Choose from Photo Gallery',
                style: TRYPTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
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

    await _uploadSelectedDocument(doc, image);
  }

  Future<void> _uploadSelectedDocument(
    RequiredDocumentType doc,
    XFile image,
  ) async {
    setState(() => _uploadingDocKey = doc.key);

    try {
      final success = await ref
          .read(driverOnboardingStateProvider.notifier)
          .uploadDocument(doc.key, image);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? '${doc.title} uploaded successfully.'
                : 'Failed to upload ${doc.title}. Please try again.',
          ),
          backgroundColor: success ? TRYPColors.primary : TRYPColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingDocKey = null);
    }
  }

  void _viewDocumentImage(String title, String? url) {
    if (url == null || url.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TRYPColors.secondary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_rounded,
                    color: TRYPColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TRYPTypography.titleLarge.copyWith(
                        color: TRYPColors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: TRYPColors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 260,
                    color: TRYPColors.inputFill,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: TRYPColors.primary,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220,
                  width: double.infinity,
                  color: TRYPColors.inputFill,
                  child: const Center(
                    child: Text(
                      'Image preview unavailable',
                      style: TextStyle(color: TRYPColors.grey),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onboardingAsync = ref.watch(driverOnboardingStateProvider);

    return Scaffold(
      backgroundColor: TRYPColors.primary,
      appBar: AppBar(
        backgroundColor: TRYPColors.primary,
        foregroundColor: TRYPColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TRYPColors.white),
          onPressed: () {
            if (_currentStep > 0 && _currentStep < 4) {
              setState(() => _currentStep--);
            } else {
              context.go(Routes.onboarding);
            }
          },
        ),
        title: Text(
          'Driver Verification Onboarding',
          style: TRYPTypography.headingSmall.copyWith(
            fontSize: 18,
            color: TRYPColors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: TRYPColors.white),
            onPressed: () =>
                ref.read(driverOnboardingStateProvider.notifier).loadData(),
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: onboardingAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: TRYPColors.white),
              SizedBox(height: 16),
              Text(
                'Loading driver profile & verification details...',
                style: TextStyle(color: TRYPColors.secondaryLight),
              ),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: TRYPColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading verification state',
                  style: TRYPTypography.headingSmall.copyWith(
                    color: TRYPColors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: TRYPColors.secondaryLight),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Retry Loading',
                  onPressed: () => ref
                      .read(driverOnboardingStateProvider.notifier)
                      .loadData(),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          _populateFromData(data);

          return SafeArea(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Step Navigation Header
                  if (_currentStep < 4) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          _StepDot(
                            step: 0,
                            currentStep: _currentStep,
                            label: 'Personal',
                          ),
                          const Expanded(
                            child: Divider(thickness: 2, height: 1),
                          ),
                          _StepDot(
                            step: 1,
                            currentStep: _currentStep,
                            label: 'Vehicle',
                          ),
                          const Expanded(
                            child: Divider(thickness: 2, height: 1),
                          ),
                          _StepDot(
                            step: 2,
                            currentStep: _currentStep,
                            label: 'Payouts',
                          ),
                          const Expanded(
                            child: Divider(thickness: 2, height: 1),
                          ),
                          _StepDot(
                            step: 3,
                            currentStep: _currentStep,
                            label: 'Verify',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],

                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                      decoration: const BoxDecoration(
                        color: TRYPColors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: _buildStepView(data),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  if (_currentStep < 4)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: PrimaryButton(
                        label: _currentStep == 3
                            ? 'Submit Verification Application'
                            : 'Next Step',
                        isLoading: _isSubmitting,
                        enabled: !_isSubmitting,
                        onPressed: () async {
                          if (_currentStep < 3) {
                            if (_formKey.currentState!.validate()) {
                              await _saveCurrentStepData();
                              setState(() => _currentStep++);
                            }
                          } else {
                            await _submitApplication();
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepView(DriverOnboardingData data) {
    switch (_currentStep) {
      case 0:
        return _buildPersonalStep();
      case 1:
        return _buildVehicleStep();
      case 2:
        return _buildBankStep();
      case 3:
        return _buildDocumentsStep(data);
      case 4:
      default:
        return _buildStatusDashboard(data);
    }
  }

  // ── STEP 1: Personal & License Details ────────────────────────────
  Widget _buildPersonalStep() {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal & License Info',
          style: TRYPTypography.headingLarge.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter your identity details for South African driving license verification.',
          style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
        ),
        const SizedBox(height: 24),

        CustomTextField(
          label: 'Full Legal Name',
          hint: 'Enter as shown on SA ID',
          controller: _fullNameController,
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÿ\s'-]")),
            LengthLimitingTextInputFormatter(80),
          ],
          validator: (v) => (v == null || v.trim().length < 3)
              ? 'Enter your full legal name'
              : null,
        ),
        const SizedBox(height: 14),

        CustomTextField(
          label: 'Phone Number',
          hint: 'Mobile number with area code',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: Icons.phone_outlined,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s().-]')),
            LengthLimitingTextInputFormatter(16),
          ],
          validator: (v) => v == null || !Validators.isValidPhone(v)
              ? 'Enter a valid phone number'
              : null,
        ),
        const SizedBox(height: 14),

        CustomTextField(
          label: 'SA ID / Passport Number',
          hint: '13-digit SA ID or passport',
          controller: _idNumberController,
          keyboardType: TextInputType.text,
          prefixIcon: Icons.badge_outlined,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
            UpperCaseTextFormatter(),
            LengthLimitingTextInputFormatter(20),
          ],
          validator: (v) => v == null || !Validators.isValidIdOrPassport(v)
              ? 'Enter a valid 13-digit ID or passport number'
              : null,
        ),
        const SizedBox(height: 14),

        CustomTextField(
          label: 'Driving License Number (PrDP)',
          hint: 'PrDP license card number',
          controller: _licenseNumberController,
          prefixIcon: Icons.card_membership_rounded,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-/]')),
            UpperCaseTextFormatter(),
            LengthLimitingTextInputFormatter(20),
          ],
          validator: (v) => v == null || !Validators.isValidLicenseNumber(v)
              ? 'Enter a valid license number'
              : null,
        ),
        const SizedBox(height: 16),

        Text('Primary Operating City / Area', style: TRYPTypography.labelLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: DriverOnboardingConfig.operatingCities.contains(_selectedCity)
              ? _selectedCity
              : DriverOnboardingConfig.operatingCities.first,
          decoration: InputDecoration(
            fillColor: TRYPColors.lightGrey,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (value) => value == null || value.isEmpty
              ? 'Select an operating area'
              : null,
          items: DriverOnboardingConfig.operatingCities
              .map((city) => DropdownMenuItem(value: city, child: Text(city)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedCity = val);
          },
        ),
      ],
    );
  }

  // ── STEP 2: Vehicle Information ──────────────────────────────────
  Widget _buildVehicleStep() {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vehicle Details',
          style: TRYPTypography.headingLarge.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          'Enter vehicle specs to match with passengers.',
          style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: CustomTextField(
                label: 'Make',
                hint: 'e.g. Toyota',
                controller: _vehicleMakeController,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9 &'-]")),
                  LengthLimitingTextInputFormatter(30),
                ],
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter vehicle make'
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomTextField(
                label: 'Model',
                hint: 'e.g. Corolla Quest',
                controller: _vehicleModelController,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9 &'-]")),
                  LengthLimitingTextInputFormatter(40),
                ],
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter vehicle model'
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Year',
                value:
                    DriverOnboardingConfig.vehicleYears.contains(
                      _vehicleYearController.text,
                    )
                    ? _vehicleYearController.text
                    : null,
                items: DriverOnboardingConfig.vehicleYears,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _vehicleYearController.text = value);
                  }
                },
                validator: (value) =>
                    value == null || value.isEmpty ? 'Select year' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdownField<String>(
                label: 'Color',
                value:
                    DriverOnboardingConfig.vehicleColors.contains(
                      _vehicleColorController.text,
                    )
                    ? _vehicleColorController.text
                    : null,
                items: DriverOnboardingConfig.vehicleColors,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _vehicleColorController.text = value);
                  }
                },
                validator: (value) =>
                    value == null || value.isEmpty ? 'Select color' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        CustomTextField(
          label: 'License Plate Number',
          hint: 'e.g. GP / KZN / CA Registration',
          controller: _vehiclePlateController,
          prefixIcon: Icons.directions_car_filled_rounded,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s-]')),
            UpperCaseTextFormatter(),
            LengthLimitingTextInputFormatter(12),
          ],
          validator: (v) => v == null || !Validators.isValidVehiclePlate(v)
              ? 'Enter a valid license plate'
              : null,
        ),
        const SizedBox(height: 20),

        Text('Select Vehicle Category Tier', style: TRYPTypography.labelLarge),
        const SizedBox(height: 12),

        ...DriverOnboardingConfig.vehicleCategories.map((cat) {
          final isSelected = _selectedVehicleCategory == cat.id;
          return GestureDetector(
            onTap: () => setState(() => _selectedVehicleCategory = cat.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? TRYPColors.primary.withValues(alpha: 0.08)
                    : TRYPColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? TRYPColors.primary : TRYPColors.divider,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? TRYPColors.primary
                          : TRYPColors.lightGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      cat.icon,
                      color: isSelected ? TRYPColors.white : TRYPColors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              cat.name,
                              style: TRYPTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: TRYPColors.lightGrey,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${cat.capacity} seats',
                                style: TRYPTypography.labelSmall.copyWith(
                                  fontSize: 10,
                                  color: TRYPColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cat.description,
                          style: TRYPTypography.bodySmall.copyWith(
                            color: TRYPColors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Radio<String>(
                    value: cat.id,
                    groupValue: _selectedVehicleCategory,
                    activeColor: TRYPColors.secondary,
                    onChanged: (val) {
                      if (val != null)
                        setState(() => _selectedVehicleCategory = val);
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── STEP 3: Bank Payout Details ──────────────────────────────────
  Widget _buildBankStep() {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bank Payout Details',
          style: TRYPTypography.headingLarge.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          'Receive daily trip earnings directly to your South African bank account.',
          style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
        ),
        const SizedBox(height: 24),

        Text('Select Bank', style: TRYPTypography.labelLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value:
              DriverOnboardingConfig.supportedBanks.any(
                (b) => b.name == _selectedBank,
              )
              ? _selectedBank
              : DriverOnboardingConfig.supportedBanks.first.name,
          decoration: InputDecoration(
            fillColor: TRYPColors.lightGrey,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          validator: (value) =>
              value == null || value.isEmpty ? 'Select your bank' : null,
          items: DriverOnboardingConfig.supportedBanks
              .map(
                (bank) =>
                    DropdownMenuItem(value: bank.name, child: Text(bank.name)),
              )
              .toList(),
          onChanged: (val) {
            if (val != null) {
              final bankObj = DriverOnboardingConfig.supportedBanks.firstWhere(
                (b) => b.name == val,
                orElse: () => DriverOnboardingConfig.supportedBanks.first,
              );
              setState(() {
                _selectedBank = val;
                _branchCodeController.text = bankObj.defaultBranchCode;
              });
            }
          },
        ),
        const SizedBox(height: 14),

        CustomTextField(
          label: 'Account Holder Name',
          hint: 'Full name registered with bank',
          controller: _accountHolderController,
          textCapitalization: TextCapitalization.words,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r"[a-zA-ZÀ-ÿ\s'-]")),
            LengthLimitingTextInputFormatter(80),
          ],
          validator: (v) => (v == null || v.trim().length < 3)
              ? 'Enter the account holder name'
              : null,
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              flex: 2,
              child: CustomTextField(
                label: 'Account Number',
                hint: 'Bank account number',
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(14),
                ],
                validator: (v) =>
                    v == null || !Validators.isValidAccountNumber(v)
                    ? 'Enter a valid account number'
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: CustomTextField(
                label: 'Branch Code',
                hint: 'Branch code',
                controller: _branchCodeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (v) => v == null || !Validators.isValidBranchCode(v)
                    ? 'Use 6 digits'
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String? Function(T?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TRYPTypography.labelLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            fillColor: TRYPColors.lightGrey,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(item.toString()),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }

  // ── STEP 4: Required Documents Upload ──────────────────────────────
  Widget _buildDocumentsStep(DriverOnboardingData data) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verification Documents',
          style: TRYPTypography.headingLarge.copyWith(fontSize: 22),
        ),
        const SizedBox(height: 4),
        Text(
          'Upload clear photo scans of all required South African transport compliance documents.',
          style: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
        ),
        const SizedBox(height: 24),

        ...DriverOnboardingConfig.requiredDocuments.map((doc) {
          final url = data.documentUrls[doc.key];
          final status =
              data.documentStatuses[doc.key] ??
              (url != null ? 'pending' : 'not_uploaded');
          final isUploadingThis = _uploadingDocKey == doc.key;
          final hasFile = url != null && url.isNotEmpty;

          Color borderCol = TRYPColors.divider;
          Color statusBg = TRYPColors.lightGrey;
          Color statusFg = TRYPColors.grey;
          String statusLabel = 'Not Uploaded';
          IconData statusIcon = Icons.cloud_upload_outlined;

          if (status == 'approved') {
            borderCol = TRYPColors.primary.withValues(alpha: 0.4);
            statusBg = TRYPColors.primary.withValues(alpha: 0.12);
            statusFg = TRYPColors.primary;
            statusLabel = 'Verified';
            statusIcon = Icons.check_circle_rounded;
          } else if (status == 'action_required' || status == 'rejected') {
            borderCol = TRYPColors.error;
            statusBg = TRYPColors.error.withValues(alpha: 0.12);
            statusFg = TRYPColors.error;
            statusLabel = 'Action Needed';
            statusIcon = Icons.error_rounded;
          } else if (status == 'pending' || hasFile) {
            borderCol = Colors.orange.withValues(alpha: 0.4);
            statusBg = Colors.orange.withValues(alpha: 0.12);
            statusFg = Colors.orange;
            statusLabel = 'Under Review';
            statusIcon = Icons.hourglass_empty_rounded;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: TRYPColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TRYPColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        doc.icon,
                        color: TRYPColors.secondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.title,
                            style: TRYPTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            doc.description,
                            style: TRYPTypography.bodySmall.copyWith(
                              color: TRYPColors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusFg),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusFg,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  doc.requirement,
                  style: TRYPTypography.bodySmall.copyWith(
                    color: TRYPColors.secondary.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 16),

                if (isUploadingThis)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: TRYPColors.secondary,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Uploading scan to Supabase Storage...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      if (hasFile) ...[
                        OutlinedButton.icon(
                          onPressed: () => _viewDocumentImage(doc.title, url),
                          icon: const Icon(
                            Icons.remove_red_eye_rounded,
                            size: 16,
                          ),
                          label: const Text('View'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _pickAndUploadDocument(doc),
                          icon: Icon(
                            hasFile
                                ? Icons.refresh_rounded
                                : Icons.file_upload_outlined,
                            size: 16,
                          ),
                          label: Text(
                            hasFile ? 'Replace Photo' : 'Upload Document',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasFile
                                ? TRYPColors.inputFill
                                : TRYPColors.secondary,
                            foregroundColor: hasFile
                                ? TRYPColors.secondary
                                : TRYPColors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: TRYPTypography.labelMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ── STEP 5: Verification Status Dashboard View ───────────────────────
  Widget _buildStatusDashboard(DriverOnboardingData data) {
    final isApproved = data.driverStatus == DriverVerificationStatus.approved;
    final isRejected = data.driverStatus == DriverVerificationStatus.rejected;

    Color badgeBg = isApproved
        ? TRYPColors.primary
        : (isRejected ? TRYPColors.error : Colors.orange);
    String statusTitle = isApproved
        ? 'Verification Approved! 🎉'
        : (isRejected
              ? 'Application Needs Action'
              : 'Application Under Review');
    String statusSubtitle = isApproved
        ? 'Your driver credentials and vehicle documents have been verified. You can now go online and accept ride requests!'
        : (isRejected
              ? 'Our safety team reviewed your submission and flagged items that need correction before approval.'
              : 'Your credentials and vehicle documents are currently under review by our TRYP safety team. Verification takes 24–48 hours.');

    return Column(
      key: const ValueKey(4),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Hero Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: TRYPColors.secondary,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: badgeBg.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isApproved
                      ? Icons.verified_user_rounded
                      : (isRejected
                            ? Icons.warning_amber_rounded
                            : Icons.hourglass_empty_rounded),
                  color: isApproved
                      ? TRYPColors.primary
                      : (isRejected ? Colors.red : TRYPColors.white),
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                statusTitle,
                style: TRYPTypography.headingMedium.copyWith(
                  color: TRYPColors.white,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                statusSubtitle,
                style: TRYPTypography.bodySmall.copyWith(
                  color: TRYPColors.secondaryLight,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Summary Card
        Text(
          'Application Summary',
          style: TRYPTypography.headingSmall.copyWith(fontSize: 18),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: TRYPColors.inputFill,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              _SummaryRow(
                label: 'Full Name',
                value: data.fullName.isEmpty ? 'Not Provided' : data.fullName,
              ),
              const Divider(height: 20),
              _SummaryRow(label: 'Operating Area', value: data.operatingCity),
              const Divider(height: 20),
              _SummaryRow(
                label: 'Vehicle Specs',
                value: data.vehicleMake.isEmpty
                    ? 'Not Provided'
                    : '${data.vehicleMake} ${data.vehicleModel} (${data.vehiclePlate})',
              ),
              const Divider(height: 20),
              _SummaryRow(label: 'Category Tier', value: data.vehicleCategory),
              const Divider(height: 20),
              _SummaryRow(label: 'Payout Bank', value: data.bankName),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Actions Row
        if (isApproved)
          PrimaryButton(
            label: 'Enter Driver Portal & Go Online',
            onPressed: () => context.go(Routes.driverHome),
          )
        else ...[
          PrimaryButton(
            label: 'Edit Info / Update Documents',
            onPressed: () => setState(() => _currentStep = 0),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.go(Routes.driverHome),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Return to Driver Portal'),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int step;
  final int currentStep;
  final String label;

  const _StepDot({
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
          backgroundColor: isActive ? TRYPColors.accent : TRYPColors.lightGrey,
          child: Text(
            '${step + 1}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? TRYPColors.white : TRYPColors.grey,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TRYPTypography.bodySmall.copyWith(
            color: isActive ? TRYPColors.white : TRYPColors.grey,
            fontSize: 9,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TRYPTypography.bodySmall.copyWith(color: TRYPColors.grey),
        ),
        Flexible(
          child: Text(
            value,
            style: TRYPTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
