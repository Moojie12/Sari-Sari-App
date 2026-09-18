import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../controllers/admin_controller.dart';
import '../widgets/dashboard_shared.dart';

class CategoriesSection extends StatefulWidget {
  final AdminController controller;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final void Function(String, int) onPageChange;
  final void Function(AdminCategory?) onShowCategoryForm;
  final void Function(AdminCategory) onArchiveCategory;

  const CategoriesSection({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.onPageChange,
    required this.onShowCategoryForm,
    required this.onArchiveCategory,
  });

  @override
  State<CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<CategoriesSection> {
  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery.toLowerCase().trim();
    final categories = widget.controller.activeCategories
        .where((c) =>
    query.isEmpty ||
        c.name.toLowerCase().contains(query) ||
        c.description.toLowerCase().contains(query))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toolbar(
          filters: const [],
          action: primaryButton(
            icon: Icons.create_new_folder_outlined,
            label: 'Add Category',
            onPressed: () => widget.onShowCategoryForm(null),
          ),
        ),
        const SizedBox(height: 20),
        if (categories.isEmpty)
          emptyState(
            icon: Icons.sell_outlined,
            title: widget.searchQuery.isEmpty
                ? 'No categories yet'
                : 'No categories match "${widget.searchQuery}"',
            message: 'Group your products for better organization.',
            actionLabel: 'Add Category',
            onAction: () => widget.onShowCategoryForm(null),
          )
        else
          _buildTable(categories),
      ],
    );
  }

  Widget _buildTable(List<AdminCategory> categories) {
    final paged = paginate(categories, 'categories', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 800,
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(4),
        2: FlexColumnWidth(1.5),
        3: FixedColumnWidth(120),
      },
      header: [
        header('Category'),
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
              '${widget.controller.getActiveProductCountForCategory(category.id)} products',
              style: const TextStyle(fontSize: 13),
            )),
            cell(
              Row(
                children: [
                  iconAction(Icons.edit_outlined, 'Edit', Colors.blue,
                          () => widget.onShowCategoryForm(category)),
                  iconAction(Icons.archive_outlined, 'Archive', Colors.orange,
                          () => widget.onArchiveCategory(category)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(paged, 'categories', 'categories', widget.pages, widget.onPageChange),
    );
  }
}
