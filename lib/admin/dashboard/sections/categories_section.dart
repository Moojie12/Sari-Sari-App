import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../services/admin_category_service.dart';
import '../../services/admin_product_service.dart';
import '../widgets/dashboard_shared.dart';

class CategoriesSection extends StatefulWidget {
  final AdminCategoryService categoryService;
  final AdminProductService productService;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final void Function(String, int) onPageChange;
  final void Function(AdminCategory?) onShowCategoryForm;
  final void Function(AdminCategory) onDeleteCategory;

  const CategoriesSection({
    super.key,
    required this.categoryService,
    required this.productService,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.onPageChange,
    required this.onShowCategoryForm,
    required this.onDeleteCategory,
  });

  @override
  State<CategoriesSection> createState() => _CategoriesSectionState();
}

class _CategoriesSectionState extends State<CategoriesSection> {
  late TextEditingController _searchController;
  late int _rowsPerPage;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _rowsPerPage = widget.rowsPerPage;
  }

  @override
  void didUpdateWidget(covariant CategoriesSection oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.categoryService, widget.productService]),
      builder: (context, _) {
        final anyLoading = widget.categoryService.isLoading || widget.productService.isLoading;
        final allInitialized = widget.categoryService.isInitialized && widget.productService.isInitialized;

        if (!allInitialized && anyLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryOrange,
            ),
          );
        }

        final query = (_searchController.text.isNotEmpty ? _searchController.text : widget.searchQuery).toLowerCase().trim();
        final categories = widget.categoryService.activeCategories
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
              filters: [
                searchFilter(
                  controller: _searchController,
                  hintText: 'Search category name...',
                  onChanged: (value) => setState(() {
                    widget.onPageChange('categories', 1);
                  }),
                  onClear: () => setState(() {
                    widget.onPageChange('categories', 1);
                  }),
                ),
              ],
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
      },
    );
  }

  Widget _buildTable(List<AdminCategory> categories) {
    final paged = paginate(categories, 'categories', _rowsPerPage, widget.pages);

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
            cell(Builder(
              builder: (_) {
                final active = widget.productService.getActiveProductCountForCategory(category.id);
                final total = widget.productService.getProductCountForCategory(category.id);
                final archived = total - active;
                if (archived > 0 && active > 0) {
                  return Text(
                    '$active active ($archived archived)',
                    style: const TextStyle(fontSize: 13),
                  );
                } else if (archived > 0) {
                  return Text(
                    '0 active ($archived archived)',
                    style: const TextStyle(fontSize: 13, color: Colors.orange),
                  );
                } else {
                  return Text(
                    '$active products',
                    style: const TextStyle(fontSize: 13),
                  );
                }
              },
            )),
            cell(
              Row(
                children: [
                  iconAction(Icons.edit_outlined, 'Edit ${category.name}', Colors.blue,
                          () => widget.onShowCategoryForm(category)),
                  iconAction(Icons.delete_outline_rounded, 'Delete ${category.name}', Colors.red,
                          () => widget.onDeleteCategory(category)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(
        paged,
        'categories',
        'categories',
        widget.pages,
        widget.onPageChange,
        currentRowsPerPage: _rowsPerPage,
        onRowsPerPageChange: (newRows) {
          setState(() {
            _rowsPerPage = newRows;
          });
          widget.onPageChange('categories', 1);
        },
      ),
    );
  }
}