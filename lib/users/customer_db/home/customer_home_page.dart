import 'package:flutter/material.dart';

import 'package:sari_sari/core/theme/app_colors.dart';
import 'package:sari_sari/shared/utils/top_notification.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';
import 'package:sari_sari/users/customer_db/customer_cart_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_details_page.dart';
import 'package:sari_sari/users/customer_db/home/customer_dummy_products.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_card.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_details_page.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_model.dart';

/// Customer "Home" tab: product browsing.
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({
    super.key,
    required this.cartController,
    required this.orderController,
  });

  final CustomerCartController cartController;
  final CustomerOrderController orderController;

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const int _itemsPerPage = 12;
  int _currentPage = 1;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isFiltering =>
      _searchQuery.isNotEmpty || _selectedCategory != 'All';

  CustomerProduct _mapToCustomerProduct(EmployeeProduct ep) {
    CustomerProductAvailability availability;
    switch (ep.stockStatus) {
      case EmployeeStockStatus.inStock:
        availability = CustomerProductAvailability.inStock;
        break;
      case EmployeeStockStatus.lowStock:
        availability = CustomerProductAvailability.lowStock;
        break;
      case EmployeeStockStatus.outOfStock:
        availability = CustomerProductAvailability.outOfStock;
        break;
    }

    return CustomerProduct(
      id: ep.id,
      name: ep.name,
      category: ep.category,
      price: ep.currentPrice,
      image: ep.image ?? '',
      availability: availability,
      isOnSale: ep.hasExpiringSoonBatch,
    );
  }

  List<CustomerProduct> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    final employeeProducts = EmployeeInventoryController.instance.products;

    return employeeProducts
        .map((ep) => _mapToCustomerProduct(ep))
        .where((product) {
      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;
      final matchesSearch =
          query.isEmpty || product.name.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  List<CustomerProduct> get _onSaleProducts {
    final employeeProducts = EmployeeInventoryController.instance.products;
    return employeeProducts
        .where((ep) => ep.hasExpiringSoonBatch)
        .map((ep) => _mapToCustomerProduct(ep))
        .toList();
  }

  void _onSearchChanged(String value) => setState(() {
        _searchQuery = value;
        _currentPage = 1;
      });

  void _onCategorySelected(String category) => setState(() {
        _selectedCategory = category;
        _currentPage = 1;
      });

  void _onPageSelected(int page) => setState(() => _currentPage = page);

  void _openProductDetails(CustomerProduct product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerProductDetailsPage(
          product: product,
          cartController: widget.cartController,
          orderController: widget.orderController,
        ),
      ),
    );
  }

  void _addToCart(CustomerProduct product) {
    final added = widget.cartController.addToCart(product);
    if (!added) return;
    TopNotification.show(context, 'Added to cart');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final int totalCount = filtered.length;
    final int totalPages = (totalCount / _itemsPerPage).ceil();

    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }

    final pagedProducts = filtered
        .skip((_currentPage - 1) * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return ListenableBuilder(
      listenable: EmployeeInventoryController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildTitle(context)),
              SliverToBoxAdapter(child: _buildWelcomeSection(context)),
              SliverToBoxAdapter(child: _buildActiveOrder(context)),
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              SliverToBoxAdapter(child: _buildCategories(context)),
              if (!_isFiltering)
                SliverToBoxAdapter(child: _buildOnSaleProducts(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Text(
                    _isFiltering ? 'Search Results' : 'All Products',
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (pagedProducts.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState(context))
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.65,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = pagedProducts[index];
                        return CustomerProductCard(
                          product: product,
                          onTap: () => _openProductDetails(product),
                          onAddToCart: () => _addToCart(product),
                        );
                      },
                      childCount: pagedProducts.length,
                    ),
                  ),
                ),
                if (totalPages > 1)
                  SliverToBoxAdapter(
                    child: _buildPagination(totalPages),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveOrder(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.orderController,
      builder: (context, _) {
        final activeOrders = widget.orderController.orders
            .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.delivered)
            .toList();
        if (activeOrders.isEmpty) return const SizedBox.shrink();

        final latestOrder = activeOrders.first;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: AppColors.primaryOrange.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Order',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        latestOrder.status.label,
                        style: const TextStyle(
                          color: AppColors.primaryOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: AppColors.primaryOrange,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #${latestOrder.orderId} · ${latestOrder.formattedDate}',
                            style: const TextStyle(
                              color: AppColors.darkText,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${latestOrder.items.length} items · ₱${latestOrder.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CustomerOrderDetailsPage(order: latestOrder),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Track',
                        style: TextStyle(
                          color: AppColors.primaryOrange,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageButton(
            icon: Icons.chevron_left,
            onPressed: _currentPage > 1
                ? () => _onPageSelected(_currentPage - 1)
                : null,
          ),
          const SizedBox(width: 8),
          ...List.generate(totalPages, (index) {
            final page = index + 1;
            final isSelected = page == _currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                onTap: () => _onPageSelected(page),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryOrange : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryOrange
                          : AppColors.borderColor.withValues(alpha: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$page',
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.darkText,
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          _PageButton(
            icon: Icons.chevron_right,
            onPressed: _currentPage < totalPages
                ? () => _onPageSelected(_currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Text(
        'What would you like to buy today?',
        style: TextStyle(
          color: AppColors.secondaryText.withValues(alpha: 0.7),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 50, 24, 4),
      child: Text(
        'Home',
        style: TextStyle(
          color: AppColors.darkText,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search products...',
          hintStyle: TextStyle(
            color: AppColors.secondaryText.withValues(alpha: 0.5),
            fontSize: 14,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.borderColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(BuildContext context) {
    final categories = EmployeeInventoryController.instance.categories;
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == _selectedCategory;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => _onCategorySelected(category),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.secondaryText,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            selectedColor: AppColors.primaryOrange,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? AppColors.primaryOrange
                    : AppColors.borderColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOnSaleProducts(BuildContext context) {
    final onSale = _onSaleProducts;
    if (onSale.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'On Sale Products',
              style: TextStyle(
                color: AppColors.darkText,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: onSale.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = onSale[index];
                return SizedBox(
                  width: 160,
                  child: CustomerProductCard(
                    product: product,
                    onTap: () => _openProductDetails(product),
                    onAddToCart: () => _addToCart(product),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 40,
            color: AppColors.secondaryText.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No products found',
            style: TextStyle(
              color: AppColors.secondaryText.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.borderColor.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null
                ? AppColors.placeholderColor
                : AppColors.darkText,
          ),
        ),
      ),
    );
  }
}
