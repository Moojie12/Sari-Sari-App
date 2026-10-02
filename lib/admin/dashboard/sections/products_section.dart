import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/product_image.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../models/admin_models.dart';
import '../../services/admin_product_service.dart';
import '../../services/admin_category_service.dart';
import '../widgets/dashboard_shared.dart';

class ProductsSection extends StatefulWidget {
  final AdminProductService productService;
  final AdminCategoryService categoryService;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final bool showCostColumn;
  final void Function(String, int) onPageChange;
  final void Function(AdminProduct?) onShowProductForm;
  final void Function(AdminProduct) onAdjustStock;
  final void Function(AdminProduct) onArchiveProduct;
  final void Function(AdminProduct) onDeleteProduct;
  final void Function(AdminCategory)? onDeleteCategory;
  final void Function() onClearFilters;

  const ProductsSection({
    super.key,
    required this.productService,
    required this.categoryService,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.showCostColumn,
    required this.onPageChange,
    required this.onShowProductForm,
    required this.onAdjustStock,
    required this.onArchiveProduct,
    required this.onDeleteProduct,
    this.onDeleteCategory,
    required this.onClearFilters,
  });

  @override
  State<ProductsSection> createState() => _ProductsSectionState();
}

class _ProductsSectionState extends State<ProductsSection> {
  late TextEditingController _searchController;
  late int _rowsPerPage;
  String _productCategoryFilter = 'All categories';
  String _productUnitFilter = 'All units';
  String _productStockFilter = 'All stock';
  String _productSort = 'name';
  bool _productAsc = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _rowsPerPage = widget.rowsPerPage;
  }

  @override
  void didUpdateWidget(covariant ProductsSection oldWidget) {
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

  List<AdminProduct> _filteredProducts() {
    // Wait for services to initialize
    if (!widget.productService.isInitialized ||
        !widget.categoryService.isInitialized) {
      return [];
    }

    final query = (_searchController.text.isNotEmpty ? _searchController.text : widget.searchQuery).toLowerCase().trim();
    final filterLower = _productCategoryFilter.trim().toLowerCase();
    
    // Find matching category object from both categoryService and productService to compare IDs as well
    AdminCategory? catObj;
    if (_productCategoryFilter != 'All categories') {
      catObj = widget.categoryService.activeCategories
          .where((c) => c.name.trim().toLowerCase() == filterLower || c.id.trim().toLowerCase() == filterLower)
          .firstOrNull;
      catObj ??= widget.productService.allCategories
          .where((c) => c.name.trim().toLowerCase() == filterLower || c.id.trim().toLowerCase() == filterLower)
          .firstOrNull;
    }
    final targetId = catObj?.id.trim().toLowerCase() ?? filterLower;
    final targetName = catObj?.name.trim().toLowerCase() ?? filterLower;

    final list = widget.productService.activeProducts.where((p) {
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.barcode.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query);

      bool matchesCategory;
      if (_productCategoryFilter == 'All categories') {
        matchesCategory = true;
      } else {
        final pCatNameLower = p.categoryName.trim().toLowerCase();
        final pCatIdLower = p.categoryId.trim().toLowerCase();

        final matchesId = targetId.isNotEmpty && (pCatIdLower == targetId || pCatNameLower == targetId);
        final matchesName = targetName.isNotEmpty && (pCatIdLower == targetName || pCatNameLower == targetName);

        matchesCategory = matchesId ||
            matchesName ||
            pCatNameLower == filterLower ||
            pCatIdLower == filterLower;
      }

      bool matchesUnit;
      if (_productUnitFilter == 'All units') {
        matchesUnit = true;
      } else if (_productUnitFilter == 'de kilo') {
        final u = p.unit.toLowerCase();
        matchesUnit = u == 'de kilo' || u == 'kg' || u == 'kilo';
      } else if (_productUnitFilter == 'pcs') {
        final u = p.unit.toLowerCase();
        matchesUnit = u == 'pcs' || u == 'piece' || u == 'pc';
      } else {
        matchesUnit = p.unit == _productUnitFilter;
      }

      bool matchesStock;
      switch (_productStockFilter) {
        case 'Low stock':
          matchesStock = p.isLowStock;
          break;
        case 'Out of stock':
          matchesStock = p.isOutOfStock;
          break;
        case 'Expiring soon':
          matchesStock = p.isExpiringSoon || p.isExpired;
          break;
        default:
          matchesStock = true;
      }

      return matchesQuery && matchesCategory && matchesUnit && matchesStock;
    }).toList();

    int compare(AdminProduct a, AdminProduct b) {
      // PREDETERMINED PRIORITY: Expiring products first
      final aExp = a.isExpired ? 2 : (a.isExpiringSoon ? 1 : 0);
      final bExp = b.isExpired ? 2 : (b.isExpiringSoon ? 1 : 0);
      if (aExp != bExp) {
        return bExp.compareTo(aExp);
      }

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

  void _onSort(String key) {
    setState(() {
      if (_productSort == key) {
        _productAsc = !_productAsc;
      } else {
        _productSort = key;
        _productAsc = true;
      }
      widget.onPageChange('products', 1);
    });
  }

  bool get _hasFilters =>
      _searchController.text.isNotEmpty ||
      widget.searchQuery.isNotEmpty ||
      _productCategoryFilter != 'All categories' ||
      _productUnitFilter != 'All units' ||
      _productStockFilter != 'All stock';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.productService, widget.categoryService]),
      builder: (context, _) {
        final anyLoading = widget.productService.isLoading || widget.categoryService.isLoading;
        final allInitialized = widget.productService.isInitialized && widget.categoryService.isInitialized;

        if (!allInitialized && anyLoading) {
          return Column(
            children: List.generate(
              6,
              (index) => const TableRowSkeleton(),
            ),
          );
        }

        final products = _filteredProducts();
        final categoryOptions = [
          'All categories',
          ...widget.categoryService.activeCategories.map((c) => c.name),
        ];

        final filterLower = _productCategoryFilter.trim().toLowerCase();
        final matchedOption = categoryOptions.where(
          (opt) => opt.trim().toLowerCase() == filterLower,
        ).firstOrNull;

        if (matchedOption != null) {
          _productCategoryFilter = matchedOption;
        } else {
          _productCategoryFilter = 'All categories';
        }
        final categoryValue = _productCategoryFilter;

        AdminCategory? selectedCategory;
        if (_productCategoryFilter != 'All categories') {
          final matches = widget.categoryService.activeCategories
              .where((c) => c.name.trim().toLowerCase() == filterLower || c.id.trim().toLowerCase() == filterLower);
          if (matches.isNotEmpty) {
            selectedCategory = matches.first;
          } else {
            final fallback = widget.productService.allCategories
                .where((c) => c.name.trim().toLowerCase() == filterLower || c.id.trim().toLowerCase() == filterLower);
            if (fallback.isNotEmpty) {
              selectedCategory = fallback.first;
            }
          }
        }

        final bool isCategoryFiltered = _productCategoryFilter != 'All categories';

        int archivedCatProducts = 0;
        if (selectedCategory != null) {
          final totalCount = widget.productService.getProductCountForCategory(selectedCategory.id);
          final activeCount = widget.productService.getActiveProductCountForCategory(selectedCategory.id);
          archivedCatProducts = totalCount - activeCount;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            toolbar(
              filters: [
                searchFilter(
                  controller: _searchController,
                  hintText: 'Search product or barcode...',
                  onChanged: (value) => setState(() {
                    widget.onPageChange('products', 1);
                  }),
                  onClear: () => setState(() {
                    widget.onPageChange('products', 1);
                  }),
                ),
                dropdownFilter(
                  label: 'Category',
                  value: categoryValue,
                  options: categoryOptions,
                  onChanged: (value) => setState(() {
                    _productCategoryFilter = value;
                    widget.onPageChange('products', 1);
                  }),
                ),
                dropdownFilter(
                  label: 'Unit',
                  value: _productUnitFilter,
                  options: ['All units', ...kProductUnits],
                  onChanged: (value) => setState(() {
                    _productUnitFilter = value;
                    widget.onPageChange('products', 1);
                  }),
                ),
                dropdownFilter(
                  label: 'Stock',
                  value: _productStockFilter,
                  options: const [
                    'All stock',
                    'Low stock',
                    'Out of stock',
                    'Expiring soon',
                  ],
                  onChanged: (value) => setState(() {
                    _productStockFilter = value;
                    widget.onPageChange('products', 1);
                  }),
                ),
              ],
              action: primaryButton(
                icon: Icons.add_box_outlined,
                label: 'Add product',
                onPressed: () => widget.onShowProductForm(null),
              ),
            ),
            const SizedBox(height: 20),
            if (products.isEmpty)
              emptyState(
                icon: Icons.inventory_2_outlined,
                title: isCategoryFiltered
                    ? 'No products in "$_productCategoryFilter"'
                    : (_hasFilters
                        ? 'No products match those filters'
                        : 'No products yet'),
                message: isCategoryFiltered
                    ? (archivedCatProducts > 0
                        ? 'This category has $archivedCatProducts archived product(s) in the Archived tab.'
                        : 'There are no products in the "$_productCategoryFilter" category.')
                    : (_hasFilters
                        ? 'Try resetting the category, unit or stock filter.'
                        : 'Add what you sell so it shows up at the till.'),
                actionLabel: isCategoryFiltered
                    ? 'Delete $_productCategoryFilter Category'
                    : (_hasFilters
                        ? 'Reset Filters'
                        : 'Add product'),
                onAction: isCategoryFiltered
                    ? () {
                        if (selectedCategory != null && widget.onDeleteCategory != null) {
                          widget.onDeleteCategory!(selectedCategory);
                        } else {
                          setState(() {
                            _searchController.clear();
                            _productCategoryFilter = 'All categories';
                            _productUnitFilter = 'All units';
                            _productStockFilter = 'All stock';
                          });
                          widget.onClearFilters();
                        }
                      }
                    : (_hasFilters
                        ? () {
                            setState(() {
                              _searchController.clear();
                              _productCategoryFilter = 'All categories';
                              _productUnitFilter = 'All units';
                              _productStockFilter = 'All stock';
                            });
                            widget.onClearFilters();
                          }
                        : () => widget.onShowProductForm(null)),
              )
            else
              _buildTable(products),
          ],
        );
      },
    );
  }

  Widget _buildTable(List<AdminProduct> products) {
    final paged = paginate(products, 'products', _rowsPerPage, widget.pages);

    return tableShell(
      minWidth: widget.showCostColumn ? 1020 : 880,
      columnWidths: {
        0: const FlexColumnWidth(2.8),
        1: const FlexColumnWidth(1.6),
        2: const FlexColumnWidth(1.2),
        if (widget.showCostColumn) 3: const FlexColumnWidth(1.5),
        (widget.showCostColumn ? 4 : 3): const FlexColumnWidth(1.6),
        (widget.showCostColumn ? 5 : 4): const FixedColumnWidth(110),
      },
      header: [
        sortableHeader('Product', 'name', _productSort, _productAsc, _onSort),
        sortableHeader('Category', 'category', _productSort, _productAsc, _onSort),
        sortableHeader('Price', 'price', _productSort, _productAsc, _onSort),
        if (widget.showCostColumn)
          sortableHeader('Cost / margin', 'margin', _productSort, _productAsc, _onSort),
        sortableHeader('Stock', 'stock', _productSort, _productAsc, _onSort),
        header('Actions'),
      ],
      rows: [
        for (final product in paged.items)
          [
            cell(Row(
              children: [
                ProductImage(
                  image: product.image,
                  width: 40,
                  height: 40,
                  borderRadius: 10,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              product.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.darkText,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (product.isExpired) ...[
                            const SizedBox(width: 8),
                            statusPill('Expired', Colors.red),
                          ] else if (product.isExpiringSoon) ...[
                            const SizedBox(width: 8),
                            statusPill('Expires soon', Colors.deepOrange),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        product.barcode.isEmpty
                            ? 'No barcode'
                            : product.barcode,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.placeholderColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )),
            cell(Text(
              product.categoryName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
            )),
            cell(Text(
              formatPeso(product.price),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
                fontSize: 13.5,
              ),
            )),
            if (widget.showCostColumn)
              cell(Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatPeso(product.cost),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    '${product.marginPercent.toStringAsFixed(0)}% margin',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: product.marginPercent < 10
                          ? Colors.red
                          : Colors.green[700],
                    ),
                  ),
                ],
              )),
            cell(Row(
              children: [
                statusPill(
                  product.isOutOfStock
                      ? 'Out of stock'
                      : formatQuantity(product.quantity, product.unit),
                  product.isOutOfStock
                      ? Colors.red
                      : product.isLowStock
                      ? Colors.orange
                      : Colors.green,
                ),
              ],
            )),
            cell(
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconAction(Icons.edit_outlined, 'Edit', Colors.blue,
                          () => widget.onShowProductForm(product)),
                  const SizedBox(width: 8),
                  iconAction(Icons.archive_outlined, 'Archive', Colors.orange,
                          () => widget.onArchiveProduct(product)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(
        paged,
        'products',
        'products',
        widget.pages,
        widget.onPageChange,
        currentRowsPerPage: _rowsPerPage,
        onRowsPerPageChange: (newRows) {
          setState(() {
            _rowsPerPage = newRows;
          });
          widget.onPageChange('products', 1);
        },
      ),
    );
  }
}