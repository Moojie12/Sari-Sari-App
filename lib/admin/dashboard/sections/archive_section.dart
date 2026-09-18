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
  int _tabIndex = 0; // 0: Users, 1: Products, 2: Categories

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _tabButton('People', 0),
            const SizedBox(width: 8),
            _tabButton('Products', 1),
            const SizedBox(width: 8),
            _tabButton('Categories', 2),
          ],
        ),
        const SizedBox(height: 24),
        if (_tabIndex == 0) _buildArchivedUsers(),
        if (_tabIndex == 1) _buildArchivedProducts(),
        if (_tabIndex == 2) _buildArchivedCategories(),
      ],
    );
  }

  Widget _tabButton(String label, int index) {
    final bool isActive = _tabIndex == index;
    return InkWell(
      onTap: () => setState(() => _tabIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryOrange : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? AppColors.primaryOrange : AppColors.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.darkText,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedUsers() {
    final list = widget.controller.archivedUsers.where((u) =>
    widget.searchQuery.isEmpty || u.fullName.toLowerCase().contains(widget.searchQuery.toLowerCase())).toList();

    if (list.isEmpty) {
      return emptyState(icon: Icons.person_off_outlined, title: 'No archived people', message: 'Accounts you archive will appear here.');
    }

    final paged = paginate(list, 'archived-users', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 800,
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(2),
        3: FixedColumnWidth(220),
      },
      header: [header('Name'), header('Role'), header('Archived Date'), header('Actions')],
      rows: [
        for (final user in paged.items)
          [
            cell(Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600))),
            cell(statusPill(user.role.label, Colors.purple)),
            cell(Text(formatDate(user.archivedAt), style: const TextStyle(fontSize: 13))),
            cell(Row(children: [
              _restoreAction(() => widget.onRestoreUser(user)),
              _deleteAction(() => widget.onDeleteUser(user)),
            ])),
          ],
      ],
      footer: paginationBar(paged, 'archived-users', 'people', widget.pages, widget.onPageChange),
    );
  }

  Widget _buildArchivedProducts() {
    final list = widget.controller.archivedProducts.where((p) =>
    widget.searchQuery.isEmpty || p.name.toLowerCase().contains(widget.searchQuery.toLowerCase())).toList();

    if (list.isEmpty) {
      return emptyState(icon: Icons.inventory_2_outlined, title: 'No archived products', message: 'Products you archive will appear here.');
    }

    final paged = paginate(list, 'archived-products', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 800,
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FixedColumnWidth(220),
      },
      header: [header('Product'), header('Category'), header('Archived Date'), header('Actions')],
      rows: [
        for (final product in paged.items)
          [
            cell(Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600))),
            cell(Text(product.categoryName, style: const TextStyle(fontSize: 13))),
            cell(Text(formatDate(product.archivedAt), style: const TextStyle(fontSize: 13))),
            cell(Row(children: [
              _restoreAction(() => widget.onRestoreProduct(product)),
              _deleteAction(() => widget.onDeleteProduct(product)),
            ])),
          ],
      ],
      footer: paginationBar(paged, 'archived-products', 'products', widget.pages, widget.onPageChange),
    );
  }

  Widget _buildArchivedCategories() {
    final list = widget.controller.archivedCategories.where((c) =>
    widget.searchQuery.isEmpty || c.name.toLowerCase().contains(widget.searchQuery.toLowerCase())).toList();

    if (list.isEmpty) {
      return emptyState(icon: Icons.layers_clear_outlined, title: 'No archived categories', message: 'Categories you archive will appear here.');
    }

    final paged = paginate(list, 'archived-categories', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 800,
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(4),
        2: FixedColumnWidth(220),
      },
      header: [header('Category'), header('Description'), header('Actions')],
      rows: [
        for (final category in paged.items)
          [
            cell(Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600))),
            cell(Text(category.description, style: const TextStyle(fontSize: 13, color: AppColors.secondaryText))),
            cell(Row(children: [
              _restoreAction(() => widget.onRestoreCategory(category)),
              _deleteAction(() => widget.onDeleteCategory(category)),
            ])),
          ],
      ],
      footer: paginationBar(paged, 'archived-categories', 'categories', widget.pages, widget.onPageChange),
    );
  }

  Widget _restoreAction(VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.restore, size: 14),
        label: const Text('Restore'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green,
          side: const BorderSide(color: Colors.green),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _deleteAction(VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.delete_forever, size: 14),
      label: const Text('Delete'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.red,
        side: const BorderSide(color: Colors.red),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
