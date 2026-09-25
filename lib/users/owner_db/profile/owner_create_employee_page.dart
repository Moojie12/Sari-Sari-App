import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/utils/top_notification.dart';

class OwnerCreateEmployeePage extends StatefulWidget {
  const OwnerCreateEmployeePage({super.key});

  @override
  State<OwnerCreateEmployeePage> createState() => _OwnerCreateEmployeePageState();
}

class _OwnerCreateEmployeePageState extends State<OwnerCreateEmployeePage> {
  final _firstNameController = TextEditingController();
  final _miController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _miController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _createEmployee() async {
    final firstName = _firstNameController.text.trim();
    final surname = _surnameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Basic validation
    if (firstName.isEmpty ||
        surname.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty) {
      TopNotification.show(context, 'Please fill in all required fields.', isError: true);
      return;
    }

    if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      TopNotification.show(context, 'Please enter a valid email address.', isError: true);
      return;
    }

    if (password.length < 8) {
      TopNotification.show(context, 'Password must be at least 8 characters long.', isError: true);
      return;
    }

    if (password != confirmPassword) {
      TopNotification.show(context, 'Passwords do not match.', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Registration'),
        content: Text('Do you want to register $firstName as a new employee?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: AppColors.primaryOrange)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // In a real app, we'd call an API here.
      // For now, we'll just show success and go back.
      Navigator.pop(context, true);
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
          'Register New Employee',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Employee Information',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: CustomTextField(
                      hint: 'First Name',
                      icon: Icons.person_outline,
                      controller: _firstNameController,
                      maxLength: 50,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                        LengthLimitingTextInputFormatter(50),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: CustomTextField(
                      hint: 'M.I.',
                      icon: Icons.short_text,
                      controller: _miController,
                      maxLength: 1,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
                        LengthLimitingTextInputFormatter(1),
                        TextInputFormatter.withFunction(
                          (oldValue, newValue) => newValue.copyWith(text: newValue.text.toUpperCase()),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              CustomTextField(
                hint: 'Lastname',
                icon: Icons.person_outline,
                controller: _surnameController,
                maxLength: 50,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                  LengthLimitingTextInputFormatter(50),
                ],
              ),
              const SizedBox(height: 14),

              CustomTextField(
                hint: 'Email Address',
                icon: Icons.email_outlined,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              CustomTextField(
                hint: 'Phone Number',
                icon: Icons.phone_outlined,
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),

              CustomTextField(
                hint: 'Password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 14),

              CustomTextField(
                hint: 'Confirm Password',
                icon: Icons.lock_outline,
                isPassword: true,
                controller: _confirmPasswordController,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Register Employee',
                height: 48,
                onPressed: _createEmployee,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
