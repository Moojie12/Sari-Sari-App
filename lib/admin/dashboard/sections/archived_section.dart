import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/product_image.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../models/admin_models.dart';
import '../../services/admin_product_service.dart';
import '../../services/admin_user_service.dart';
import '../widgets/dashboard_shared.dart';

class ArchivedSection extends StatefulWidget {
  final AdminProductService productService;
  final AdminUserService userService;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final void Function(String, int) onPageChange;
  final void Function(AdminProduct) onRestoreProduct;
  final void Function(AdminProduct) onDeleteProduct;
  final void Function(AdminUser) onRestoreUser;
  final void Function(AdminUser) onDeleteUser;
  final void Function() onClearFilters;

  const ArchivedSection({
    super.key,
    required this.productService,
    required this.userService,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.onPageChange,
    required this.onRestoreProduct,
    required this.onDeleteProduct,
    required this.onRestoreUser,
    required this.onDeleteUser,
    required this.onClearFilters,
  });

  @override
  State<ArchivedSection> createState() => _ArchivedSectionState();
}

class _ArchivedSectionState extends State<ArchivedSection> {
  late TextEditingController _searchController;
  late int _rowsPerPage;
  int _selectedTab = 0; // 0: Products, 1: Users

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _rowsPerPage = widget.rowsPerPage;
  }

  @override
  void didUpdateWidget(covariant ArchivedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
    if (widget.rowsPerPage != oldWidget.rowsPerPage) {
      _rowsPerPage = widget.rowsPerPage;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminProduct> _archivedProducts() {
    if (!widget.productService.isInitialized) {
      return [];
    }

    final query = (_searchController.text.isNotEmpty ? _searchController.text : widget.searchQuery).toLowerCase().trim();
    final list = widget.productService.archivedProducts.where((p) {
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.barcode.contains(query) ||
          p.description.toLowerCase().contains(query);
      return matchesQuery;
    }).toList();

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<AdminUser> _archivedUsers() {
    if (!widget.userService.isInitialized) {
      return [];
    }

    final query = (_searchController.text.isNotEmpty ? _searchController.text : widget.searchQuery).toLowerCase().trim();
    final list = widget.userService.archivedUsers.where((u) {
      final matchesQuery = query.isEmpty ||
          u.fullName.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.phone.contains(query);
      return matchesQuery;
    }).toList();

    list.sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return list;
  }

  bool get _hasFilters => _searchController.text.isNotEmpty || widget.searchQuery.isNotEmpty;

  Widget _tabPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.productService,
        widget.userService,
      ]),
      builder: (context, _) {
        final anyLoading = widget.productService.isLoading ||
            widget.userService.isLoading;
        final allInitialized = widget.productService.isInitialized &&
            widget.userService.isInitialized;

        if (!allInitialized && anyLoading) {
          return Column(
            children: List.generate(
              5,
              (index) => const TableRowSkeleton(),
            ),
          );
        }

        final products = _archivedProducts();
        final users = _archivedUsers();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            toolbar(
              filters: [
                searchFilter(
                  controller: _searchController,
                  hintText: 'Search archived items...',
                  onChanged: (value) => setState(() {
                    widget.onPageChange(_selectedTab == 0 ? 'archived_products' : 'archived_users', 1);
                  }),
                  onClear: () => setState(() {
                    widget.onPageChange(_selectedTab == 0 ? 'archived_products' : 'archived_users', 1);
                  }),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tabPill(
                        label: 'Products (${widget.productService.archivedProducts.length})',
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() => _selectedTab = 0),
                      ),
                      const SizedBox(width: 4),
                      _tabPill(
                        label: 'Users (${widget.userService.archivedUsers.length})',
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() => _selectedTab = 1),
                      ),
                    ],
                  ),
                ),
              ],
              action: const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            if (_selectedTab == 0)
              _buildArchivedProductsTab(products)
            else
              _buildArchivedUsersTab(users),
          ],
        );
      },
    );
  }

  Widget _buildArchivedProductsTab(List<AdminProduct> products) {
    if (products.isEmpty) {
      return emptyState(
        icon: Icons.inventory_2_outlined,
        title: _hasFilters
            ? 'No archived products match those filters'
            : 'No archived products yet',
        message: _hasFilters
            ? 'Try a different search term.'
            : 'Archived products will appear here when you archive them.',
        actionLabel: _hasFilters ? 'Reset Filters' : null,
        onAction: _hasFilters
            ? () {
                setState(() {
                  _searchController.clear();
                });
                widget.onClearFilters();
              }
            : null,
      );
    }
    return _buildArchivedProductsTable(products);
  }

  Widget _buildArchivedProductsTable(List<AdminProduct> products) {
    final paged = paginate(products, 'archived_products', _rowsPerPage, widget.pages);

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
        header('Product'),
        header('Category'),
        header('Price'),
        header('Cost'),
        header('Stock'),
        header('Actions'),
      ],
      rows: [
        for (final product in paged.items)
          [
            cell(Row(
              children: [
                ProductImage(
                  image: product.image,
                  width: 36,
                  height: 36,
                  borderRadius: 8,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    product.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconAction(Icons.restore_from_trash, 'Restore', Colors.green,
                      () => widget.onRestoreProduct(product)),
                  const SizedBox(width: 8),
                  iconAction(Icons.delete_outline_rounded, 'Delete', Colors.red,
                      () => widget.onDeleteProduct(product)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(
        paged,
        'archived_products',
        'products',
        widget.pages,
        widget.onPageChange,
        currentRowsPerPage: _rowsPerPage,
        onRowsPerPageChange: (newRows) {
          setState(() {
            _rowsPerPage = newRows;
          });
          widget.onPageChange('archived_products', 1);
        },
      ),
    );
  }

  Widget _buildArchivedUsersTab(List<AdminUser> users) {
    if (users.isEmpty) {
      return emptyState(
        icon: Icons.person_search_outlined,
        title: _hasFilters
            ? 'No archived users match those filters'
            : 'No archived users yet',
        message: _hasFilters
            ? 'Try a different search term.'
            : 'Archived users will appear here when you archive them.',
        actionLabel: _hasFilters ? 'Reset Filters' : null,
        onAction: _hasFilters
            ? () {
                setState(() {
                  _searchController.clear();
                });
                widget.onClearFilters();
              }
            : null,
      );
    }
    return _buildArchivedUsersTable(users);
  }

  Widget _buildArchivedUsersTable(List<AdminUser> users) {
    final paged = paginate(users, 'archived_users', _rowsPerPage, widget.pages);

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
        header('Name'),
        header('Contact'),
        header('Role'),
        header('Status'),
        header('Joined'),
        header('Actions'),
      ],
      rows: [
        for (final user in paged.items)
          [
            cell(
              Row(
                children: [
                  AdminUserAvatar(
                    photoUrl: user.photoUrl,
                    initials: user.initials,
                    radius: 17,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconAction(Icons.restore_from_trash, 'Restore', Colors.green,
                      () => widget.onRestoreUser(user)),
                  const SizedBox(width: 8),
                  iconAction(Icons.delete_outline_rounded, 'Delete', Colors.red,
                      () => widget.onDeleteUser(user)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(
        paged,
        'archived_users',
        'users',
        widget.pages,
        widget.onPageChange,
        currentRowsPerPage: _rowsPerPage,
        onRowsPerPageChange: (newRows) {
          setState(() {
            _rowsPerPage = newRows;
          });
          widget.onPageChange('archived_users', 1);
        },
      ),
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
