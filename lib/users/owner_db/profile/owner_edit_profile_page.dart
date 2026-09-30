import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/utils/top_notification.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/editable_profile_avatar.dart';
import '../../../shared/widgets/primary_button.dart';
import 'owner_profile_controller.dart';

class OwnerEditProfilePage extends StatefulWidget {
  const OwnerEditProfilePage({super.key});

  @override
  State<OwnerEditProfilePage> createState() => _OwnerEditProfilePageState();
}

class _OwnerEditProfilePageState extends State<OwnerEditProfilePage> {
  final _controller = OwnerProfileController.instance;

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleInitialController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _contactController;
  String? _previewPhotoPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onProfileChanged);
    final profile = _controller.profile;
    _firstNameController = TextEditingController(text: profile.firstName);
    _middleInitialController = TextEditingController(text: profile.middleInitial);
    _lastNameController = TextEditingController(text: profile.lastName);
    _emailController = TextEditingController(text: profile.email);
    _contactController = TextEditingController(text: profile.contactNumber);
    _controller.loadProfile();
  }

  void _onProfileChanged() {
    if (!mounted) return;
    final profile = _controller.profile;
    if (_firstNameController.text.trim().isEmpty && profile.firstName.isNotEmpty) {
      _firstNameController.text = profile.firstName;
    }
    if (_middleInitialController.text.trim().isEmpty && profile.middleInitial.isNotEmpty) {
      _middleInitialController.text = profile.middleInitial;
    }
    if (_lastNameController.text.trim().isEmpty && profile.lastName.isNotEmpty) {
      _lastNameController.text = profile.lastName;
    }
    if (_emailController.text.trim().isEmpty && profile.email.isNotEmpty) {
      _emailController.text = profile.email;
    }
    if (_contactController.text.trim().isEmpty && profile.contactNumber.isNotEmpty) {
      _contactController.text = profile.contactNumber;
    }
  }

  String get _computedInitials {
    final f = _firstNameController.text.trim();
    final l = _lastNameController.text.trim();
    if (f.isNotEmpty || l.isNotEmpty) {
      final fChar = f.isNotEmpty ? f[0].toUpperCase() : '';
      final lChar = l.isNotEmpty ? l[0].toUpperCase() : '';
      return '$fChar$lChar';
    }
    return _controller.profile.initials;
  }

  @override
  void dispose() {
    _controller.removeListener(_onProfileChanged);
    _firstNameController.dispose();
    _middleInitialController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  void _saveChanges() async {
    final firstName = _firstNameController.text.trim();
    final middleInitial = _middleInitialController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final contact = _contactController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty) {
      TopNotification.show(context, 'Please fill in all required fields.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Changes', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Do you want to save the changes to your owner profile?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save', style: TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isSaving = true);
    try {
      if (_previewPhotoPath != null) {
        await _controller.setPhoto(_previewPhotoPath == '' ? null : _previewPhotoPath);
      }
      await _controller.updateProfile(
        firstName: firstName,
        middleInitial: middleInitial,
        lastName: lastName,
        email: email,
        contactNumber: contact,
      );

      if (!mounted) return;
      TopNotification.show(context, 'Owner profile updated successfully.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        TopNotification.show(context, 'Failed to update profile: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Owner Profile',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) {
                    final photoToDisplay = _previewPhotoPath == ''
                        ? null
                        : (_previewPhotoPath ?? _controller.profile.photoPath);
                    return EditableProfileAvatar(
                      initials: _computedInitials,
                      photoPath: photoToDisplay,
                      onPhotoChanged: (newPath) {
                        setState(() {
                          _previewPhotoPath = newPath ?? '';
                        });
                      },
                      radius: 46,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _previewPhotoPath != null && _previewPhotoPath!.isNotEmpty
                      ? 'Photo preview ready. Tap Save Changes to keep.'
                      : 'Tap avatar to change photo',
                  style: TextStyle(
                    color: _previewPhotoPath != null && _previewPhotoPath!.isNotEmpty
                        ? AppColors.primaryOrange
                        : AppColors.secondaryText,
                    fontSize: 12,
                    fontWeight: _previewPhotoPath != null && _previewPhotoPath!.isNotEmpty
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Owner Information',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'First Name',
                          style: TextStyle(
                            color: AppColors.labelText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CustomTextField(
                          hint: 'First Name',
                          icon: Icons.person_outline,
                          controller: _firstNameController,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'M.I.',
                          style: TextStyle(
                            color: AppColors.labelText,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        CustomTextField(
                          hint: 'M.I.',
                          textAlign: TextAlign.center,
                          controller: _middleInitialController,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Last Name',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                hint: 'Last Name',
                icon: Icons.person_outline,
                controller: _lastNameController,
              ),
              const SizedBox(height: 14),
              const Text(
                'Email Address',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                hint: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                controller: _emailController,
              ),
              const SizedBox(height: 14),
              const Text(
                'Contact Number',
                style: TextStyle(
                  color: AppColors.labelText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              CustomTextField(
                hint: 'Contact Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                controller: _contactController,
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _saveChanges,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
