import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/theme/app_colors.dart';
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

  Future<void> _showUserForm(BuildContext context, [AdminUser? user]) async {
    if (!mounted) return;

    final isEdit = user != null;
    final formKey = GlobalKey<FormState>();
    final firstNameController = TextEditingController(text: user?.firstName ?? '');
    final middleInitialController = TextEditingController(text: user?.middleInitial ?? '');
    final surnameController = TextEditingController(text: user?.surname ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final phoneController = TextEditingController(text: user?.phone ?? '');
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    
    AdminRole selectedRole = user?.role ?? AdminRole.customer;
    bool isEnabled = user?.isActive ?? true;

    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? 'Edit User' : 'Add User'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: firstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            icon: Icon(Icons.person),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: middleInitialController,
                          decoration: const InputDecoration(
                            labelText: 'M.I.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: surnameController,
                    decoration: const InputDecoration(
                      labelText: 'Surname',
                      icon: Icon(Icons.person_outlined),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      icon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (!value.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      icon: Icon(Icons.phone),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  if (!isEdit) ...[
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        icon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (value) => !isEdit && (value == null || value.length < 6) ? 'Min 6 chars' : null,
                    ),
                    TextFormField(
                      controller: confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        icon: Icon(Icons.lock_reset),
                      ),
                      obscureText: true,
                      validator: (value) => !isEdit && value != passwordController.text ? 'Mismatch' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AdminRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      icon: Icon(Icons.person_search),
                    ),
                    items: AdminRole.values.map((role) => DropdownMenuItem(
                      value: role,
                      child: Text(role.label),
                    )).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Account Status'),
                    value: isEnabled,
                    onChanged: (value) => setState(() => isEnabled = value),
                    secondary: Icon(
                      isEnabled ? Icons.check_circle : Icons.cancel,
                      color: isEnabled ? Colors.green : Colors.red,
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
                if (!formKey.currentState!.validate()) return;

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
                      status: isEnabled ? 'Enabled' : 'Disabled',
                    );
                  } else {
                    result = await _userService.createUser(
                      firstName: firstName,
                      middleInitial: mi,
                      surname: surname,
                      email: email,
                      phone: phone,
                      role: selectedRole,
                      status: isEnabled ? 'Enabled' : 'Disabled',
                      password: passwordController.text,
                      confirmPassword: confirmPasswordController.text,
                    );
                  }

                  if (mounted) {
                    if (result == null) {
                      Navigator.pop(context, true);
                    } else {
                      TopNotification.show(context, result, isError: true);
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    TopNotification.show(context, 'Error: $e', isError: true);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
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
      if (mounted) {
        if (result == null) {
          TopNotification.show(context, 'User archived successfully');
          // Refresh the users section
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
      if (mounted) {
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
    final nameController0 = TextEditingController(text: product?.name ?? '');
    final barcodeController = TextEditingController(text: product?.barcode ?? '');
    final descriptionController = TextEditingController(text: product?.description ?? '');
    final priceController = TextEditingController(text: product?.price.toString() ?? '');
    final costController = TextEditingController(text: product?.cost.toString() ?? '');
    final quantityController = TextEditingController(text: product?.quantity.toString() ?? '');
    final unitController = TextEditingController(text: product?.unit ?? 'piece');
    
    String selectedCategoryId = product?.categoryId ?? '';

    // Ensure categories are loaded
    if (_categories.isEmpty && !_categoriesLoading) {
      _fetchCategories();
    }

    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Product' : 'Add Product'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController0,
                    decoration: const InputDecoration(labelText: 'Product Name', icon: Icon(Icons.inventory), hintText: 'e.g. Jasmine Rice'),
                    validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: barcodeController,
                    decoration: const InputDecoration(labelText: 'Barcode', icon: Icon(Icons.barcode_reader), hintText: 'Leave blank if none'),
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description', icon: Icon(Icons.description)),
                    maxLines: 2,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceController,
                          decoration: const InputDecoration(labelText: 'Price (₱)', icon: Icon(Icons.attach_money), hintText: 'e.g. 50'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: costController,
                          decoration: const InputDecoration(labelText: 'Cost (₱)', hintText: 'e.g. 40'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: quantityController,
                          decoration: const InputDecoration(labelText: 'Stock', icon: Icon(Icons.numbers), hintText: 'e.g. 100'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: unitController,
                          decoration: const InputDecoration(labelText: 'Unit', hintText: 'e.g. piece'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_categoriesLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Loading...', style: TextStyle(fontStyle: FontStyle.italic)),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('cat_${_categories.length}'),
                            initialValue: selectedCategoryId.isNotEmpty && _categories.any((c) => c.id == selectedCategoryId) 
                                ? selectedCategoryId 
                                : null,
                            decoration: const InputDecoration(labelText: 'Category', icon: Icon(Icons.category)),
                            items: [
                              const DropdownMenuItem<String>(value: '', child: Text('Select category')),
                              ..._categories.map((c) => DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.name),
                              )),
                            ],
                            onChanged: (val) => setDialogState(() => selectedCategoryId = val ?? ''),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: AppColors.primaryOrange),
                          onPressed: () async {
                            final nameController = TextEditingController();
                            final name = await showDialog<String>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('New Category'),
                                content: TextField(controller: nameController, autofocus: true),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, nameController.text.trim()), child: const Text('Add')),
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
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                
                try {
                  final price = double.tryParse(priceController.text) ?? 0.0;
                  final cost = double.tryParse(costController.text) ?? 0.0;
                  final qty = double.tryParse(quantityController.text) ?? 0.0;

                  String? error;
                  if (isEdit) {
                    error = await _productService.updateProduct(
                      id: product.id,
                      name: nameController0.text.trim(),
                      barcode: barcodeController.text.trim(),
                      description: descriptionController.text.trim(),
                      price: price,
                      cost: cost,
                      quantity: qty,
                      unit: unitController.text.trim(),
                      categoryId: selectedCategoryId,
                    );
                  } else {
                    error = await _productService.createProduct(
                      name: nameController0.text.trim(),
                      barcode: barcodeController.text.trim(),
                      description: descriptionController.text.trim(),
                      price: price,
                      cost: cost,
                      quantity: qty,
                      unit: unitController.text.trim(),
                      categoryId: selectedCategoryId,
                    );
                  }

                  if (mounted) {
                    if (error == null) {
                      TopNotification.show(context, 'Product ${isEdit ? 'updated' : 'added'} successfully');
                      Navigator.pop(context, true);
                      setState(() {});
                    } else {
                      TopNotification.show(context, error, isError: true);
                    }
                  }
                } catch (e) {
                  if (mounted) TopNotification.show(context, 'Error: $e', isError: true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
              child: Text(isEdit ? 'Update' : 'Add'),
            ),
          ],
        ),
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
                if (mounted) {
                  TopNotification.show(context, 'Stock adjusted successfully');
                }
                if (mounted) {
                  Navigator.pop(context, true);
                  // Refresh the products section
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Product'),
        content: Text('Are you sure you want to archive "${product.name}"?'),
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
      final result = await _productService.archiveProduct(product.id);
      if (mounted) {
        if (result == null) {
          TopNotification.show(context, 'Product archived successfully');
          // Refresh the products section
          setState(() {});
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
      if (mounted) {
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
      if (mounted) {
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
      if (mounted) {
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

  Future<void> _restoreCategory(BuildContext context, AdminCategory category) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Category'),
        content: Text('Are you sure you want to restore "${category.name}" from archive?'),
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
      final result = await _productService.restoreCategory(category.id);
      if (mounted) {
        if (result == null) {
          TopNotification.show(context, 'Category restored successfully');
          // Refresh the archived section
          setState(() {});
        } else {
          TopNotification.show(context, 'Failed to restore category: $result', isError: true);
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
      if (mounted) {
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
      if (mounted) {
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

  Future<void> _deleteCategoryFromArchived(BuildContext context, AdminCategory category) async {
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to permanently delete "${category.name}"? This action cannot be undone.'),
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
      final result = await _productService.permanentlyDeleteCategory(category.id);
      if (mounted) {
        if (result == null) {
          TopNotification.show(context, 'Category deleted successfully');
          // Refresh the archived section
          setState(() {});
        } else {
          TopNotification.show(context, 'Failed to delete category: $result', isError: true);
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
        children: [
          // Sidebar
          if (!isMobile) _buildSidebar(),
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 32),
              child: _buildBody(),
            ),
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
            onTap: () async {
              await AuthService().signOut();
              if (!mounted) return;

              // Navigate to appropriate login page based on platform
              if (kIsWeb) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminLoginPage()),
                      (route) => false,
                );
              } else {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                      (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 32),
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
          onAdjustStock: (product) => {}, // TODO: Implement stock adjustment
        );
      case AdminSection.users:
        return UsersSection(
          userService: _userService,
          searchQuery: '',
          rowsPerPage: 10,
          pages: const {},
          onPageChange: (_, _) {},
          onShowUserForm: (user) => _showUserForm(context, user),
          onShowUserDetail: (user) => _showUserDetail(context, user),
          onArchiveUser: (user) => _archiveUser(context, user),
          onDeleteUser: (user) => _deleteUser(context, user),
          onClearFilters: () => setState(() {}),
        );
      case AdminSection.settings:
        return SettingsSection(
          productService: _productService,
          initialStoreName: 'Tindahan ni Eca',
          initialRowsPerPage: 10,
          initialShowCostColumn: false,
          initialConfirmBeforeArchive: true,
          onStoreNameChanged: (name) {}, // TODO: Implement store name change
          onRowsPerPageChanged: (rows) {}, // TODO: Implement rows per page change
          onShowCostColumnChanged: (show) {}, // TODO: Implement show cost column change
          onConfirmBeforeArchiveChanged: (confirm) {}, // TODO: Implement confirm before archive change
        );
      case AdminSection.products:
        return ProductsSection(
          productService: _productService,
          categoryService: _categoryService,
          searchQuery: '',
          rowsPerPage: 10,
          pages: const {},
          showCostColumn: false,
          onPageChange: (_, _) {},
          onShowProductForm: (product) => _showProductForm(context, product),
          onAdjustStock: (product) => _adjustStock(context, product),
          onArchiveProduct: (product) => _archiveProduct(context, product),
          onDeleteProduct: (product) => _deleteProduct(context, product),
          onClearFilters: () => setState(() {}),
        );
      case AdminSection.categories:
        return CategoriesSection(
          categoryService: _categoryService,
          productService: _productService,
          searchQuery: '',
          rowsPerPage: 10,
          pages: const {},
          onPageChange: (_, _) {},
          onShowCategoryForm: (category) => {}, // TODO: Implement category form
          onArchiveCategory: (category) => {}, // TODO: Implement archive category
          onDeleteCategory: (category) => {}, // TODO: Implement delete category
        );
      case AdminSection.sales:
        return SalesSection(
          saleService: _saleService,
          searchQuery: '',
          rowsPerPage: 10,
          pages: const {},
          storeName: 'Tindahan ni Eca',
          onPageChange: (_, _) {},
          onShowReceipt: (sale) => {}, // TODO: Implement show receipt
          onVoidSale: (sale) => {}, // TODO: Implement void sale
          onCopyText: (_, _) {}, // TODO: Implement copy text
          onClearFilters: () {}, // TODO: Implement clear filters
        );
      case AdminSection.activity:
        return ActivitySection(
          auditService: _auditService,
          searchQuery: '',
          rowsPerPage: 10,
          pages: const {},
          onPageChange: (_, _) {},
          onShowAuditDetail: (log) => {}, // TODO: Implement audit log detail
        );
      case AdminSection.archived:
        return ArchivedSection(
          productService: _productService,
          userService: _userService,
          categoryService: _categoryService,
          searchQuery: '',
          rowsPerPage: 10,
          pages: const {},
          onPageChange: (_, _) {},
          onRestoreProduct: (product) => _restoreProduct(context, product),
          onDeleteProduct: (product) => _deleteProductFromArchived(context, product),
          onRestoreUser: (user) => _restoreUser(context, user),
          onDeleteUser: (user) => _deleteUserFromArchived(context, user),
          onRestoreCategory: (category) => _restoreCategory(context, category),
          onDeleteCategory: (category) => _deleteCategoryFromArchived(context, category),
          onClearFilters: () => setState(() {}),
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