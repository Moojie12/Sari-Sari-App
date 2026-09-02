// lib/authentication/login/login_page.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/custom_text_field.dart';
import '../../shared/widgets/primary_button.dart';
import '../signup/signup_page.dart';
import '../../users/customer_db/customer_db.dart';
import '../../users/employee_db/employee_db.dart';
import '../../users/owner_db/owner_db.dart';
import '../signup/widgets/role_selector_card.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String _selectedRole = 'customer';

  void _onRoleSelected(String role) {
    setState(() {
      _selectedRole = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      body: SafeArea(
        child: Column(
          children: [
            const Expanded(flex: 5, child: _Header()),
            Expanded(
              flex: 10,
              child: _LoginCard(
                selectedRole: _selectedRole,
                onRoleSelected: _onRoleSelected,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primaryOrange,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 42,
                  color: AppColors.primaryOrange,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Sari-Sari',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                'Stock, Sell, Check, Buy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.selectedRole,
    required this.onRoleSelected,
  });

  final String selectedRole;
  final Function(String) onRoleSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text(
              'Welcome!',
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Login account to get started',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Role Selector in Login too
            Row(
              children: [
                Expanded(
                  child: RoleSelectorCard(
                    label: 'Owner',
                    icon: Icons.storefront_outlined,
                    isSelected: selectedRole == 'owner',
                    onTap: () => onRoleSelected('owner'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RoleSelectorCard(
                    label: 'Employee',
                    icon: Icons.badge_outlined,
                    isSelected: selectedRole == 'employee',
                    onTap: () => onRoleSelected('employee'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RoleSelectorCard(
                    label: 'Customer',
                    icon: Icons.person_outline,
                    isSelected: selectedRole == 'customer',
                    onTap: () => onRoleSelected('customer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Phone Number',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            const CustomTextField(
              hint: 'Enter your number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 18),

            const Text(
              'Password',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            const CustomTextField(
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 9),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot password?',
                  style: TextStyle(
                    color: AppColors.primaryOrange,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Login',
              onPressed: () {
                Widget destination;
                if (selectedRole == 'owner') {
                  destination = const OwnerDb();
                } else if (selectedRole == 'employee') {
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
            const SizedBox(height: 14),

            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignUpPage(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: AppColors.primaryOrange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            const Center(
              child: Text(
                'Your Everything Store',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
