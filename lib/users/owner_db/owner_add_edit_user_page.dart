import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../../admin/models/admin_models.dart';
import 'owner_user_controller.dart';

class OwnerAddEditUserPage extends StatefulWidget {
  const OwnerAddEditUserPage({super.key, this.user});
  final AdminUser? user;

  @override
  State<OwnerAddEditUserPage> createState() => _OwnerAddEditUserPageState();
}

class _OwnerAddEditUserPageState extends State<OwnerAddEditUserPage> {
  late final _fullNameController = TextEditingController(text: widget.user?.fullName);
  late final _usernameController = TextEditingController(text: widget.user?.username);
  late final _emailController = TextEditingController(text: widget.user?.email);
  late final _phoneController = TextEditingController(text: widget.user?.phone);
  late AdminRole _role = widget.user?.role ?? AdminRole.customer;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _save() {
    if (_fullNameController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields.')),
      );
      return;
    }

    final isEdit = widget.user != null;
    final user = AdminUser(
      id: widget.user?.id ?? 'USR-${DateTime.now().millisecondsSinceEpoch}',
      fullName: _fullNameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      role: _role,
      status: widget.user?.status ?? 'Active',
      verificationStatus: widget.user?.verificationStatus ?? 'Verified',
      createdAt: widget.user?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      isArchived: widget.user?.isArchived ?? false,
    );

    if (isEdit) {
      OwnerUserController.instance.updateUser(user);
    } else {
      OwnerUserController.instance.addUser(user);
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.user != null;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          isEdit ? 'Edit User' : 'Register New User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'User Information',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              CustomTextField(
                hint: 'Full Name',
                icon: Icons.person_outline,
                controller: _fullNameController,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                hint: 'Username',
                icon: Icons.alternate_email,
                controller: _usernameController,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                hint: 'Email Address',
                icon: Icons.email_outlined,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              CustomTextField(
                hint: 'Phone Number',
                icon: Icons.phone_outlined,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              const Text(
                'Access Role',
                style: TextStyle(color: AppColors.labelText, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              _buildRoleSelector(),
              const SizedBox(height: 40),
              PrimaryButton(
                label: isEdit ? 'Save Changes' : 'Create Account',
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Row(
      children: AdminRole.values.map((role) {
        final isSelected = _role == role;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _role = role),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryOrange : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? AppColors.primaryOrange : AppColors.borderColor),
                ),
                child: Column(
                  children: [
                    Icon(
                      role == AdminRole.owner 
                        ? Icons.storefront 
                        : role == AdminRole.employee 
                          ? Icons.badge_outlined 
                          : Icons.person_outline,
                      size: 20,
                      color: isSelected ? Colors.white : AppColors.secondaryText,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.label.split(' ')[0],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.darkText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
