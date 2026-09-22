import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../services/admin_product_service.dart';
import '../../services/admin_user_service.dart';
import '../../services/admin_category_service.dart';
import '../widgets/dashboard_shared.dart';

class ArchivedSection extends StatefulWidget {
  final AdminProductService productService;
  final AdminUserService userService;
  final AdminCategoryService categoryService;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final void Function(String, int) onPageChange;
  final void Function(AdminProduct) onRestoreProduct;
  final void Function(AdminProduct) onDeleteProduct;
  final void Function(AdminUser) onRestoreUser;
  final void Function(AdminUser) onDeleteUser;
  final void Function(AdminCategory) onRestoreCategory;
  final void Function(AdminCategory) onDeleteCategory;
  final void Function() onClearFilters;

  const ArchivedSection({
    super.key,
    required this.productService,
    required this.userService,
    required this.categoryService,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.onPageChange,
    required this.onRestoreProduct,
    required this.onDeleteProduct,
    required this.onRestoreUser,
    required this.onDeleteUser,
    required this.onRestoreCategory,
    required this.onDeleteCategory,
    required this.onClearFilters,
  });

  @override
  State<ArchivedSection> createState() => _ArchivedSectionState();
}

class _ArchivedSectionState extends State<ArchivedSection> {
  String _archiveTypeFilter = 'All';
  String _productSort = 'name';
  bool _productAsc = true;
  String _userSort = 'name';
  bool _userAsc = true;
  String _categorySort = 'name';
  bool _categoryAsc = true;
  late String _searchQuery;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.searchQuery;
  }

  List<AdminProduct> _archivedProducts() {
    // Wait for service to initialize
    if (!widget.productService.isInitialized) {
      return [];
    }

    final query = _searchQuery.toLowerCase().trim();
    final list = widget.productService.archivedProducts.where((p) {
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.barcode.contains(query) ||
          p.description.toLowerCase().contains(query);
      return matchesQuery;
    }).toList();

    int compare(AdminProduct a, AdminProduct b) {
      switch (_productSort) {
        case 'price':
          return a.price.compareTo(b.price);
        case 'margin':
          return a.marginPercent.compareTo(b.marginPercent);
        case 'stock':
          return a.quantity.compareTo(b.quantity);
        case 'category':
          return a.categoryName
              .toLowerCase()
              .compareTo(b.categoryName.toLowerCase());
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    }

    list.sort((a, b) => _productAsc ? compare(a, b) : compare(b, a));
    return list;
  }

  List<AdminUser> _archivedUsers() {
    // Wait for service to initialize
    if (!widget.userService.isInitialized) {
      return [];
    }

    final query = _searchQuery.toLowerCase().trim();
    final list = widget.userService.archivedUsers.where((u) {
      final matchesQuery = query.isEmpty ||
          u.fullName.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.phone.contains(query);
      return matchesQuery;
    }).toList();

    int compare(AdminUser a, AdminUser b) {
      switch (_userSort) {
        case 'joined':
          final ad = a.createdAt ?? DateTime(1970);
          final bd = b.createdAt ?? DateTime(1970);
          return ad.compareTo(bd);
        default:
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      }
    }

    list.sort((a, b) => _userAsc ? compare(a, b) : compare(b, a));
    return list;
  }

  List<AdminCategory> _archivedCategories() {
    // Wait for service to initialize
    if (!widget.categoryService.isInitialized) {
      return [];
    }

    final query = _searchQuery.toLowerCase().trim();
    final list = widget.categoryService.archivedCategories.where((c) {
      final matchesQuery = query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query);
      return matchesQuery;
    }).toList();

    int compare(AdminCategory a, AdminCategory b) {
      switch (_categorySort) {
        case 'name':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        default:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    }

    list.sort((a, b) => _categoryAsc ? compare(a, b) : compare(b, a));
    return list;
  }

  void _onProductSort(String key) {
    setState(() {
      if (_productSort == key) {
        _productAsc = !_productAsc;
      } else {
        _productSort = key;
        _productAsc = true;
      }
    });
  }

  void _onUserSort(String key) {
    setState(() {
      if (_userSort == key) {
        _userAsc = !_userAsc;
      } else {
        _userSort = key;
        _userAsc = true;
      }
    });
  }

  void _onCategorySort(String key) {
    setState(() {
      if (_categorySort == key) {
        _categoryAsc = !_categoryAsc;
      } else {
        _categorySort = key;
        _categoryAsc = true;
      }
    });
  }

  bool get _hasFilters =>
      widget.searchQuery.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.productService,
        widget.userService,
        widget.categoryService,
      ]),
      builder: (context, _) {
        final anyLoading = widget.productService.isLoading ||
            widget.userService.isLoading ||
            widget.categoryService.isLoading;
        final allInitialized = widget.productService.isInitialized &&
            widget.userService.isInitialized &&
            widget.categoryService.isInitialized;

        if (!allInitialized && anyLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryOrange,
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            // Defensive check: If the layout hasn't determined a width yet, wait.
            // This prevents "Cannot hit test a render box with no size" errors.
            if (constraints.maxWidth <= 0) {
              return const SizedBox.shrink();
            }

            return DefaultTabController(
              length: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  toolbar(
                    filters: [
                      dropdownFilter(
                        label: 'Type',
                        value: _archiveTypeFilter,
                        options: const ['All', 'Products', 'Users', 'Categories'],
                        onChanged: (value) => setState(() {
                          _archiveTypeFilter = value;
                        }),
                      ),
                    ],
                    action: primaryButton(
                      icon: Icons.restore_from_trash,
                      label: 'Restore All',
                      onPressed: () {
                        // TODO: Implement restore all functionality
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  TabBar(
                    labelColor: AppColors.primaryOrange,
                    unselectedLabelColor: AppColors.secondaryText,
                    indicatorColor: AppColors.primaryOrange,
                    tabs: const [
                      Tab(text: 'Products'),
                      Tab(text: 'Users'),
                      Tab(text: 'Categories'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Use a constrained height for TabBarView inside a Column
                  // or use Expanded if the parent provides constraints.
                  SizedBox(
                    height: 600, // Provide a default height to ensure rendering
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(child: _buildArchivedProductsTab()),
                        SingleChildScrollView(child: _buildArchivedUsersTab()),
                        SingleChildScrollView(child: _buildArchivedCategoriesTab()),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildArchivedProductsTab() {
    final products = _archivedProducts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toolbar(
          filters: [
            dropdownFilter(
              label: 'Sort',
              value: _productSort,
              options: const ['name', 'price', 'margin', 'stock', 'category'],
              onChanged: (value) => setState(() {
                _productSort = value;
              }),
            ),
          ],
          action: primaryButton(
            icon: Icons.restore_from_trash,
            label: 'Restore Selected',
            onPressed: () {
              // TODO: Implement restore selected products
            },
          ),
        ),
        const SizedBox(height: 20),
        if (products.isEmpty)
          emptyState(
            icon: Icons.inventory_2_outlined,
            title: _hasFilters
                ? 'No archived products match those filters'
                : 'No archived products yet',
            message: _hasFilters
                ? 'Try a different search term.'
                : 'Archived products will appear here when you archive them.',
            actionLabel: _hasFilters ? 'Clear filters' : 'Restore Selected',
            onAction: _hasFilters
                ? () {
                  setState(() {
                    _searchQuery = '';
                  });
                  widget.onClearFilters();
                }
                : () {
                  // TODO: Implement restore selected
                },
          )
        else
          _buildArchivedProductsTable(products),
      ],
    );
  }

  Widget _buildArchivedProductsTable(List<AdminProduct> products) {
    final paged = paginate(products, 'archived_products', 10, {});

    return tableShell(
      minWidth: 800,
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1.5),
        5: FixedColumnWidth(150),
      },
      header: [
        sortableHeader('Product', 'name', _productSort, _productAsc, _onProductSort),
        header('Category'),
        header('Price'),
        header('Cost'),
        header('Stock'),
        header('Actions'),
      ],
      rows: [
        for (final product in paged.items)
          [
            cell(Text(
              product.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            )),
            cell(Text(
              product.categoryName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            )),
            cell(Text(
              formatPeso(product.price),
              style: const TextStyle(fontWeight: FontWeight.w700),
            )),
            cell(Text(
              formatPeso(product.cost),
              style: const TextStyle(fontSize: 13),
            )),
            cell(Text(
              formatQuantity(product.quantity, product.unit),
              style: const TextStyle(fontSize: 13),
            )),
            cell(
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  iconAction(Icons.edit_outlined, 'Edit', Colors.blue,
                          () => {}), // TODO: Implement edit archived product
                  iconAction(Icons.restore_from_trash, 'Restore', Colors.green,
                          () => widget.onRestoreProduct(product)),
                  iconAction(Icons.delete_outline_rounded, 'Delete', Colors.red,
                          () => widget.onDeleteProduct(product)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(paged, 'archived_products', 'products', {}, widget.onPageChange),
    );
  }

  Widget _buildArchivedUsersTab() {
    final users = _archivedUsers();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toolbar(
          filters: [
            dropdownFilter(
              label: 'Sort',
              value: _userSort,
              options: const ['name', 'joined'],
              onChanged: (value) => setState(() {
                _userSort = value;
              }),
            ),
          ],
          action: primaryButton(
            icon: Icons.restore_from_trash,
            label: 'Restore Selected',
            onPressed: () {
              // TODO: Implement restore selected users
            },
          ),
        ),
        const SizedBox(height: 20),
        if (users.isEmpty)
          emptyState(
            icon: Icons.person_search_outlined,
            title: _hasFilters
                ? 'No archived users match those filters'
                : 'No archived users yet',
            message: _hasFilters
                ? 'Try a different search term.'
                : 'Archived users will appear here when you archive them.',
            actionLabel: _hasFilters ? 'Clear filters' : 'Restore Selected',
            onAction: _hasFilters
                ? () {
                  setState(() {
                    _searchQuery = '';
                  });
                  widget.onClearFilters();
                }
                : () {
                  // TODO: Implement restore selected
                },
          )
        else
          _buildArchivedUsersTable(users),
      ],
    );
  }

  Widget _buildArchivedUsersTable(List<AdminUser> users) {
    final paged = paginate(users, 'archived_users', 10, {});

    return tableShell(
      minWidth: 900,
      columnWidths: const {
        0: FlexColumnWidth(2.6),
        1: FlexColumnWidth(2.6),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.4),
        4: FlexColumnWidth(1.4),
        5: FixedColumnWidth(150),
      },
      header: [
        sortableHeader('Name', 'name', _userSort, _userAsc, _onUserSort),
        header('Contact'),
        sortableHeader('Role', 'role', _userSort, _userAsc, _onUserSort),
        header('State'),
        sortableHeader('Joined', 'joined', _userSort, _userAsc, _onUserSort),
        header('Actions'),
      ],
      rows: [
        for (final user in paged.items)
          [
            cell(
              InkWell(
                onTap: () => {}, // TODO: Implement view user detail
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.lightPeach,
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            cell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.darkText),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      user.phone,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.placeholderColor,
                      ),
                    ),
                  ],
                ),
              ],
            )),
            cell(_rolePill(user.role)),
            cell(statusPill(
              user.status,
              user.isActive ? Colors.green : AppColors.placeholderColor,
            )),
            cell(Text(
              formatDate(user.createdAt),
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.secondaryText),
            )),
            cell(
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  iconAction(Icons.visibility_outlined, 'View', Colors.blueGrey,
                          () => {}), // TODO: Implement view user
                  iconAction(Icons.edit_outlined, 'Edit', Colors.blue,
                          () => {}), // TODO: Implement edit archived user
                  iconAction(Icons.restore_from_trash, 'Restore', Colors.green,
                          () => widget.onRestoreUser(user)),
                  iconAction(Icons.delete_outline_rounded, 'Delete', Colors.red,
                          () => widget.onDeleteUser(user)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(paged, 'archived_users', 'users', {}, widget.onPageChange),
    );
  }

  Widget _buildArchivedCategoriesTab() {
    final categories = _archivedCategories();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toolbar(
          filters: const [],
          action: primaryButton(
            icon: Icons.restore_from_trash,
            label: 'Restore Selected',
            onPressed: () {
              // TODO: Implement restore selected categories
            },
          ),
        ),
        const SizedBox(height: 20),
        if (categories.isEmpty)
          emptyState(
            icon: Icons.sell_outlined,
            title: _hasFilters
                ? 'No archived categories match those filters'
                : 'No archived categories yet',
            message: _hasFilters
                ? 'Try a different search term.'
                : 'Archived categories will appear here when you archive them.',
            actionLabel: _hasFilters ? 'Clear filters' : 'Restore Selected',
            onAction: _hasFilters
                ? () {
                  setState(() {
                    _searchQuery = '';
                  });
                  widget.onClearFilters();
                }
                : () {
                  // TODO: Implement restore selected
                },
          )
        else
          _buildArchivedCategoriesTable(categories),
      ],
    );
  }

  Widget _buildArchivedCategoriesTable(List<AdminCategory> categories) {
    final paged = paginate(categories, 'archived_categories', 10, {});

    return tableShell(
      minWidth: 800,
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(4),
        2: FlexColumnWidth(1.5),
        3: FixedColumnWidth(120),
      },
      header: [
        sortableHeader('Category', 'name', _categorySort, _categoryAsc, _onCategorySort),
        header('Description'),
        header('Products'),
        header('Actions'),
      ],
      rows: [
        for (final category in paged.items)
          [
            cell(Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600))),
            cell(Text(
              category.description.isEmpty ? '—' : category.description,
              style: const TextStyle(color: AppColors.secondaryText, fontSize: 13),
            )),
            cell(Text(
              '${widget.productService.getActiveProductCountForCategory(category.id)} products',
              style: const TextStyle(fontSize: 13),
            )),
            cell(
              Row(
                children: [
                  iconAction(Icons.edit_outlined, 'Edit', Colors.blue,
                          () => {}), // TODO: Implement edit archived category
                  iconAction(Icons.restore_from_trash, 'Restore', Colors.green,
                          () => widget.onRestoreCategory(category)),
                  iconAction(Icons.delete_outline_rounded, 'Delete', Colors.red,
                          () => widget.onDeleteCategory(category)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(paged, 'archived_categories', 'categories', {}, widget.onPageChange),
    );
  }

  Widget _rolePill(AdminRole role) {
    Color color;
    switch (role) {
      case AdminRole.admin:
        color = Colors.indigo;
        break;
      case AdminRole.owner:
        color = Colors.purple;
        break;
      case AdminRole.employee:
        color = Colors.blue;
        break;
      case AdminRole.customer:
        color = Colors.teal;
        break;
    }
    return statusPill(role.label, color);
  }
}