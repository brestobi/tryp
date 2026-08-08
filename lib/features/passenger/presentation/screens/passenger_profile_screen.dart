import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tryp/app/router.dart';
import 'package:tryp/app/theme.dart';
import 'package:tryp/core/services/push_notification_service.dart';
import 'package:tryp/core/services/supabase_service.dart';
import 'package:tryp/core/services/welcome_notification_service.dart';
import 'package:tryp/core/widgets/common_widgets.dart';

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

  bool _isEditing = false;
  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  String? _avatarUrl;
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
                final file = await picker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 600,
                  maxHeight: 600,
                  imageQuality: 85,
                );
                if (mounted) Navigator.pop(context, file);
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
                if (mounted) Navigator.pop(context, file);
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
            backgroundColor: Colors.green,
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

  Future<void> _testPushNotification() async {
    try {
      final pushService = PushNotificationService();
      final allowed = await pushService.hasPermission();
      if (!allowed) {
        final settings = await pushService.requestPermission();
        if (settings.authorizationStatus == AuthorizationStatus.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification permission denied. Enable it in device settings to test push messages.'),
              backgroundColor: TRYPColors.error,
            ),
          );
          return;
        }
      }

      final token = await pushService.getPushToken();
      debugPrint('🧪 Test notification token: $token');

      if (!mounted) return;
      WelcomeNotificationService.showWelcomeNotification(
        callback: (title, body) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title\n$body'),
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              backgroundColor: TRYPColors.secondary,
            ),
          );
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(token == null
              ? 'Push permission granted. No token was returned yet.'
              : 'Push permission granted. Device token generated successfully for testing.'),
          backgroundColor: TRYPColors.primary,
        ),
      );
    } catch (e) {
      debugPrint('Error testing push notification: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Push test failed: $e'),
          backgroundColor: TRYPColors.error,
        ),
      );
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
                      // User Header Card
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickAndUploadAvatar,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 46,
                                    backgroundColor: TRYPColors.accent,
                                    backgroundImage:
                                        (_avatarUrl != null &&
                                            _avatarUrl!.startsWith('http'))
                                        ? NetworkImage(_avatarUrl!)
                                        : null,
                                    child: _isUploadingAvatar
                                        ? const CircularProgressIndicator(
                                            color: TRYPColors.primary,
                                          )
                                        : ((_avatarUrl == null ||
                                                  !_avatarUrl!.startsWith(
                                                    'http',
                                                  ))
                                              ? const Icon(
                                                  Icons.person_rounded,
                                                  size: 54,
                                                  color: TRYPColors.primary,
                                                )
                                              : null),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: TRYPColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: TRYPColors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.camera_alt_rounded,
                                        size: 14,
                                        color: TRYPColors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _nameController.text,
                              style: TRYPTypography.headingMedium.copyWith(
                                fontSize: 20,
                                color: TRYPColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: TRYPColors.accentSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: TRYPColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$_userRating ★ Gold Member',
                                        style: TRYPTypography.bodySmall
                                            .copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: TRYPColors.primary,
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
                          color: TRYPColors.dark,
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
                                  style: TRYPTypography.bodySmall.copyWith(
                                    color: TRYPColors.muted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'R${_walletBalance.toStringAsFixed(2)}',
                                  style: TRYPTypography.headingMedium.copyWith(
                                    color: TRYPColors.accent,
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Wallet Top Up powered by Paystack',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Top Up'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TRYPColors.accent,
                                foregroundColor: TRYPColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Personal Info Section
                      _SectionHeader(
                        title: 'Personal Info',
                        isEditing: _isEditing,
                      ),
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
                      _SectionHeader(
                        title: 'Saved Places',
                        isEditing: _isEditing,
                      ),
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
                      Text(
                        'Safety & Security',
                        style: TRYPTypography.headingSmall.copyWith(
                          fontSize: 16,
                          color: TRYPColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: TRYPColors.inputFill,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              activeTrackColor: TRYPColors.accent,
                              title: const Text(
                                'PIN Verification',
                                style: TextStyle(color: TRYPColors.primary),
                              ),
                              subtitle: const Text(
                                'Require 4-digit PIN before ride starts',
                                style: TextStyle(color: TRYPColors.grey),
                              ),
                              value: _pinVerificationEnabled,
                              onChanged: (val) =>
                                  setState(() => _pinVerificationEnabled = val),
                            ),
                            const Divider(height: 1, color: TRYPColors.grey),
                            SwitchListTile(
                              activeTrackColor: TRYPColors.accent,
                              title: const Text(
                                'Share Trip Status',
                                style: TextStyle(color: TRYPColors.primary),
                              ),
                              subtitle: const Text(
                                'Auto-share live location with emergency contact',
                                style: TextStyle(color: TRYPColors.grey),
                              ),
                              value: _shareTripEnabled,
                              onChanged: (val) =>
                                  setState(() => _shareTripEnabled = val),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      ListTile(
                        tileColor: TRYPColors.lightGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: const Icon(
                          Icons.verified_user_rounded,
                          color: TRYPColors.primary,
                        ),
                        title: const Text('Passenger identity verification'),
                        subtitle: const Text('Submit your ID and camera selfie for admin review'),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () => context.go(Routes.passengerVerification),
                      ),
                      const SizedBox(height: 10),

                      // Test Push Notification
                      ListTile(
                        tileColor: TRYPColors.lightGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: const Icon(
                          Icons.notifications_active_rounded,
                          color: TRYPColors.primary,
                        ),
                        title: const Text('Test Push Notification'),
                        subtitle: const Text('Request permission and verify notification readiness'),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                        ),
                        onTap: _testPushNotification,
                      ),
                      const SizedBox(height: 10),

                      // Quick Shortcuts
                      ListTile(
                        tileColor: TRYPColors.lightGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: const Icon(
                          Icons.history_rounded,
                          color: TRYPColors.primary,
                        ),
                        title: const Text('Trip History & Receipts'),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                        ),
                        onTap: () => context.go(Routes.passengerActivity),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        tileColor: TRYPColors.lightGrey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: const Icon(
                          Icons.support_agent_rounded,
                          color: TRYPColors.primary,
                        ),
                        title: const Text('24/7 Safety Support & Help'),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                        ),
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

                      const SizedBox(height: 32),

                      // Logout Button
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
            style: TRYPTypography.bodySmall.copyWith(
              color: TRYPColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}
