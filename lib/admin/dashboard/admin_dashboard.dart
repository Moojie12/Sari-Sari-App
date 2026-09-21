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
    final _formKey = GlobalKey<FormState>();
    final _firstNameController = TextEditingController(text: user?.firstName ?? '');
    final _middleInitialController = TextEditingController(text: user?.middleInitial ?? '');
    final _surnameController = TextEditingController(text: user?.surname ?? '');
    final _emailController = TextEditingController(text: user?.email ?? '');
    final _phoneController = TextEditingController(text: user?.phone ?? '');
    final _passwordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    
    AdminRole _selectedRole = user?.role ?? AdminRole.customer;
    bool _isEnabled = user?.isActive ?? true;

    await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEdit ? 'Edit User' : 'Add User'),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _firstNameController,
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
                          controller: _middleInitialController,
                          decoration: const InputDecoration(
                            labelText: 'M.I.',
                          ),
                        ),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: _surnameController,
                    decoration: const InputDecoration(
                      labelText: 'Surname',
                      icon: Icon(Icons.person_outlined),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _emailController,
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
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      icon: Icon(Icons.phone),
                    ),
                    validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                  ),
                  if (!isEdit) ...[
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        icon: Icon(Icons.lock_outline),
                      ),
                      obscureText: true,
                      validator: (value) => !isEdit && (value == null || value.length < 6) ? 'Min 6 chars' : null,
                    ),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'Confirm Password',
                        icon: Icon(Icons.lock_reset),
                      ),
                      obscureText: true,
                      validator: (value) => !isEdit && value != _passwordController.text ? 'Mismatch' : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  DropdownButtonFormField<AdminRole>(
                    value: _selectedRole,
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
                        setState(() => _selectedRole = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Account Status'),
                    value: _isEnabled,
                    onChanged: (value) => setState(() => _isEnabled = value),
                    secondary: Icon(
                      _isEnabled ? Icons.check_circle : Icons.cancel,
                      color: _isEnabled ? Colors.green : Colors.red,
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
                if (!_formKey.currentState!.validate()) return;

                final firstName = _firstNameController.text.trim();
                final mi = _middleInitialController.text.trim();
                final surname = _surnameController.text.trim();
                final email = _emailController.text.trim();
                final phone = _phoneController.text.trim();

                try {
                  String? result;
                  if (isEdit) {
                    result = await _userService.updateUser(
                      id: user!.id,
                      firstName: firstName,
                      middleInitial: mi,
                      surname: surname,
                      email: email,
                      phone: phone,
                      role: _selectedRole,
                      status: _isEnabled ? 'Enabled' : 'Disabled',
                    );
                  } else {
                    result = await _userService.createUser(
                      firstName: firstName,
                      middleInitial: mi,
                      surname: surname,
                      email: email,
                      phone: phone,
                      role: _selectedRole,
                      status: _isEnabled ? 'Enabled' : 'Disabled',
                      password: _passwordController.text,
                      confirmPassword: _confirmPasswordController.text,
                    );
                  }

                  if (mounted) {
                    if (result == null) {
                      Navigator.pop(context, true);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result), backgroundColor: Colors.red),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
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
    // For now, we'll just show a simple snackbar indicating the feature needs implementation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Viewing details for: ${user.fullName}'),
          backgroundColor: AppColors.primaryOrange,
        ),
      );
    }
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User archived successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the users section
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive user: $result'),
              backgroundColor: Colors.red,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the users section
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete user: $result'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // ==================== PRODUCT METHODS ====================

  Future<void> _showProductForm(BuildContext context, [AdminProduct? product]) async {
    if (!mounted) return;

    final isEdit = product != null;
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController(text: product?.name ?? '');
    final _barcodeController = TextEditingController(text: product?.barcode ?? '');
    final _descriptionController = TextEditingController(text: product?.description ?? '');
    final _priceController = TextEditingController(text: product?.price?.toString() ?? '');
    final _costController = TextEditingController(text: product?.cost?.toString() ?? '');
    final _quantityController = TextEditingController(text: product?.quantity?.toString() ?? '');
    final _unitController = TextEditingController(text: product?.unit ?? 'piece');
    
    String _selectedCategoryId = product?.categoryId ?? '';

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
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Name', icon: Icon(Icons.inventory)),
                    validator: (value) => (value == null || value.isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(labelText: 'Barcode', icon: Icon(Icons.barcode_reader)),
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description', icon: Icon(Icons.description)),
                    maxLines: 2,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(labelText: 'Price (₱)', icon: Icon(Icons.attach_money)),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _costController,
                          decoration: const InputDecoration(labelText: 'Cost (₱)'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          decoration: const InputDecoration(labelText: 'Stock', icon: Icon(Icons.numbers)),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _unitController,
                          decoration: const InputDecoration(labelText: 'Unit'),
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
                            value: _selectedCategoryId.isNotEmpty && _categories.any((c) => c.id == _selectedCategoryId) 
                                ? _selectedCategoryId 
                                : null,
                            decoration: const InputDecoration(labelText: 'Category', icon: Icon(Icons.category)),
                            items: [
                              const DropdownMenuItem<String>(value: '', child: Text('Select category')),
                              ..._categories.map((c) => DropdownMenuItem<String>(
                                value: c.id,
                                child: Text(c.name),
                              )),
                            ],
                            onChanged: (val) => setDialogState(() => _selectedCategoryId = val ?? ''),
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
                                setDialogState(() => _selectedCategoryId = added.id);
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
                if (!_formKey.currentState!.validate()) return;
                
                try {
                  final price = double.tryParse(_priceController.text) ?? 0.0;
                  final cost = double.tryParse(_costController.text) ?? 0.0;
                  final qty = double.tryParse(_quantityController.text) ?? 0.0;

                  String? error;
                  if (isEdit) {
                    error = await _productService.updateProduct(
                      id: product!.id,
                      name: _nameController.text.trim(),
                      barcode: _barcodeController.text.trim(),
                      description: _descriptionController.text.trim(),
                      price: price,
                      cost: cost,
                      quantity: qty,
                      unit: _unitController.text.trim(),
                      categoryId: _selectedCategoryId,
                    );
                  } else {
                    error = await _productService.createProduct(
                      name: _nameController.text.trim(),
                      barcode: _barcodeController.text.trim(),
                      description: _descriptionController.text.trim(),
                      price: price,
                      cost: cost,
                      quantity: qty,
                      unit: _unitController.text.trim(),
                      categoryId: _selectedCategoryId,
                    );
                  }

                  if (mounted) {
                    if (error == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Product ${isEdit ? 'updated' : 'added'} successfully'),
                        backgroundColor: Colors.green,
                      ));
                      Navigator.pop(context, true);
                      setState(() {});
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
                    }
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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

    final _formKey = GlobalKey<FormState>();
    final _quantityController = TextEditingController(text: product.quantity.toString());
    final _unitController = TextEditingController(text: product.unit);

    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Stock'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _quantityController,
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
                  controller: _unitController,
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
              if (!_formKey.currentState!.validate()) {
                return;
              }

              final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
              final unit = _unitController.text.trim();

              try {
                await _productService.adjustStock(
                  product.id,
                  quantity.toDouble(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stock adjusted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                if (mounted) {
                  Navigator.pop(context, true);
                  // Refresh the products section
                  setState(() {});
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to adjust stock: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product archived successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the products section
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to archive product: $result'),
              backgroundColor: Colors.red,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the products section
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete product: $result'),
              backgroundColor: Colors.red,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product restored successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the archived section
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to restore product: $result'),
              backgroundColor: Colors.red,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User restored successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the archived section
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to restore user: $result'),
              backgroundColor: Colors.red,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category restored successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the archived section
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to restore category: $result'),
              backgroundColor: Colors.red,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the archived section
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete product: $result'),
              backgroundColor: Colors.red,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the archived section
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete user: $result'),
              backgroundColor: Colors.red,
            ),
          );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the archived section
          setState(() {});
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete category: $result'),
              backgroundColor: Colors.red,
            ),
          );
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
          onPageChange: (_, __) {},
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
          onPageChange: (_, __) {},
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
          onPageChange: (_, __) {},
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
          onPageChange: (_, __) {},
          onShowReceipt: (sale) => {}, // TODO: Implement show receipt
          onVoidSale: (sale) => {}, // TODO: Implement void sale
          onCopyText: (_, __) {}, // TODO: Implement copy text
          onClearFilters: () {}, // TODO: Implement clear filters
        );
      case AdminSection.activity:
        return ActivitySection(
          auditService: _auditService,
          searchQuery: '',
          rowsPerPage: 10,
          pages: const {},
          onPageChange: (_, __) {},
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
          onPageChange: (_, __) {},
          onRestoreProduct: (product) => _restoreProduct(context, product),
          onDeleteProduct: (product) => _deleteProductFromArchived(context, product),
          onRestoreUser: (user) => _restoreUser(context, user),
          onDeleteUser: (user) => _deleteUserFromArchived(context, user),
          onRestoreCategory: (category) => _restoreCategory(context, category),
          onDeleteCategory: (category) => _deleteCategoryFromArchived(context, category),
          onClearFilters: () => setState(() {}),
        );
      default:
        // For sections that aren't implemented yet, show a placeholder
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              const Icon(Icons.construction_rounded, size: 64, color: AppColors.placeholderColor),
              const SizedBox(height: 16),
              Text('Feature Coming Soon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.placeholderColor)),
              const SizedBox(height: 8),
              Text('This part of the management portal is currently under development.', style: TextStyle(color: AppColors.placeholderColor)),
            ],
          ),
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