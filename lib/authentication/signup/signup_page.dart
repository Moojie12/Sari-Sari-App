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
      body: Stack(
        children: [
          // 1. Full Screen Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_image.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // 2. Dark Overlay for readability across the whole screen
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),

          // 3. Side-by-Side Layout (Left: SignUp Box | Right: Logo)
          Row(
            children: [
              // LEFT SIDE: THE SIGNUP BOX
              Expanded(
                flex: 1,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(left: 80), // Push away from extreme edge
                  child: Container(
                    width: 520, // Slightly wider for signup form
                    margin: const EdgeInsets.symmetric(vertical: 40),
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 40,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Create Account',
                            style: TextStyle(
                              color: AppColors.darkText,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Fill up the form to join our enterprise network',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Role Selector
                          const Text(
                            'Select System Role',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: RoleSelectorCard(
                                  label: 'Owner',
                                  icon: Icons.storefront_outlined,
                                  isSelected: _selectedRole == 'owner',
                                  onTap: () => _onRoleSelected('owner'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RoleSelectorCard(
                                  label: 'Employee',
                                  icon: Icons.badge_outlined,
                                  isSelected: _selectedRole == 'employee',
                                  onTap: () => _onRoleSelected('employee'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RoleSelectorCard(
                                  label: 'Customer',
                                  icon: Icons.person_outline,
                                  isSelected: _selectedRole == 'customer',
                                  onTap: () => _onRoleSelected('customer'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

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
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 7),
                                    const CustomTextField(
                                      hint: 'Enter first name',
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
                                        fontWeight: FontWeight.bold,
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
                              fontWeight: FontWeight.bold,
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
                              fontWeight: FontWeight.bold,
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
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const CustomTextField(
                            hint: 'Enter phone number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 18),

                          const Text(
                            'Password',
                            style: TextStyle(
                              color: AppColors.labelText,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const CustomTextField(
                            hint: 'Create password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          const SizedBox(height: 18),

                          const Text(
                            'Confirm Password',
                            style: TextStyle(
                              color: AppColors.labelText,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const CustomTextField(
                            hint: 'Confirm password',
                            icon: Icons.lock_outline,
                            isPassword: true,
                          ),
                          const SizedBox(height: 32),

                          PrimaryButton(
                            label: 'Sign Up Now',
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
                          const SizedBox(height: 24),

                          Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "Already have an account? ",
                                  style: TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
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
                ),
              ),

              // RIGHT SIDE: BRANDING LOGO
              Expanded(
                flex: 1,
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(right: 80),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
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
                      const SizedBox(height: 28),
                      const Text(
                        'Sari-Sari Hub',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          shadows: [
                            Shadow(color: Colors.black54, offset: Offset(0, 4), blurRadius: 15),
                          ],
                        ),
                      ),
                      const Text(
                        'JOIN THE ENTERPRISE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                          shadows: [
                            Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 60),
                      const Text(
                        '© 2026 Tindahan ni Eca • Secured Node 0917',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
