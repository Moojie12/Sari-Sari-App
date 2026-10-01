import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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
  String _archiveTypeFilter = 'All';
  String _productSort = 'name';
  bool _productAsc = true;
  String _userSort = 'name';
  bool _userAsc = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant ArchivedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminProduct> _archivedProducts() {
    // Wait for service to initialize
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

    final query = (_searchController.text.isNotEmpty ? _searchController.text : widget.searchQuery).toLowerCase().trim();
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

  bool get _hasFilters => _searchController.text.isNotEmpty || widget.searchQuery.isNotEmpty;

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
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryOrange,
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth <= 0) {
              return const SizedBox.shrink();
            }

            return DefaultTabController(
              length: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  toolbar(
                    filters: [
                      searchFilter(
                        controller: _searchController,
                        hintText: 'Search archived items...',
                        onChanged: (value) => setState(() {
                          widget.onPageChange('archived', 1);
                        }),
                        onClear: () => setState(() {
                          widget.onPageChange('archived', 1);
                        }),
                      ),
                      dropdownFilter(
                        label: 'Type',
                        value: _archiveTypeFilter,
                        options: const ['All', 'Products', 'Users'],
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
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 600,
                    child: TabBarView(
                      children: [
                        SingleChildScrollView(child: _buildArchivedProductsTab()),
                        SingleChildScrollView(child: _buildArchivedUsersTab()),
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
            actionLabel: _hasFilters ? 'Reset Filters' : 'Restore Selected',
            onAction: _hasFilters
                ? () {
                  setState(() {
                    _searchController.clear();
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
            actionLabel: _hasFilters ? 'Reset Filters' : 'Restore Selected',
            onAction: _hasFilters
                ? () {
                  setState(() {
                    _searchController.clear();
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
        header('Status'),
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
      footer: paginationBar(paged, 'archived_users', 'users', {}, widget.onPageChange),
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