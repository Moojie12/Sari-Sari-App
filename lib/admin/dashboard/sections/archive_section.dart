import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../controllers/admin_controller.dart';
import '../widgets/dashboard_shared.dart';

class ArchiveSection extends StatefulWidget {
  final AdminController controller;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final void Function(String, int) onPageChange;
  final void Function(AdminUser) onRestoreUser;
  final void Function(AdminUser) onDeleteUser;
  final void Function(AdminProduct) onRestoreProduct;
  final void Function(AdminProduct) onDeleteProduct;
  final void Function(AdminCategory) onRestoreCategory;
  final void Function(AdminCategory) onDeleteCategory;

  const ArchiveSection({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.onPageChange,
    required this.onRestoreUser,
    required this.onDeleteUser,
    required this.onRestoreProduct,
    required this.onDeleteProduct,
    required this.onRestoreCategory,
    required this.onDeleteCategory,
  });

  @override
  State<ArchiveSection> createState() => _ArchiveSectionState();
}

class _ArchiveSectionState extends State<ArchiveSection> {
  int _archivedTab = 0; // 0 users, 1 products, 2 categories

  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery.toLowerCase().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _tabPill('People', widget.controller.archivedUsers.length, 0),
            _tabPill('Products', widget.controller.archivedProducts.length, 1),
            _tabPill('Categories', widget.controller.archivedCategories.length, 2),
          ],
        ),
        const SizedBox(height: 22),
        if (_archivedTab == 0)
          _buildArchivedUsers(query)
        else if (_archivedTab == 1)
          _buildArchivedProducts(query)
        else
          _buildArchivedCategories(query),
      ],
    );
  }

  Widget _tabPill(String label, int count, int index) {
    final isActive = _archivedTab == index;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        _archivedTab = index;
        widget.onPageChange('archive', 1);
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryOrange : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive ? Colors.transparent : AppColors.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.darkText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withValues(alpha: 0.25)
                    : AppColors.lightBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchivedUsers(String query) {
    final list = widget.controller.archivedUsers
        .where((u) =>
    query.isEmpty ||
        u.fullName.toLowerCase().contains(query) ||
        u.email.toLowerCase().contains(query))
        .toList();

    if (list.isEmpty) {
      return emptyState(
        icon: Icons.person_off_outlined,
        title: 'No archived people',
        message: 'When you archive someone they land here, and you can bring them back any time.',
      );
    }

    final paged = paginate(list, 'archived-users', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 860,
      columnWidths: const {
        0: FlexColumnWidth(2.6),
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(2.2),
        3: FixedColumnWidth(240),
      },
      header: [
        header('Name'),
        header('Role'),
        header('Archived'),
        header('Actions'),
      ],
      rows: [
        for (final user in paged.items)
          [
            cell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.placeholderColor,
                  ),
                ),
              ],
            )),
            cell(_rolePill(user.role)),
            cell(Text(
              '${formatDate(user.archivedAt)}\nby ${user.archivedBy ?? 'unknown'}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText, height: 1.4),
            )),
            cell(
              _archiveActions(
                onRestore: () => widget.onRestoreUser(user),
                onDelete: () => widget.onDeleteUser(user),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ],
      ],
      footer: paginationBar(paged, 'archived-users', 'people', widget.pages, widget.onPageChange),
    );
  }

  Widget _buildArchivedProducts(String query) {
    final list = widget.controller.archivedProducts
        .where((p) =>
    query.isEmpty ||
        p.name.toLowerCase().contains(query) ||
        p.categoryName.toLowerCase().contains(query))
        .toList();

    if (list.isEmpty) {
      return emptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No archived products',
        message: 'Archived products stay out of the till but keep their sales history.',
      );
    }

    final paged = paginate(list, 'archived-products', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 900,
      columnWidths: const {
        0: FlexColumnWidth(2.8),
        1: FlexColumnWidth(1.8),
        2: FlexColumnWidth(2),
        3: FixedColumnWidth(240),
      },
      header: [
        header('Product'),
        header('Category'),
        header('Archived'),
        header('Actions'),
      ],
      rows: [
        for (final product in paged.items)
          [
            cell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  '${formatPeso(product.price)} · ${formatQuantity(product.quantity, product.unit)} left',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.placeholderColor,
                  ),
                ),
              ],
            )),
            cell(Builder(builder: (context) {
              final category = widget.controller.categoryById(product.categoryId);
              final isAvailable = category != null && !category.isArchived;
              return Row(
                children: [
                  Flexible(
                    child: Text(
                      product.categoryName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                    ),
                  ),
                  if (!isAvailable) ...[
                    const SizedBox(width: 6),
                    const Tooltip(
                      message: 'This category is archived too',
                      child: Icon(Icons.info_outline, size: 14, color: Colors.orange),
                    ),
                  ],
                ],
              );
            })),
            cell(Text(
              '${formatDate(product.archivedAt)}\nby ${product.archivedBy ?? 'unknown'}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText, height: 1.4),
            )),
            cell(
              _archiveActions(
                onRestore: () => widget.onRestoreProduct(product),
                onDelete: () => widget.onDeleteProduct(product),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ],
      ],
      footer: paginationBar(paged, 'archived-products', 'products', widget.pages, widget.onPageChange),
    );
  }

  Widget _buildArchivedCategories(String query) {
    final list = widget.controller.archivedCategories
        .where((c) => query.isEmpty || c.name.toLowerCase().contains(query))
        .toList();

    if (list.isEmpty) {
      return emptyState(
        icon: Icons.layers_clear_outlined,
        title: 'No archived categories',
        message: 'Categories you stop using end up here.',
      );
    }

    final paged = paginate(list, 'archived-categories', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 820,
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(1.6),
        3: FixedColumnWidth(240),
      },
      header: [
        header('Category'),
        header('Description'),
        header('Products attached'),
        header('Actions'),
      ],
      rows: [
        for (final category in paged.items)
          [
            cell(Text(
              category.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
                fontSize: 13.5,
              ),
            )),
            cell(Text(
              category.description.isEmpty
                  ? 'No description'
                  : category.description,
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
            )),
            cell(Builder(builder: (context) {
              final count = widget.controller.getProductCountForCategory(category.id);
              return Text(
                count == 0 ? 'None' : '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: count > 0 ? Colors.orange : AppColors.placeholderColor,
                ),
              );
            })),
            cell(
              _archiveActions(
                onRestore: () => widget.onRestoreCategory(category),
                onDelete: () => widget.onDeleteCategory(category),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ],
      ],
      footer: paginationBar(paged, 'archived-categories', 'categories', widget.pages, widget.onPageChange),
    );
  }

  Widget _rolePill(AdminRole role) {
    Color color;
    switch (role) {
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

  Widget _archiveActions({
    required VoidCallback onRestore,
    required VoidCallback onDelete,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: onRestore,
          icon: const Icon(Icons.restore, size: 15),
          label: const Text('Restore'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green[700],
            side: BorderSide(color: Colors.green.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 12.5),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 15),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red[700],
            side: BorderSide(color: Colors.red.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle: const TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
