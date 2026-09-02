import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import 'widgets/role_selector_card.dart';
import '../../users/customer_db/customer_db.dart';
import '../../users/employee_db/employee_db.dart';
import '../../users/owner_db/owner_db.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  String _selectedRole = 'customer';

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
          'Create Account',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Account',
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: RoleSelectorCard(
                      label: 'Owner',
                      icon: Icons.storefront_outlined,
                      isSelected: _selectedRole == 'owner',
                      onTap: () => setState(() => _selectedRole = 'owner'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RoleSelectorCard(
                      label: 'Employee',
                      icon: Icons.badge_outlined,
                      isSelected: _selectedRole == 'employee',
                      onTap: () => setState(() => _selectedRole = 'employee'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RoleSelectorCard(
                      label: 'Customer',
                      icon: Icons.person_outline,
                      isSelected: _selectedRole == 'customer',
                      onTap: () => setState(() => _selectedRole = 'customer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // First Name + Middle Initial
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    flex: 3,
                    child: CustomTextField(
                      hint: 'First Name',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    flex: 1,
                    child: CustomTextField(
                      hint: 'M.I.',
                      icon: Icons.short_text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const CustomTextField(
                hint: 'Surname',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 14),

              const CustomTextField(
                hint: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),

              const CustomTextField(
                hint: 'Phone Number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 14),

              const CustomTextField(
                hint: 'Password',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 14),

              const CustomTextField(
                hint: 'Confirm Password',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Create Account',
                height: 48,
                onPressed: () {
                  Widget destination;
                  if (_selectedRole == 'owner') {
                    destination = const OwnerDb();
                  } else if (_selectedRole == 'employee') {
                    destination = const EmployeeDb();
                  } else {
                    destination = const CustomerDb();
                  }

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => destination),
                  );
                },
              ),
              
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}