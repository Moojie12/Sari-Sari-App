// lib/authentication/signup/signup_page.dart
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

  void _onRoleSelected(String role) {
    setState(() {
      _selectedRole = role;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false, // Papayagan ang Header na umabot sa pinaka-itaas (Status Bar)
        child: Column(
          children: [
            // Nakapirme ang Header dito, eksaktong kapareho ng proportion sa login page (flex 5)
            const Expanded(flex: 5, child: _Header()),
            Expanded(
              flex: 10, // Default base size na katulad ng sa login page upang pantay silang dalawa
              child: Transform.translate(
                offset: const Offset(0, -5), // I-overlap ang card sa image nang 5 pixels
                child: Container(
                  color: Colors.transparent,
                  child: _SignUpCard(
                    selectedRole: _selectedRole,
                    onRoleSelected: _onRoleSelected,
                  ),
                ),
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
      height: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: -10,
            child: Transform.scale(
              scale: 1.15,
              alignment: const Alignment(0, -0.96),
              child: Image.asset(
                'assets/images/bg_image.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Center(
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
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tindahan ni Eca',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Stock, Sell, Check, Buy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignUpCard extends StatelessWidget {
  const _SignUpCard({
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
        // Ang loob lamang ng white section / inputs ang pwedeng ma-scroll ngayon
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            const Text(
              'Create Account',
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'Fill up the form to join us',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Role Selector
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

            // Name Row (First Name + M.I.)
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
                      const SizedBox(height: 7),
                      const CustomTextField(
                        hint: 'First name',
                        icon: Icons.person_outline,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 7),
                      const CustomTextField(
                        hint: 'M.I.',
                        icon: Icons.short_text,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            const Text(
              'Surname',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            const CustomTextField(
              hint: 'Enter your surname',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 18),

            const Text(
              'Email Address',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            const CustomTextField(
              hint: 'Enter your email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 18),

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
              hint: 'Enter your phone number',
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
              hint: 'Enter password',
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 18),

            const Text(
              'Confirm Password',
              style: TextStyle(
                color: AppColors.labelText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 7),
            const CustomTextField(
              hint: 'Confirm password',
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            const SizedBox(height: 24),

            PrimaryButton(
              label: 'Sign Up',
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
                    "Already have an account? ",
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
