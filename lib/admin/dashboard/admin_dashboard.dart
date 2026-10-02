import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/supabase_service.dart';
import '../../shared/widgets/product_image.dart';
import '../../shared/widgets/product_image_crop_dialog.dart';
import '../../authentication/login/login_page.dart';
import '../../authentication/admin_login/admin_login_page.dart';
import '../models/admin_models.dart';
import '../services/admin_product_service.dart';
import '../services/admin_user_service.dart';
import '../services/admin_category_service.dart';
import '../services/admin_sale_service.dart';
import '../services/admin_audit_service.dart';
import '../services/admin_analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/emailjs_service.dart';
import '../../shared/utils/text_formatters.dart';
import '../../shared/utils/top_notification.dart';
import './widgets/dashboard_shared.dart';
import './sections/overview_section.dart';
import './sections/settings_section.dart';
import './sections/users_section.dart';
import './sections/products_section.dart';
import './sections/categories_section.dart';
import './sections/sales_section.dart';
import './sections/activity_section.dart';
import './sections/archived_section.dart';
import '../../users/employee_db/employee_inventory_controller.dart';
import '../../users/employee_db/inventory/employee_archive_stock_dialog.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  AdminSection _selectedSection = AdminSection.overview;
  bool _isInitializing = true;
  String? _errorMessage;

  // Services
  final AdminProductService _productService = AdminProductService();
  final AdminUserService _userService = AdminUserService();
  final AdminCategoryService _categoryService = AdminCategoryService();
  final AdminSaleService _saleService = AdminSaleService();
  final AdminAuditService _auditService = AdminAuditService();
  final AdminAnalyticsService _analyticsService = AdminAnalyticsService();

  List<AdminCategory> _categories = [];
  bool _categoriesLoading = false;

  final Map<String, int> _pages = {};
  String _searchQuery = '';
  String _storeName = 'Tindahan ni Eca';
  int _rowsPerPage = 10;
  bool _showCostColumn = false;
  bool _confirmBeforeArchive = true;

  void _onPageChange(String key, int page) {
    setState(() {
      _pages[key] = page;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    _isInitializing = true;
    _errorMessage = null;
    try {
      await Future.wait([
        _productService.initialize(),
        _userService.initialize(),
        _categoryService.initialize(),
        _saleService.initialize(),
        _auditService.initialize(),
        _analyticsService.initialize(),
      ]);
      await _fetchCategories();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _fetchCategories() async {
    setState(() => _categoriesLoading = true);
    try {
      _categories = _categoryService.allCategories;
    } finally {
      if (mounted) setState(() => _categoriesLoading = false);
    }
  }

  // ==================== USER METHODS ====================

  String _generateRandomPassword() {
    const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lowercase = 'abcdefghijklmnopqrstuvwxyz';
    const numbers = '0123456789';
    const specials = '!@#\$%^&*(),.?":{}|<>_-+=/\\';
    
    final random = Random.secure();
    List<String> chars = [
      uppercase[random.nextInt(uppercase.length)],
      lowercase[random.nextInt(lowercase.length)],
      numbers[random.nextInt(numbers.length)],
      specials[random.nextInt(specials.length)],
    ];
    
    const allChars = uppercase + lowercase + numbers + specials;
    for (int i = 0; i < 8; i++) {
      chars.add(allChars[random.nextInt(allChars.length)]);
    }
    chars.shuffle(random);
    return chars.join();
  }

  Future<void> _showUserForm(BuildContext context, [AdminUser? user]) async {
    if (!mounted) return;

    final isEdit = user != null;
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(text: user?.firstName ?? '');
    final middleInitialController = TextEditingController(text: user?.middleInitial ?? '');
    final surnameController = TextEditingController(text: user?.surname ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    
    final tempPassword = isEdit ? '' : _generateRandomPassword();
    bool showTempPassword = false;

    AdminRole selectedRole = user?.role ?? AdminRole.customer;
    bool isSubmitting = false;

    String? validateFirstName(String val) {
      final v = val.trim();
      if (v.isEmpty) return 'Enter first name';
      if (v.length < 2) return 'At least 2 characters';
      if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(v)) return 'Letters and spaces only';
      return null;
    }

    String? validateMiddleInitial(String val) {
      final v = val.trim();
      if (v.isNotEmpty && !RegExp(r'^[a-zA-Z]{1,2}$').hasMatch(v)) {
        return '1-2 letters only';
      }
      return null;
    }

    String? validateSurname(String val) {
      final v = val.trim();
      if (v.isEmpty) return 'Enter surname';
      if (v.length < 2) return 'At least 2 characters';
      if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(v)) return 'Letters and spaces only';
      return null;
    }

    String? validateEmail(String val) {
      final v = val.trim();
      if (v.isEmpty) return 'Enter email address';
      if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(v)) {
        return 'Enter valid email address';
      }
      return null;
    }

    String? validatePhone(String val) {
      final v = val.trim();
      if (v.isEmpty) return 'Enter phone number';
      if (!v.startsWith('09') && !v.startsWith('+639')) {
        return 'Start with 09 or +639';
      }
      if (v.startsWith('09') && v.length != 11) {
        return 'Must be 11 digits (09xxxxxxxx)';
      }
      if (v.startsWith('+639') && v.length != 13) {
        return 'Must be 13 characters (+639xxxxxxxx)';
      }
      if (RegExp(r'(\d)\1{3}').hasMatch(v)) {
        return 'Cannot contain 4 consecutive same digits';
      }
      return null;
    }

    InputDecoration liveInputDecoration({
      required IconData icon,
      String? hint,
      required String value,
      required String? errorText,
      Widget? customSuffix,
    }) {
      final isNotEmpty = value.trim().isNotEmpty;
      final isValid = isNotEmpty && errorText == null;
      final isError = errorText != null;

      Widget? suffix;
      if (customSuffix != null) {
        suffix = customSuffix;
      } else if (isValid) {
        suffix = const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
        );
      } else if (isError && isNotEmpty) {
        suffix = const Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
        );
      }

      return InputDecoration(
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        errorText: isNotEmpty ? errorText : null,
        errorMaxLines: 2,
        prefixIcon: Icon(
          icon,
          size: 18,
          color: (isError && isNotEmpty) ? Colors.redAccent : (isValid ? Colors.green : AppColors.primaryOrange),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.lightPeach,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: isValid
              ? const BorderSide(color: Colors.green, width: 1)
              : BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: (isError && isNotEmpty) ? Colors.redAccent : AppColors.primaryOrange,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      );
    }

    Widget fieldLabel(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText,
          ),
        ),
      );
    }

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final fnVal = firstNameController.text;
          final miVal = middleInitialController.text;
          final snVal = surnameController.text;
          final emVal = emailController.text;
          final phVal = phoneController.text;

          final fnError = validateFirstName(fnVal);
          final miError = validateMiddleInitial(miVal);
          final snError = validateSurname(snVal);
          final emError = validateEmail(emVal);
          final phError = validatePhone(phVal);

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 620,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modal Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isEdit ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
                              color: AppColors.primaryOrange,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit ? 'Edit User Details' : 'Add New User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEdit
                                    ? 'Update profile information for ${user.fullName}'
                                    : 'Enter user registration details with live validation',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.placeholderColor),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.borderColor),
                  const SizedBox(height: 16),

                  // Modal Form Fields
                  Flexible(
                    child: SingleChildScrollView(
                      child: Form(
                        key: formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // First Name and Middle Initial
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      fieldLabel('First Name *'),
                                      TextFormField(
                                        controller: firstNameController,
                                        onChanged: (_) => setModalState(() {}),
                                        decoration: liveInputDecoration(
                                          icon: Icons.person_outline_rounded,
                                          hint: 'e.g. Juan',
                                          value: fnVal,
                                          errorText: fnError,
                                        ),
                                        validator: (_) => fnError,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      fieldLabel('M.I.'),
                                      TextFormField(
                                        controller: middleInitialController,
                                        onChanged: (_) => setModalState(() {}),
                                        textCapitalization: TextCapitalization.characters,
                                        decoration: liveInputDecoration(
                                          icon: Icons.short_text_rounded,
                                          hint: 'e.g. D',
                                          value: miVal,
                                          errorText: miError,
                                        ),
                                        validator: (_) => miError,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Surname
                            fieldLabel('Surname / Last Name *'),
                            TextFormField(
                              controller: surnameController,
                              onChanged: (_) => setModalState(() {}),
                              decoration: liveInputDecoration(
                                icon: Icons.badge_outlined,
                                hint: 'e.g. Cruz',
                                value: snVal,
                                errorText: snError,
                              ),
                              validator: (_) => snError,
                            ),
                            const SizedBox(height: 14),

                            // Email & Phone Number
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      fieldLabel('Email Address *'),
                                      TextFormField(
                                        controller: emailController,
                                        onChanged: (_) => setModalState(() {}),
                                        keyboardType: TextInputType.emailAddress,
                                        decoration: liveInputDecoration(
                                          icon: Icons.email_outlined,
                                          hint: 'user@example.com',
                                          value: emVal,
                                          errorText: emError,
                                        ),
                                        validator: (_) => emError,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      fieldLabel('Phone Number *'),
                                      TextFormField(
                                        controller: phoneController,
                                        onChanged: (_) => setModalState(() {}),
                                        keyboardType: TextInputType.phone,
                                        decoration: liveInputDecoration(
                                          icon: Icons.phone_outlined,
                                          hint: '09123456789',
                                          value: phVal,
                                          errorText: phError,
                                        ),
                                        validator: (_) => phError,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Auto-generated password info card (For new user creation)
                            if (!isEdit) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.lock_person_outlined, color: AppColors.primaryOrange, size: 20),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Auto-Generated Temporary Password',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.darkText),
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          icon: Icon(
                                            showTempPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                            size: 18,
                                            color: AppColors.placeholderColor,
                                          ),
                                          onPressed: () => setModalState(() => showTempPassword = !showTempPassword),
                                          tooltip: showTempPassword ? 'Hide password' : 'Show password',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryOrange),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: tempPassword));
                                            TopNotification.show(context, 'Temporary password copied to clipboard');
                                          },
                                          tooltip: 'Copy password',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      showTempPassword ? tempPassword : '•' * tempPassword.length,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.2, color: AppColors.darkText),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'This secure password meets all validation rules (min 8 chars, uppercase, lowercase, number, special char) and will be sent automatically to the user\'s email via EmailJS.',
                                      style: TextStyle(fontSize: 12, color: AppColors.secondaryText, height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),

                            // Role Dropdown
                            fieldLabel('User Role *'),
                            DropdownButtonFormField<AdminRole>(
                              initialValue: selectedRole,
                              decoration: liveInputDecoration(
                                icon: Icons.admin_panel_settings_outlined,
                                value: selectedRole.label,
                                errorText: null,
                              ),
                              items: AdminRole.values.map((role) {
                                return DropdownMenuItem(
                                  value: role,
                                  child: Text(
                                    role.label,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() => selectedRole = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Modal Actions (Cancel & Save)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          side: const BorderSide(color: AppColors.borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.darkText)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;

                                setModalState(() => isSubmitting = true);

                                final firstName = firstNameController.text.trim();
                                final mi = middleInitialController.text.trim();
                                final surname = surnameController.text.trim();
                                final email = emailController.text.trim();
                                final phone = phoneController.text.trim();

                                try {
                                  String? result;
                                  if (isEdit) {
                                    result = await _userService.updateUser(
                                      id: user.id,
                                      firstName: firstName,
                                      middleInitial: mi,
                                      surname: surname,
                                      email: email,
                                      phone: phone,
                                      role: selectedRole,
                                      status: user.status,
                                    );
                                  } else {
                                    result = await _userService.createUser(
                                      firstName: firstName,
                                      middleInitial: mi,
                                      surname: surname,
                                      email: email,
                                      phone: phone,
                                      role: selectedRole,
                                      status: 'Enabled',
                                      password: tempPassword,
                                      confirmPassword: tempPassword,
                                    );

                                    if (result == null) {
                                      // Maximize EmailJS to send account credentials
                                      await EmailJsService.instance.sendAccountCredentialsEmail(
                                        recipientEmail: email,
                                        temporaryPassword: tempPassword,
                                        recipientName: '$firstName ${mi.isNotEmpty ? '$mi. ' : ''}$surname'.trim(),
                                        roleName: selectedRole.label,
                                      );
                                    }
                                  }

                                  if (mounted && context.mounted) {
                                    setModalState(() => isSubmitting = false);
                                    if (result == null) {
                                      TopNotification.show(
                                        context,
                                        isEdit ? 'User details updated successfully' : 'User account created & credentials emailed!',
                                      );
                                      Navigator.pop(context, true);
                                    } else {
                                      TopNotification.show(context, result, isError: true);
                                    }
                                  }
                                } catch (e) {
                                  if (mounted && context.mounted) {
                                    setModalState(() => isSubmitting = false);
                                    TopNotification.show(context, 'Error: $e', isError: true);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(isEdit ? Icons.save_outlined : Icons.person_add_rounded, size: 18),
                        label: Text(isEdit ? 'Save Changes' : 'Add User'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showUserDetail(BuildContext context, AdminUser user) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: Row(
          children: [
            const Text(
              'User Profile Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(dialogContext),
              splashRadius: 18,
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: AdminUserAvatar(
                  photoUrl: user.photoUrl,
                  initials: user.initials,
                  radius: 42,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user.fullName.isNotEmpty ? user.fullName : 'Unnamed User',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.darkText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.role.label,
                      style: const TextStyle(
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: user.isActive
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      user.status,
                      style: TextStyle(
                        color: user.isActive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _userDetailRow(Icons.email_outlined, 'Email', user.email.isNotEmpty ? user.email : '—'),
              const SizedBox(height: 12),
              _userDetailRow(Icons.phone_outlined, 'Phone', user.phone.isNotEmpty ? user.phone : '—'),
              const SizedBox(height: 12),
              _userDetailRow(Icons.calendar_today_outlined, 'Joined', formatDate(user.createdAt)),
              if (user.updatedAt != null) ...[
                const SizedBox(height: 12),
                _userDetailRow(Icons.update_outlined, 'Last Updated', formatDateTime(user.updatedAt)),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _showUserForm(context, user);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondaryText),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.secondaryText, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _archiveUser(BuildContext context, AdminUser user) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive User'),
        content: Text('Are you sure you want to archive "${user.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _userService.archiveUser(user.id);
      if (mounted && context.mounted) {
        if (result == null) {
          TopNotification.show(context, 'User archived successfully');
          setState(() {});
        } else {
          TopNotification.show(context, 'Failed to archive user: $result', isError: true);
        }
      }
    }
  }

  Future<void> _deleteUser(BuildContext context, AdminUser user) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to permanently delete "${user.fullName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _userService.permanentlyDeleteUser(user.id);
      if (mounted && context.mounted) {
        if (result == null) {
          TopNotification.show(context, 'User deleted successfully');
          // Refresh the users section
          setState(() {});
        } else {
          TopNotification.show(context, 'Failed to delete user: $result', isError: true);
        }
      }
    }
  }

  // ==================== PRODUCT METHODS ====================

  Future<void> _showProductForm(BuildContext context, [AdminProduct? product]) async {
    if (!mounted) return;

    final isEdit = product != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product?.name ?? '');
    final barcodeController = TextEditingController(text: product?.barcode ?? '');
    final descriptionController = TextEditingController(text: product?.description ?? '');
    final priceController = TextEditingController(text: product?.price != null ? product!.price.toString() : '');
    final costController = TextEditingController(text: product?.cost != null ? product!.cost.toString() : '');
    final quantityController = TextEditingController(text: product?.quantity != null ? product!.quantity.toString() : '1');
    final thresholdController = TextEditingController(text: product?.lowStockThreshold != null ? product!.lowStockThreshold.round().clamp(0, 99).toString() : '5');

    // Bulk Purchase Entry Calculator
    bool isBulkMode = false;
    final bulkPriceController = TextEditingController();
    final pcsPerBulkController = TextEditingController();
    final numberOfBulkController = TextEditingController();

    bool isWeightBased = product != null
        ? (product.unit.toLowerCase() == 'kg' || product.unit.toLowerCase() == 'de kilo')
        : false;

    DateTime? expiryDate = product?.expirationDate;
    String selectedCategoryId = product?.categoryId ?? '';
    String? imagePath = product?.image;
    bool isImageChanged = false;
    final imagePicker = ImagePicker();

    Future<void> processImagePick(ImageSource source, StateSetter setDialogState, BuildContext dialogCtx) async {
      try {
        final picked = await imagePicker.pickImage(
          source: source,
          maxWidth: 1200,
          imageQuality: 85,
        );
        if (picked != null && dialogCtx.mounted) {
          final confirmedPath = await showProductImageCropDialog(
            context: dialogCtx,
            xfile: picked,
          );
          if (confirmedPath != null) {
            setDialogState(() {
              imagePath = confirmedPath;
              isImageChanged = true;
            });
          }
        }
      } catch (e) {
        debugPrint('Error picking image in admin: $e');
        if (dialogCtx.mounted) {
          TopNotification.show(dialogCtx, "Couldn't access image. Please check app permissions.", isError: true);
        }
      }
    }

    void showImageSourceSheet(StateSetter setDialogState, BuildContext dialogCtx) {
      showModalBottomSheet(
        context: dialogCtx,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Product Photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primaryOrange),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  processImagePick(ImageSource.camera, setDialogState, dialogCtx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primaryOrange),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  processImagePick(ImageSource.gallery, setDialogState, dialogCtx);
                },
              ),
              if (imagePath != null && imagePath!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setDialogState(() {
                      imagePath = null;
                      isImageChanged = true;
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    // Ensure categories are loaded
    if (_categories.isEmpty && !_categoriesLoading) {
      _fetchCategories();
    }

    void recalcBulk(StateSetter setDialogState) {
      final bulkPrice = double.tryParse(bulkPriceController.text.trim());
      final pcsPerBulk = int.tryParse(pcsPerBulkController.text.trim());
      final numberOfBulk = int.tryParse(numberOfBulkController.text.trim());

      setDialogState(() {
        if (bulkPrice != null && bulkPrice >= 0 && pcsPerBulk != null && pcsPerBulk > 0) {
          final capitalPerPc = bulkPrice / pcsPerBulk;
          costController.text = capitalPerPc.toStringAsFixed(2);
        }
        if (pcsPerBulk != null && pcsPerBulk > 0 && numberOfBulk != null && numberOfBulk >= 0) {
          final totalQty = (pcsPerBulk * numberOfBulk).toDouble();
          quantityController.text = isWeightBased ? totalQty.toStringAsFixed(2) : totalQty.toInt().toString();
        }
      });
    }

    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final selectedUnit = isWeightBased ? 'de kilo' : 'pcs';

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: dialogWidth(context, 720),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.90,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dialog Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.06),
                      border: const Border(bottom: BorderSide(color: AppColors.borderColor)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isEdit ? Icons.edit_note : Icons.add_box_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdit ? 'Edit Product' : 'Add Product',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkText,
                              ),
                            ),
                            Text(
                              isEdit
                                  ? 'Modify details and stock settings'
                                  : 'Fill in product details and initial inventory',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(dialogContext, false),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                  ),

                  // Dialog Body Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Photo
                            Center(
                              child: GestureDetector(
                                onTap: () => showImageSourceSheet(setDialogState, dialogContext),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: AppColors.lightPeach,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.borderColor),
                                  ),
                                  child: (imagePath == null || imagePath!.trim().isEmpty)
                                      ? const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_a_photo_outlined, color: AppColors.primaryOrange, size: 28),
                                            SizedBox(height: 6),
                                            Text(
                                              'Add Photo',
                                              style: TextStyle(
                                                color: AppColors.primaryOrange,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              ProductImage(
                                                image: imagePath,
                                                width: 100,
                                                height: 100,
                                                borderRadius: 16,
                                              ),
                                              Positioned(
                                                right: 6,
                                                bottom: 6,
                                                child: Container(
                                                  padding: const EdgeInsets.all(5),
                                                  decoration: const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black26,
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Icon(
                                                    Icons.edit,
                                                    size: 14,
                                                    color: AppColors.primaryOrange,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Product Type Selector (Retail Pcs vs De-Kilo Kg)
                            const Text(
                              'PRODUCT TYPE',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.labelText,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() => isWeightBased = false);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: !isWeightBased
                                            ? AppColors.primaryOrange.withValues(alpha: 0.12)
                                            : AppColors.lightBackground,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: !isWeightBased
                                              ? AppColors.primaryOrange
                                              : AppColors.borderColor,
                                          width: !isWeightBased ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.inventory_2_outlined,
                                            size: 18,
                                            color: !isWeightBased ? AppColors.primaryOrange : AppColors.secondaryText,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Retail (Pcs)',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: !isWeightBased ? FontWeight.bold : FontWeight.w500,
                                              color: !isWeightBased ? AppColors.primaryOrange : AppColors.darkText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() => isWeightBased = true);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: isWeightBased
                                            ? AppColors.primaryOrange.withValues(alpha: 0.12)
                                            : AppColors.lightBackground,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isWeightBased
                                              ? AppColors.primaryOrange
                                              : AppColors.borderColor,
                                          width: isWeightBased ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.scale_outlined,
                                            size: 18,
                                            color: isWeightBased ? AppColors.primaryOrange : AppColors.secondaryText,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'De-Kilo (Kg)',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: isWeightBased ? FontWeight.bold : FontWeight.w500,
                                              color: isWeightBased ? AppColors.primaryOrange : AppColors.darkText,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Basic Information Section
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextFormField(
                                        controller: nameController,
                                        maxLength: 20,
                                        inputFormatters: [
                                          NoDoubleSpaceAndMax20Formatter(maxLength: 20),
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Product Name',
                                          hintText: 'e.g. Jasmine Rice',
                                          prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
                                          counterText: '',
                                        ),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) return 'Product name is required';
                                          if (value.length > 20) return 'Max 20 characters allowed';
                                          if (value.contains('  ')) return 'Double spaces not allowed';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      // Category Selection
                                      Row(
                                        children: [
                                          Expanded(
                                            child: DropdownButtonFormField<String>(
                                              key: ValueKey('cat_${_categories.length}'),
                                              initialValue: selectedCategoryId.isNotEmpty &&
                                                      _categories.any((c) => c.id == selectedCategoryId)
                                                  ? selectedCategoryId
                                                  : null,
                                              decoration: const InputDecoration(
                                                labelText: 'Category',
                                                prefixIcon: Icon(Icons.category_outlined, size: 20),
                                              ),
                                              items: [
                                                const DropdownMenuItem<String>(value: '', child: Text('Select Category')),
                                                ..._categories.map((c) => DropdownMenuItem<String>(
                                                      value: c.id,
                                                      child: Text(c.name),
                                                    )),
                                              ],
                                              validator: (value) => (value == null || value.isEmpty) ? 'Please select a category' : null,
                                              onChanged: (val) => setDialogState(() => selectedCategoryId = val ?? ''),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton(
                                            tooltip: 'Add new category',
                                            icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryOrange),
                                            onPressed: () async {
                                              final catNameController = TextEditingController();
                                              final name = await showDialog<String>(
                                                context: dialogContext,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('New Category'),
                                                  content: TextField(
                                                    controller: catNameController,
                                                    autofocus: true,
                                                    maxLength: 20,
                                                    inputFormatters: [
                                                      NoDoubleSpaceAndMax20Formatter(maxLength: 20),
                                                    ],
                                                    decoration: const InputDecoration(
                                                      hintText: 'Category name',
                                                      counterText: '',
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx),
                                                      child: const Text('Cancel'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(ctx, catNameController.text.trim()),
                                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                                                      child: const Text('Add'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (name != null && name.isNotEmpty) {
                                                final err = await _categoryService.createCategory(name: name, description: '');
                                                if (err == null) {
                                                  await _fetchCategories();
                                                  final added = _categories.firstWhere((c) => c.name == name);
                                                  setDialogState(() => selectedCategoryId = added.id);
                                                }
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Barcode Field with Auto-Generate
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: barcodeController,
                                              decoration: const InputDecoration(
                                                labelText: 'Barcode',
                                                hintText: 'Scan or type barcode',
                                                prefixIcon: Icon(Icons.qr_code_outlined, size: 20),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              final random = Random();
                                              final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
                                              final timePart = timestamp.length >= 6 ? timestamp.substring(timestamp.length - 6) : timestamp;
                                              final randPart = (random.nextInt(900) + 100).toString();
                                              final autoBarcode = 'SS-$timePart$randPart';
                                              setDialogState(() {
                                                barcodeController.text = autoBarcode;
                                              });
                                            },
                                            icon: const Icon(Icons.auto_awesome, size: 16),
                                            label: const Text('Auto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.primaryOrange,
                                              side: const BorderSide(color: AppColors.primaryOrange),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Expiration Date Picker
                                      InkWell(
                                        onTap: () async {
                                          final now = DateTime.now();
                                          final picked = await showDatePicker(
                                            context: dialogContext,
                                            initialDate: expiryDate ?? now,
                                            firstDate: DateTime(now.year - 1),
                                            lastDate: DateTime(now.year + 15),
                                          );
                                          if (picked != null) {
                                            setDialogState(() => expiryDate = picked);
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            labelText: 'Expiration Date (Optional)',
                                            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                                            suffixIcon: expiryDate != null
                                                ? IconButton(
                                                    icon: const Icon(Icons.clear, size: 18),
                                                    onPressed: () => setDialogState(() => expiryDate = null),
                                                  )
                                                : null,
                                          ),
                                          child: Text(
                                            expiryDate == null
                                                ? 'No expiration set'
                                                : '${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: expiryDate == null ? AppColors.placeholderColor : AppColors.darkText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 20),

                                // Right Column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Selling Price and Cost
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: priceController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(
                                                labelText: 'Selling Price (₱)',
                                                hintText: '0.00',
                                                prefixIcon: Icon(Icons.attach_money, size: 20),
                                              ),
                                              validator: (value) {
                                                final v = double.tryParse(value ?? '');
                                                if (v == null || v < 0) return 'Invalid price';
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: costController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: const InputDecoration(
                                                labelText: 'Capital / Cost (₱)',
                                                hintText: '0.00',
                                              ),
                                              validator: (value) {
                                                final v = double.tryParse(value ?? '');
                                                if (v == null || v < 0) return 'Invalid cost';
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Stock Quantity & Low Stock Threshold
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: quantityController,
                                              keyboardType: TextInputType.numberWithOptions(decimal: isWeightBased),
                                              decoration: InputDecoration(
                                                labelText: isEdit ? 'Current Stock' : 'Initial Stock',
                                                hintText: isWeightBased ? 'e.g. 2.5' : 'e.g. 50',
                                                suffixText: selectedUnit,
                                                prefixIcon: const Icon(Icons.numbers_outlined, size: 20),
                                              ),
                                              validator: (value) {
                                                final qty = double.tryParse(value ?? '');
                                                if (qty == null || qty < 0) return 'Invalid stock';
                                                if (!isWeightBased && qty != qty.roundToDouble()) {
                                                  return 'Must be whole #';
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextFormField(
                                              controller: thresholdController,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.digitsOnly,
                                                LengthLimitingTextInputFormatter(2),
                                              ],
                                              decoration: const InputDecoration(
                                                labelText: 'Low Stock Limit',
                                                hintText: '5',
                                                helperText: 'Max 2 digits (0-99)',
                                              ),
                                              validator: (val) {
                                                if (val != null && val.isNotEmpty) {
                                                  final num = int.tryParse(val);
                                                  if (num == null || num < 0 || num > 99) {
                                                    return '0 - 99 only';
                                                  }
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),

                                      // Bulk Purchase Calculator Toggle
                                      if (!isWeightBased) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.lightBackground,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: AppColors.borderColor),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.calculate_outlined, size: 20, color: AppColors.primaryOrange),
                                              const SizedBox(width: 10),
                                              const Expanded(
                                                child: Text(
                                                  'Bulk Purchase Entry',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.darkText,
                                                  ),
                                                ),
                                              ),
                                              Switch(
                                                value: isBulkMode,
                                                activeTrackColor: AppColors.primaryOrange,
                                                onChanged: (val) {
                                                  setDialogState(() {
                                                    isBulkMode = val;
                                                    if (isBulkMode) recalcBulk(setDialogState);
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (isBulkMode) ...[
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryOrange.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3)),
                                            ),
                                            child: Column(
                                              children: [
                                                TextFormField(
                                                  controller: bulkPriceController,
                                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                  decoration: const InputDecoration(
                                                    labelText: 'Bulk Price (₱)',
                                                    hintText: 'e.g. 500 (total case price)',
                                                    isDense: true,
                                                  ),
                                                  onChanged: (_) => recalcBulk(setDialogState),
                                                ),
                                                const SizedBox(height: 10),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextFormField(
                                                        controller: pcsPerBulkController,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(
                                                          labelText: 'Pcs / Bulk',
                                                          hintText: 'e.g. 24',
                                                          isDense: true,
                                                        ),
                                                        onChanged: (_) => recalcBulk(setDialogState),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: TextFormField(
                                                        controller: numberOfBulkController,
                                                        keyboardType: TextInputType.number,
                                                        decoration: const InputDecoration(
                                                          labelText: '# of Bulks',
                                                          hintText: 'e.g. 2',
                                                          isDense: true,
                                                        ),
                                                        onChanged: (_) => recalcBulk(setDialogState),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                      ],

                                      // Description Field
                                      TextFormField(
                                        controller: descriptionController,
                                        maxLines: 2,
                                        decoration: const InputDecoration(
                                          labelText: 'Description (Optional)',
                                          hintText: 'Product notes, brand, size, etc.',
                                          alignLabelWithHint: true,
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
                    ),
                  ),

                  // Footer Actions
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      color: AppColors.lightBackground,
                      border: Border(top: BorderSide(color: AppColors.borderColor)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                            final cost = double.tryParse(costController.text.trim()) ?? 0.0;
                            final qty = double.tryParse(quantityController.text.trim()) ?? 0.0;
                            final threshold = (double.tryParse(thresholdController.text.trim()) ?? 5.0).clamp(0.0, 99.0);

                            try {
                              String? finalImageUrl = imagePath;
                              if (isImageChanged) {
                                if (imagePath != null && imagePath!.trim().isNotEmpty) {
                                  final trimmedPath = imagePath!.trim();
                                  if (trimmedPath.startsWith('http://') ||
                                      trimmedPath.startsWith('https://') ||
                                      trimmedPath.startsWith('data:image/')) {
                                    finalImageUrl = trimmedPath;
                                  } else {
                                    try {
                                      final uploadedUrl = await SupabaseService().uploadProductImageFromPathOrBytes(
                                        productId: isEdit ? product.id : (nameController.text.trim().isNotEmpty ? nameController.text.trim() : 'prod'),
                                        filePath: trimmedPath,
                                      );
                                      if (uploadedUrl != null &&
                                          uploadedUrl.isNotEmpty &&
                                          !uploadedUrl.startsWith('/') &&
                                          !uploadedUrl.startsWith('file://')) {
                                        finalImageUrl = uploadedUrl;
                                        debugPrint('Product photo uploaded by admin: $finalImageUrl');
                                      } else {
                                        String cleanPath = trimmedPath;
                                        if (cleanPath.startsWith('file://')) cleanPath = cleanPath.substring(7);
                                        try {
                                          final bytes = await XFile(cleanPath).readAsBytes();
                                          final ext = cleanPath.endsWith('.png') ? 'png' : 'jpg';
                                          finalImageUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
                                        } catch (_) {
                                          if (!kIsWeb) {
                                            final file = File(cleanPath);
                                            if (await file.exists()) {
                                              final bytes = await file.readAsBytes();
                                              final ext = cleanPath.endsWith('.png') ? 'png' : 'jpg';
                                              finalImageUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
                                            }
                                          }
                                        }
                                      }
                                    } catch (e) {
                                      debugPrint('Error uploading product photo in admin: $e');
                                    }
                                  }
                                } else {
                                  finalImageUrl = null;
                                }
                              }

                              final shouldClearImage = isImageChanged && (finalImageUrl == null || finalImageUrl.trim().isEmpty);

                              String? error;
                              if (isEdit) {
                                error = await _productService.updateProduct(
                                  id: product.id,
                                  name: nameController.text.trim(),
                                  barcode: barcodeController.text.trim(),
                                  description: descriptionController.text.trim(),
                                  price: price,
                                  cost: cost,
                                  quantity: qty,
                                  unit: selectedUnit,
                                  categoryId: selectedCategoryId,
                                  expirationDate: expiryDate,
                                  lowStockThreshold: threshold,
                                  image: finalImageUrl,
                                  clearImage: shouldClearImage,
                                );
                              } else {
                                error = await _productService.createProduct(
                                  name: nameController.text.trim(),
                                  barcode: barcodeController.text.trim(),
                                  description: descriptionController.text.trim(),
                                  price: price,
                                  cost: cost,
                                  quantity: qty,
                                  unit: selectedUnit,
                                  categoryId: selectedCategoryId,
                                  expirationDate: expiryDate,
                                  lowStockThreshold: threshold,
                                  image: finalImageUrl,
                                );
                              }

                              if (mounted && dialogContext.mounted) {
                                if (error == null) {
                                  TopNotification.show(
                                    context,
                                    'Product ${isEdit ? 'updated' : 'added'} successfully',
                                  );
                                  Navigator.pop(dialogContext, true);
                                  await EmployeeInventoryController.instance.reloadProducts();
                                  setState(() {});
                                } else {
                                  TopNotification.show(context, error, isError: true);
                                }
                              }
                            } catch (e) {
                              if (mounted && dialogContext.mounted) {
                                TopNotification.show(context, 'Error: $e', isError: true);
                              }
                            }
                          },
                          icon: Icon(isEdit ? Icons.save_outlined : Icons.add, color: Colors.white, size: 18),
                          label: Text(
                            isEdit ? 'Update Product' : 'Add Product',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
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

  Future<void> _adjustStock(BuildContext context, AdminProduct product) async {
    if (!mounted) return;

    final formKey = GlobalKey<FormState>();
    final quantityController = TextEditingController(text: product.quantity.toString());
    final unitController = TextEditingController(text: product.unit);

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Stock'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    icon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: false),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter quantity';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    icon: Icon(Icons.folder_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              final quantity = int.tryParse(quantityController.text.trim()) ?? 0;

              try {
                await _productService.adjustStock(
                  product.id,
                  quantity.toDouble(),
                );
                if (mounted && context.mounted) {
                  TopNotification.show(context, 'Stock adjusted successfully');
                  Navigator.pop(context, true);
                  // Refresh the products section
                  setState(() {});
                }
              } catch (e) {
                if (mounted && context.mounted) {
                  TopNotification.show(context, 'Failed to adjust stock: $e', isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Adjust'),
          ),
        ],
      ),
    );
  }

  Future<void> _archiveProduct(BuildContext context, AdminProduct product) async {
    if (!mounted) return;

    var empProduct = EmployeeInventoryController.instance.findById(product.id);
    if (empProduct == null) {
      await EmployeeInventoryController.instance.reloadProducts();
      if (!mounted) return;
      empProduct = EmployeeInventoryController.instance.findById(product.id);
    }

    if (empProduct != null && empProduct.batches.isNotEmpty) {
      if (!context.mounted) return;
      await showDialog(
        context: context,
        builder: (dialogContext) => EmployeeArchiveStockDialog(
          product: empProduct!,
          inventory: EmployeeInventoryController.instance,
        ),
      );
      if (mounted) {
        await _productService.refresh();
        if (mounted) setState(() {});
      }
      return;
    }

    if (!context.mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Product'),
        content: Text('Are you sure you want to archive "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _productService.archiveProduct(product.id);
      if (mounted && context.mounted) {
        if (result == null) {
          TopNotification.show(context, 'Product archived successfully');
          await _productService.refresh();
          if (mounted) setState(() {});
        } else {
          TopNotification.show(context, 'Failed to archive product: $result', isError: true);
        }
      }
    }
  }

  Future<void> _deleteProduct(BuildContext context, AdminProduct product) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to permanently delete "${product.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _productService.permanentlyDeleteProduct(product.id);
      if (mounted && context.mounted) {
        if (result == null) {
          TopNotification.show(context, 'Product deleted successfully');
          // Refresh the products section
          setState(() {});
        } else {
          TopNotification.show(context, 'Failed to delete product: $result', isError: true);
        }
      }
    }
  }

  // ==================== CATEGORY METHODS ====================

  Future<void> _showCategoryForm(BuildContext context, [AdminCategory? category]) async {
    if (!mounted) return;

    final isEdit = category != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: category?.name ?? '');
    final descriptionController = TextEditingController(text: category?.description ?? '');

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Category' : 'Add Category'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Category Name',
                    icon: Icon(Icons.category_outlined),
                  ),
                  maxLength: 20,
                  inputFormatters: [
                    NoDoubleSpaceAndMax20Formatter(maxLength: 20),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter category name';
                    }
                    if (value.trim().length < 2) {
                      return 'Category name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    icon: Icon(Icons.description_outlined),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final name = nameController.text.trim();
              final description = descriptionController.text.trim();

              String? result;
              if (isEdit) {
                result = await _categoryService.updateCategory(
                  id: category.id,
                  name: name,
                  description: description,
                );
                await _productService.updateCategory(
                  id: category.id,
                  name: name,
                  description: description,
                );
              } else {
                result = await _categoryService.createCategory(
                  name: name,
                  description: description,
                );
                await _productService.createCategory(
                  name: name,
                  description: description,
                );
              }

              if (mounted && context.mounted) {
                if (result == null) {
                  TopNotification.show(
                    context,
                    isEdit ? 'Category updated successfully' : 'Category created successfully',
                  );
                  Navigator.pop(context, true);
                  setState(() {});
                } else {
                  TopNotification.show(context, result, isError: true);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, AdminCategory category) async {
    if (!mounted) return;

    final totalProductCount = _productService.getProductCountForCategory(category.id);
    final activeCount = _productService.getActiveProductCountForCategory(category.id);
    final archivedCount = totalProductCount - activeCount;

    if (totalProductCount > 0) {
      String details = '';
      if (activeCount > 0 && archivedCount > 0) {
        details = '$activeCount active product(s) and $archivedCount archived product(s) (in the Archived tab)';
      } else if (archivedCount > 0) {
        details = '$archivedCount archived product(s) (in the Archived tab)';
      } else {
        details = '$activeCount active product(s)';
      }

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Category'),
          content: Text(
            'The category "${category.name}" cannot be deleted because $details are still tied to it.\n\nPlease delete or reassign all associated products first.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _categoryService.permanentlyDeleteCategory(category.id);
      await _productService.permanentlyDeleteCategory(category.id);
      if (mounted && context.mounted) {
        if (result == null) {
          TopNotification.show(context, 'Category deleted successfully');
          setState(() {});
        } else {
          TopNotification.show(context, result, isError: true);
        }
      }
    }
  }

  // ==================== ARCHIVED SECTION METHODS ====================

  Future<void> _restoreProduct(BuildContext context, AdminProduct product) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Product'),
        content: Text('Are you sure you want to restore "${product.name}" from archive?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _productService.restoreProduct(product.id);
      if (mounted && context.mounted) {
        if (result == null) {
          TopNotification.show(context, 'Product restored successfully');
          // Refresh the archived section
          setState(() {});
        } else {
          TopNotification.show(context, 'Failed to restore product: $result', isError: true);
        }
      }
    }
  }

  Future<void> _restoreUser(BuildContext context, AdminUser user) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore User'),
        content: Text('Are you sure you want to restore "${user.fullName}" from archive?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _userService.restoreUser(user.id);
      if (mounted && context.mounted) {
        if (result == null) {
          TopNotification.show(context, 'User restored successfully');
          // Refresh the archived section
          setState(() {});
        } else {
          TopNotification.show(context, 'Failed to restore user: $result', isError: true);
        }
      }
    }
  }

  Future<void> _deleteProductFromArchived(BuildContext context, AdminProduct product) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to permanently delete "${product.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _productService.permanentlyDeleteProduct(product.id);
      if (mounted && context.mounted) {
        if (result == null) {
          TopNotification.show(context, 'Product deleted successfully');
          // Refresh the archived section
          setState(() {});
        } else {
          TopNotification.show(context, 'Failed to delete product: $result', isError: true);
        }
      }
    }
  }

  Future<void> _deleteUserFromArchived(BuildContext context, AdminUser user) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to permanently delete "${user.fullName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final result = await _userService.permanentlyDeleteUser(user.id);
      if (mounted && context.mounted) {
        if (result == null) {
          TopNotification.show(context, 'User deleted successfully');
          // Refresh the archived section
          setState(() {});
        } else {
          TopNotification.show(context, 'Failed to delete user: $result', isError: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 900;

    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryOrange,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Failed to load data',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initializeServices,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      drawer: isMobile ? _buildSidebar(isDrawer: true) : null,
      appBar: isMobile ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.darkText),
        title: const Text('Tindahan ni Eca Admin', style: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.bold)),
      ) : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar
          if (!isMobile) _buildSidebar(),
          // Main Content
          Expanded(
            child: Align(
              alignment: Alignment.topLeft,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 32),
                child: _buildBody(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context, rootNavigator: true);
              Navigator.pop(dialogContext);
              await AuthService().signOut();

              // Navigate to appropriate login page based on platform
              if (kIsWeb) {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AdminLoginPage()),
                  (route) => false,
                );
              } else {
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar({bool isDrawer = false}) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        border: isDrawer ? null : const Border(right: BorderSide(color: AppColors.borderColor, width: 1)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storefront, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tindahan ni Eca',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.darkText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      'Admin Panel',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sidebarItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            isSelected: _selectedSection == AdminSection.overview,
            onTap: () {
              setState(() => _selectedSection = AdminSection.overview);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _sidebarItem(
            icon: Icons.people_outline,
            label: 'Users',
            isSelected: _selectedSection == AdminSection.users,
            onTap: () {
              setState(() => _selectedSection = AdminSection.users);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _sidebarItem(
            icon: Icons.inventory_2_outlined,
            label: 'Inventory',
            isSelected: _selectedSection == AdminSection.products,
            onTap: () {
              setState(() => _selectedSection = AdminSection.products);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _sidebarItem(
            icon: Icons.receipt_long_outlined,
            label: 'Sales',
            isSelected: _selectedSection == AdminSection.sales,
            onTap: () {
              setState(() => _selectedSection = AdminSection.sales);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _sidebarItem(
            icon: Icons.analytics_outlined,
            label: 'Activity',
            isSelected: _selectedSection == AdminSection.activity,
            onTap: () {
              setState(() => _selectedSection = AdminSection.activity);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _sidebarItem(
            icon: Icons.archive_outlined,
            label: 'Archived',
            isSelected: _selectedSection == AdminSection.archived,
            onTap: () {
              setState(() => _selectedSection = AdminSection.archived);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          _sidebarItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: _selectedSection == AdminSection.settings,
            onTap: () {
              setState(() => _selectedSection = AdminSection.settings);
              if (isDrawer) Navigator.pop(context);
            },
          ),
          Spacer(),
          _sidebarItem(
            icon: Icons.logout,
            label: 'Logout',
            isSelected: false,
            onTap: () => _showLogoutConfirmation(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _showAuditDetail(BuildContext context, AdminAuditLog log) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.history_edu_rounded, color: AppColors.primaryOrange),
            const SizedBox(width: 8),
            const Text(
              'Audit Log Details',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(dialogContext),
              splashRadius: 18,
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _userDetailRow(Icons.bolt_outlined, 'Action', log.action.label),
              const SizedBox(height: 12),
              _userDetailRow(Icons.category_outlined, 'Entity Type', log.entityType),
              const SizedBox(height: 12),
              _userDetailRow(Icons.label_outlined, 'Entity Name', log.entityName),
              const SizedBox(height: 12),
              _userDetailRow(Icons.person_outline, 'Performed By', log.performedBy),
              const SizedBox(height: 12),
              _userDetailRow(Icons.schedule_outlined, 'Timestamp', formatDateTime(log.timestamp)),
              if (log.previousStatus.isNotEmpty || log.newStatus.isNotEmpty) ...[
                const SizedBox(height: 12),
                _userDetailRow(Icons.swap_horiz_outlined, 'Status Change', '${log.previousStatus} → ${log.newStatus}'),
              ],
              if (log.note != null && log.note!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Notes / Reason:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightPeach,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    log.note!,
                    style: const TextStyle(fontSize: 12, color: AppColors.darkText),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedSection) {
      case AdminSection.overview:
        return OverviewSection(
          productService: _productService,
          userService: _userService,
          categoryService: _categoryService,
          saleService: _saleService,
          auditService: _auditService,
          analyticsService: _analyticsService,
          onGoTo: (section) => setState(() => _selectedSection = section),
          onAdjustStock: (product) => _adjustStock(context, product),
        );
      case AdminSection.users:
        return UsersSection(
          userService: _userService,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          onPageChange: _onPageChange,
          onShowUserForm: (user) => _showUserForm(context, user),
          onShowUserDetail: (user) => _showUserDetail(context, user),
          onArchiveUser: (user) => _archiveUser(context, user),
          onDeleteUser: (user) => _deleteUser(context, user),
          onClearFilters: () => setState(() {
            _searchQuery = '';
            _pages['users'] = 1;
          }),
        );
      case AdminSection.settings:
        return SettingsSection(
          productService: _productService,
          initialStoreName: _storeName,
          initialRowsPerPage: _rowsPerPage,
          initialShowCostColumn: _showCostColumn,
          initialConfirmBeforeArchive: _confirmBeforeArchive,
          onStoreNameChanged: (name) => setState(() => _storeName = name),
          onRowsPerPageChanged: (rows) => setState(() => _rowsPerPage = rows),
          onShowCostColumnChanged: (show) => setState(() => _showCostColumn = show),
          onConfirmBeforeArchiveChanged: (confirm) => setState(() => _confirmBeforeArchive = confirm),
        );
      case AdminSection.products:
        return ProductsSection(
          productService: _productService,
          categoryService: _categoryService,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          showCostColumn: _showCostColumn,
          onPageChange: _onPageChange,
          onShowProductForm: (product) => _showProductForm(context, product),
          onAdjustStock: (product) => _adjustStock(context, product),
          onArchiveProduct: (product) => _archiveProduct(context, product),
          onDeleteProduct: (product) => _deleteProduct(context, product),
          onDeleteCategory: (category) => _deleteCategory(context, category),
          onClearFilters: () => setState(() {
            _searchQuery = '';
            _pages['products'] = 1;
          }),
        );
      case AdminSection.categories:
        return CategoriesSection(
          categoryService: _categoryService,
          productService: _productService,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          onPageChange: _onPageChange,
          onShowCategoryForm: (category) => _showCategoryForm(context, category),
          onDeleteCategory: (category) => _deleteCategory(context, category),
        );
      case AdminSection.sales:
        return SalesSection(
          saleService: _saleService,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          storeName: _storeName,
          onPageChange: _onPageChange,
          onShowReceipt: (_) {},
          onVoidSale: (_) {},
          onCopyText: (_, _) {},
          onClearFilters: () => setState(() {
            _searchQuery = '';
            _pages['sales'] = 1;
          }),
        );
      case AdminSection.activity:
        return ActivitySection(
          auditService: _auditService,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          onPageChange: _onPageChange,
          onShowAuditDetail: (log) => _showAuditDetail(context, log),
        );
      case AdminSection.archived:
        return ArchivedSection(
          productService: _productService,
          userService: _userService,
          searchQuery: _searchQuery,
          rowsPerPage: _rowsPerPage,
          pages: _pages,
          onPageChange: _onPageChange,
          onRestoreProduct: (product) => _restoreProduct(context, product),
          onDeleteProduct: (product) => _deleteProductFromArchived(context, product),
          onRestoreUser: (user) => _restoreUser(context, user),
          onDeleteUser: (user) => _deleteUserFromArchived(context, user),
          onClearFilters: () => setState(() {
            _searchQuery = '';
            _pages['archived'] = 1;
          }),
        );
    }
  }

  Widget _sidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryOrange.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
                size: 24,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primaryOrange : AppColors.secondaryText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}