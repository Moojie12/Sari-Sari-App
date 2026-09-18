import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../controllers/admin_controller.dart';
import '../widgets/dashboard_shared.dart';

class CategoriesSection extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final query = searchQuery.toLowerCase().trim();
    final categories = controller.activeCategories
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
            label: 'Add category',
            onPressed: () => onShowCategoryForm(null),
          ),
        ),
        const SizedBox(height: 20),
        if (categories.isEmpty)
          emptyState(
            icon: Icons.sell_outlined,
            title: searchQuery.isEmpty
                ? 'No categories yet'
                : 'No categories match "$searchQuery"',
            message:
            'Categories group your products — beverages, snacks, household, and so on.',
            actionLabel: 'Add category',
            onAction: () => onShowCategoryForm(null),
          )
        else
          _buildTable(categories),
      ],
    );
  }

  Widget _buildTable(List<AdminCategory> categories) {
    final paged = paginate(categories, 'categories', rowsPerPage, pages);

    return tableShell(
      minWidth: 820,
      columnWidths: const {
        0: FlexColumnWidth(2.2),
        1: FlexColumnWidth(4),
        2: FlexColumnWidth(1.6),
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
              style: TextStyle(
                fontSize: 13,
                color: category.description.isEmpty
                    ? AppColors.placeholderColor
                    : AppColors.secondaryText,
              ),
            )),
            cell(Builder(builder: (context) {
              final count =
              controller.getActiveProductCountForCategory(category.id);
              return Text(
                count == 0
                    ? 'None yet'
                    : '$count ${count == 1 ? 'product' : 'products'}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: count > 0
                      ? AppColors.primaryOrange
                      : AppColors.placeholderColor,
                ),
              );
            })),
            cell(
              Row(
                children: [
                  iconAction(Icons.edit_outlined, 'Edit', Colors.blue,
                          () => onShowCategoryForm(category)),
                  iconAction(Icons.archive_outlined, 'Archive', Colors.orange,
                          () => onArchiveCategory(category)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(paged, 'categories', 'categories', pages, onPageChange),
    );
  }
}
