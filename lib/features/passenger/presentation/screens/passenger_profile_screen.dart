import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/camera_permission_service.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

bool passengerProfileIsApproved(Map<String, dynamic>? profile) {
  return profile?['passenger_verification_status'] == 'approved';
}

class PassengerProfileScreen extends ConsumerStatefulWidget {
  const PassengerProfileScreen({super.key});

  @override
  ConsumerState<PassengerProfileScreen> createState() =>
      _PassengerProfileScreenState();
}

class _PassengerProfileScreenState
    extends ConsumerState<PassengerProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _homeAddressController = TextEditingController();
  final _workAddressController = TextEditingController();
  final _emergencyContactController = TextEditingController();
  final _emergencyNameController = TextEditingController();

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
  bool _isVerified = false;
  final double _userRating = 4.9;

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
    _emergencyNameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user != null) {
        final data = await client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle();
        final userEmail = user.email ?? '';
        final defaultName = userEmail.contains('@')
            ? userEmail.split('@').first
            : 'TRYP User';
        final rawAvatar = data?['avatar_url'] as String?;
        final validAvatar =
            (rawAvatar != null &&
                rawAvatar.trim().isNotEmpty &&
                rawAvatar.startsWith('http'))
            ? rawAvatar.trim()
            : null;
        final rawFullName = data?['full_name'] as String?;

        if (mounted) {
          setState(() {
            _avatarUrl = validAvatar;
            _nameController.text =
                (rawFullName != null && rawFullName.trim().isNotEmpty)
                ? rawFullName.trim()
                : defaultName;
            _emailController.text = (data?['email'] as String?) ?? userEmail;
            _phoneController.text =
                (data?['phone_number'] as String?) ??
                (data?['phone'] as String?) ??
                '';
            _homeAddressController.text =
                (data?['home_address'] as String?) ?? '';
            _workAddressController.text =
                (data?['work_address'] as String?) ?? '';
            _emergencyContactController.text =
                (data?['emergency_contact_phone'] as String?) ?? '';
            _emergencyNameController.text =
                (data?['emergency_contact_name'] as String?) ?? '';
            _isVerified = passengerProfileIsApproved(data);
          });
        }
      } else {
        _setDefaults();
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
      _setDefaults();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<XFile?> _pickCameraAvatar(ImagePicker picker) async {
    final granted = await CameraPermissionService.ensureCameraPermission();
    if (!mounted) return null;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera permission is required to take a profile photo.',
          ),
          backgroundColor: TRYPColors.error,
        ),
      );
      return null;
    }

    return picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showModalBottomSheet<XFile?>(
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
            Text('Update Profile Picture', style: TRYPTypography.headingSmall),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: TRYPColors.inputFill,
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: TRYPColors.secondary,
                size: 28,
              ),
              title: Text(
                'Take Photo',
                style: TRYPTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Use camera to take a new profile picture'),
              onTap: () async {
                final file = await _pickCameraAvatar(picker);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: TRYPColors.inputFill,
              leading: const Icon(
                Icons.photo_library_rounded,
                color: TRYPColors.primary,
                size: 28,
              ),
              title: Text(
                'Choose from Gallery',
                style: TRYPTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text('Select photo from gallery'),
              onTap: () async {
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 600,
                  maxHeight: 600,
                  imageQuality: 85,
                );
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );

    if (image == null) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final client = ref.read(supabaseClientProvider);
      final user = client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();
      final extension =
          (ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp')
          ? ext
          : 'jpg';
      final storagePath =
          '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$extension',
              upsert: true,
            ),
          );

      final publicUrl = client.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      await client
          .from('profiles')
          .update({
            'avatar_url': publicUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      setState(() {
        _avatarUrl = publicUrl;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully! 📸'),
            backgroundColor: TRYPColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile picture: $e'),
            backgroundColor: TRYPColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _setDefaults() {
    final client = ref.read(supabaseClientProvider);
    final user = client.auth.currentUser;
    final userEmail = user?.email ?? '';
    final defaultName = userEmail.contains('@')
        ? userEmail.split('@').first
        : 'TRYP User';

    setState(() {
      _nameController.text = defaultName;
      _emailController.text = userEmail;
      _phoneController.text = '';
      _homeAddressController.text = '';
      _workAddressController.text = '';
      _emergencyContactController.text = '';
      _emergencyNameController.text = '';
      _isVerified = false;
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
          'emergency_contact_name': _emergencyNameController.text.trim(),
          'emergency_contact_phone': _emergencyContactController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      setState(() => _isEditing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: TRYPColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
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
        foregroundColor: TRYPColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: TRYPColors.primary),
          onPressed: () => context.go(Routes.passengerHome),
        ),
        title: Text(
          'Account & Profile',
          style: TRYPTypography.headingSmall.copyWith(
            fontSize: 18,
            color: TRYPColors.primary,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              if (_isEditing) {
                _saveProfile();
              } else {
                setState(() => _isEditing = true);
              }
            },
            icon: Icon(
              _isEditing ? Icons.check_circle_rounded : Icons.edit_rounded,
              color: TRYPColors.accent,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TRYPColors.primary),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProfileHero(
                        name: _nameController.text,
                        avatarUrl: _avatarUrl,
                        isVerified: _isVerified,
                        rating: _userRating,
                        isUploading: _isUploadingAvatar,
                        onAvatarTap: _pickAndUploadAvatar,
                      ),
                      const SizedBox(height: 28),

                      _ProfileSection(
                        title: 'Personal information',
                        icon: Icons.person_outline_rounded,
                        isEditing: _isEditing,
                        children: [
                          CustomTextField(
                            label: 'Full Name',
                            controller: _nameController,
                            prefixIcon: Icons.badge_outlined,
                            readOnly: !_isEditing,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            label: 'Email',
                            controller: _emailController,
                            prefixIcon: Icons.email_outlined,
                            readOnly: true,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            label: 'Phone Number',
                            controller: _phoneController,
                            prefixIcon: Icons.phone_outlined,
                            readOnly: !_isEditing,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _ProfileSection(
                        title: 'Saved places',
                        icon: Icons.bookmark_outline_rounded,
                        isEditing: _isEditing,
                        children: [
                          _AddressField(
                            icon: Icons.home_rounded,
                            label: 'Home',
                            controller: _homeAddressController,
                            isEditing: _isEditing,
                          ),
                          const SizedBox(height: 12),
                          _AddressField(
                            icon: Icons.work_outline_rounded,
                            label: 'Work',
                            controller: _workAddressController,
                            isEditing: _isEditing,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _ProfileSection(
                        title: 'Emergency contact',
                        icon: Icons.contact_emergency_outlined,
                        isEditing: _isEditing,
                        children: [
                          CustomTextField(
                            label: 'Contact Name',
                            hint: 'e.g. Sarah (Spouse / Parent)',
                            controller: _emergencyNameController,
                            prefixIcon: Icons.person_outline_rounded,
                            readOnly: !_isEditing,
                          ),
                          const SizedBox(height: 12),
                          CustomTextField(
                            label: 'Contact Phone',
                            hint: 'e.g. +27 71 987 6543',
                            controller: _emergencyContactController,
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_iphone_rounded,
                            readOnly: !_isEditing,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _ProfileSection(
                        title: 'Safety & security',
                        icon: Icons.shield_outlined,
                        children: [
                          const _SafetyNotice(),
                          const SizedBox(height: 12),
                          _ActionTile(
                            icon: _isVerified
                                ? Icons.verified_rounded
                                : Icons.verified_user_outlined,
                            title: _isVerified
                                ? 'Identity verified'
                                : 'Verify your identity',
                            subtitle: _isVerified
                                ? 'Your identity has been approved by TRYP'
                                : 'Submit your ID and camera selfie for review',
                            onTap: () =>
                                context.go(Routes.passengerVerification),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _ProfileSection(
                        title: 'Account controls',
                        icon: Icons.tune_rounded,
                        children: [
                          _ActionTile(
                            icon: Icons.history_rounded,
                            title: 'Trip history & receipts',
                            onTap: () => context.go(Routes.passengerActivity),
                          ),
                          const SizedBox(height: 10),
                          _ActionTile(
                            icon: Icons.support_agent_rounded,
                            title: '24/7 safety support & help',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Contacting TRYP 24/7 Safety Support...',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SecondaryButton(label: 'Log Out', onPressed: _logout),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),

                // Full-width flat bottom navigation bar
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: TRYPBottomNavBar(currentIndex: 3),
                ),
              ],
            ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isVerified;
  final double rating;
  final bool isUploading;
  final VoidCallback onAvatarTap;

  const _ProfileHero({
    required this.name,
    required this.avatarUrl,
    required this.isVerified,
    required this.rating,
    required this.isUploading,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: TRYPColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: TRYPColors.divider),
        boxShadow: [
          BoxShadow(
            color: TRYPColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 43,
                  backgroundColor: TRYPColors.accent,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: isUploading
                      ? const CircularProgressIndicator(color: TRYPColors.white)
                      : avatarUrl == null
                      ? const Icon(
                          Icons.person_rounded,
                          size: 50,
                          color: TRYPColors.white,
                        )
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: TRYPColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: TRYPColors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 13,
                      color: TRYPColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TRYPTypography.headingMedium.copyWith(
                    fontSize: 21,
                    color: TRYPColors.primary,
                  ),
                ),
                const SizedBox(height: 7),
                if (isVerified)
                  const _StatusPill(
                    icon: Icons.verified_rounded,
                    label: 'Identity verified',
                  )
                else
                  const _StatusPill(
                    icon: Icons.verified_user_outlined,
                    label: 'Verification pending',
                    muted: true,
                  ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetaPill(
                      icon: Icons.star_rounded,
                      label: rating.toStringAsFixed(1),
                    ),
                    const _MetaPill(
                      icon: Icons.workspace_premium_rounded,
                      label: 'Gold member',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool muted;

  const _StatusPill({
    required this.icon,
    required this.label,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = muted ? TRYPColors.grey : TRYPColors.primaryAlt;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: muted ? TRYPColors.lightGrey : TRYPColors.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TRYPTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: TRYPColors.primary),
        const SizedBox(width: 4),
        Text(
          label,
          style: TRYPTypography.bodySmall.copyWith(
            color: TRYPColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isEditing;
  final List<Widget> children;

  const _ProfileSection({
    required this.title,
    required this.icon,
    this.isEditing = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TRYPColors.accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: TRYPColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TRYPTypography.titleMedium.copyWith(
                    color: TRYPColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isEditing)
                Text(
                  'Editing',
                  style: TRYPTypography.bodySmall.copyWith(
                    color: TRYPColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _AddressField extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;
  final bool isEditing;

  const _AddressField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return CustomTextField(
        label: '$label address',
        controller: controller,
        prefixIcon: icon,
      );
    }

    return _ReadOnlyField(
      icon: icon,
      label: label,
      value: controller.text.trim().isEmpty
          ? 'Add a saved address'
          : controller.text.trim(),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadOnlyField({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: TRYPColors.inputFill,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: TRYPColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TRYPTypography.bodySmall.copyWith(
                    color: TRYPColors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TRYPTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TRYPColors.inputFill,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, color: TRYPColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TRYPTypography.titleMedium.copyWith(fontSize: 14),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TRYPTypography.bodySmall.copyWith(height: 1.35),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: TRYPColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TRYPColors.accentSoft,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, color: TRYPColors.primary),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Ride PIN verification is enabled. Your driver must verify the 4-digit PIN before starting your ride.',
              style: TRYPTypography.bodySmall.copyWith(
                color: TRYPColors.primaryAlt,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
