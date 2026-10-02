import 'package:flutter/material.dart';

import 'package:sari_sari/core/theme/app_colors.dart';
import 'package:sari_sari/shared/utils/top_notification.dart';
import 'package:sari_sari/shared/widgets/product_image.dart';
import 'package:sari_sari/users/customer_db/customer_dashboard.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';
import 'package:sari_sari/users/customer_db/customer_cart_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_details_page.dart';
import 'package:sari_sari/users/customer_db/checkout/customer_checkout_page.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_card.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_details_page.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_model.dart';
import 'package:sari_sari/shared/widgets/skeleton.dart';
import '../../../models/sale_deal_model.dart';
import '../../../core/services/sale_deal_controller.dart';
import 'package:sari_sari/users/customer_db/tutorial/customer_tutorial_keys.dart';

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
  final _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _isLoading = true;

  static const int _itemsPerPage = 20;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    SaleDealController.instance.addListener(_onSaleDealsUpdated);
    _simulateLoading();
  }

  void _onSaleDealsUpdated() {
    if (mounted) setState(() {});
  }

  void _simulateLoading() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    SaleDealController.instance.removeListener(_onSaleDealsUpdated);
    _searchController.dispose();
    _scrollController.dispose();
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
      capital: ep.capital,
      sellableQuantity: ep.sellableQuantity,
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

  void _onPageSelected(int page) {
    setState(() => _currentPage = page);
    _simulateLoading();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

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

  void _addToCart(CustomerProduct product, [Offset? startPosition]) {
    final added = widget.cartController.addToCart(product);
    if (!added) return;
    final pos = startPosition ?? Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
    CustomerDashboard.dashboardKey.currentState?.runFlyToCartAnimation(
      startOffset: pos,
      productImage: product.image,
    );
  }

  void _addSaleDealToCart(SaleDealModel deal, [Offset? startPosition]) {
    final employeeProducts = EmployeeInventoryController.instance.products;
    final allCustomerProducts = employeeProducts.map((ep) => _mapToCustomerProduct(ep)).toList();
    final success = widget.cartController.addSaleDeal(deal, allCustomerProducts);
    if (success) {
      final pos = startPosition ?? Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
      CustomerDashboard.dashboardKey.currentState?.runFlyToCartAnimation(
        startOffset: pos,
        productImage: deal.effectiveImage,
      );
    } else {
      TopNotification.show(context, 'Sorry, some items in this promo are out of stock.', isError: true);
    }
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
      listenable: Listenable.merge([
        EmployeeInventoryController.instance,
        SaleDealController.instance,
      ]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildTitle(context)),
              SliverToBoxAdapter(child: _buildWelcomeSection(context)),
              SliverToBoxAdapter(child: _buildActiveOrder(context)),
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              SliverToBoxAdapter(child: _buildCategories(context)),
              if (!_isFiltering && !_isLoading)
                SliverToBoxAdapter(child: _buildOnSaleProducts(context)),
              if (!_isFiltering && _isLoading)
                SliverToBoxAdapter(child: _buildOnSaleSkeletons()),
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
              if (!_isLoading && pagedProducts.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState(context))
              else if (_isLoading)
                _buildGridSkeletons()
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
                        final activeDeals = SaleDealController.instance.activeDeals;
                        final onSale = _onSaleProducts;
                        final firstInStock = pagedProducts.indexWhere((p) => !p.isOutOfStock);
                        final targetIdx = firstInStock != -1 ? firstInStock : 0;
                        final shouldAttachKey = activeDeals.isEmpty && onSale.isEmpty && index == targetIdx;
                        return CustomerProductCard(
                          key: index == 0 ? CustomerTutorialKeys.firstProductCardKey : null,
                          addToCartKey: shouldAttachKey ? CustomerTutorialKeys.addToCartKey : null,
                          product: product,
                          onTap: () => _openProductDetails(product),
                          onAddToCart: () => _addToCart(product),
                          onAddToCartWithPosition: (pos) => _addToCart(product, pos),
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

  int _getOrderStatusPriority(OrderStatus status) {
    switch (status) {
      case OrderStatus.outForDelivery:
      case OrderStatus.readyForPickup:
        return 1;
      case OrderStatus.readyForShipment:
        return 2;
      case OrderStatus.preparing:
        return 3;
      case OrderStatus.confirmed:
        return 4;
      case OrderStatus.pending:
        return 5;
      case OrderStatus.delivered:
      case OrderStatus.completed:
      case OrderStatus.cancelled:
        return 99;
    }
  }

  Widget _buildActiveOrder(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.orderController,
      builder: (context, _) {
        final activeOrders = widget.orderController.orders
            .where((o) =>
                o.status != OrderStatus.completed &&
                o.status != OrderStatus.cancelled &&
                o.status != OrderStatus.delivered)
            .toList();
        if (activeOrders.isEmpty) return const SizedBox.shrink();

        activeOrders.sort((a, b) {
          final priorityA = _getOrderStatusPriority(a.status);
          final priorityB = _getOrderStatusPriority(b.status);
          if (priorityA != priorityB) {
            return priorityA.compareTo(priorityB);
          }
          return b.orderDate.compareTo(a.orderDate);
        });

        final latestOrder = activeOrders.first;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          child: Material(
            color: AppColors.primaryOrange.withValues(alpha: 0.04), // Subtle tint
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomerOrderDetailsPage(order: latestOrder),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryOrange.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.primaryOrange.withValues(alpha: 0.4), // Brighter border
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
                          'My Order',
                          style: TextStyle(
                            color: AppColors.darkText,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrange.withValues(alpha: 0.15), // Brighter badge
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            latestOrder.status.label,
                            style: const TextStyle(
                              color: AppColors.primaryOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.w900, // Thicker font
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
                            color: AppColors.primaryOrange.withValues(alpha: 0.1), // Brightened icon bg
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
                                'Order #${latestOrder.displayOrderId} · ${latestOrder.formattedDate}',
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
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.primaryOrange,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
        key: CustomerTutorialKeys.searchBarKey,
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

  List<CustomerProduct> get _allCustomerProducts {
    final employeeProducts = EmployeeInventoryController.instance.products;
    return employeeProducts.map((ep) => _mapToCustomerProduct(ep)).toList();
  }

  void _buyNowSaleDeal(SaleDealModel deal) {
    widget.cartController.clearCart();
    final success = widget.cartController.addSaleDeal(deal, _allCustomerProducts);
    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomerCheckoutPage(
            cartController: widget.cartController,
            orderController: widget.orderController,
          ),
        ),
      );
    } else {
      TopNotification.show(context, 'Sorry, some items in this promo are out of stock.', isError: true);
    }
  }

  void _showSaleDealDetailsModal(BuildContext context, SaleDealModel deal) {
    showSaleDealDetailsModal(
      context: context,
      deal: deal,
      cartController: widget.cartController,
      orderController: widget.orderController,
    );
  }

  Widget _buildOnSaleProducts(BuildContext context) {
    final activeDeals = SaleDealController.instance.activeDeals;
    final onSale = _onSaleProducts;
    if (activeDeals.isEmpty && onSale.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  'On Sale Deals & Promos',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'HOT DEALS',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                // 1. Customized On-Sale Deals created by Owner
                ...activeDeals.map((deal) {
                  final isFirstDeal = activeDeals.isNotEmpty && deal.id == activeDeals.first.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _SaleDealCard(
                      addToCartKey: isFirstDeal ? CustomerTutorialKeys.addToCartKey : null,
                      deal: deal,
                      onTap: () => _showSaleDealDetailsModal(context, deal),
                      onAddToCart: () => _addSaleDealToCart(deal),
                      onAddToCartWithPosition: (pos) => _addSaleDealToCart(deal, pos),
                      onBuyNow: () => _buyNowSaleDeal(deal),
                    ),
                  );
                }),

                // 2. Individual expiring-soon on-sale items
                ...onSale.asMap().entries.map((entry) {
                  final index = entry.key;
                  final product = entry.value;
                  final firstOnSaleInStock = onSale.indexWhere((p) => !p.isOutOfStock);
                  final targetOnSaleIdx = firstOnSaleInStock != -1 ? firstOnSaleInStock : 0;
                  final shouldAttach = activeDeals.isEmpty && index == targetOnSaleIdx;
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 160,
                      child: CustomerProductCard(
                        addToCartKey: shouldAttach ? CustomerTutorialKeys.addToCartKey : null,
                        product: product,
                        onTap: () => _openProductDetails(product),
                        onAddToCart: () => _addToCart(product),
                        onAddToCartWithPosition: (pos) => _addToCart(product, pos),
                      ),
                    ),
                  );
                }),
              ],
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

  Widget _buildOnSaleSkeletons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Skeleton(height: 20, width: 140),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => const SizedBox(
                width: 160,
                child: ProductCardSkeleton(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridSkeletons() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const ProductCardSkeleton(),
          childCount: 4,
        ),
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

class _SaleDealCard extends StatelessWidget {
  final SaleDealModel deal;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;
  final Function(Offset position)? onAddToCartWithPosition;
  final Key? addToCartKey;

  const _SaleDealCard({
    required this.deal,
    required this.onTap,
    required this.onAddToCart,
    required this.onBuyNow,
    this.onAddToCartWithPosition,
    this.addToCartKey,
  });

  @override
  Widget build(BuildContext context) {
    final image = deal.effectiveImage;

    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 160,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image Container with 8px Margin Inset Frame
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image != null && image.isNotEmpty)
                        ProductImage(
                          image: image,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        )
                      else
                        Center(
                          child: Icon(
                            Icons.local_offer_rounded,
                            size: 32,
                            color: AppColors.primaryOrange.withValues(alpha: 0.4),
                          ),
                        ),
                      // Item Count Badge Top Left
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_offer, size: 9, color: Colors.white),
                              const SizedBox(width: 2),
                              Text(
                                '${deal.totalItemQuantity} Items',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Discount Badge Top Right
                      if (deal.discountPercentage > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '-${deal.discountPercentage}%',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Deal Content
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deal.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Inclusions Preview Text
                    Text(
                      deal.items.map((i) => '${i.quantity}x ${i.productName}').join(', '),
                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Pricing
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₱${deal.salePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (deal.originalTotalPrice > deal.salePrice)
                          Text(
                            '₱${deal.originalTotalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Action Buttons Row: Purchase & Cart
                    SizedBox(
                      height: 34,
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: AppColors.primaryOrange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: onBuyNow,
                              child: const Text(
                                'Purchase',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 34,
                            child: Builder(
                              builder: (btnContext) {
                                return OutlinedButton(
                                  key: addToCartKey,
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    foregroundColor: AppColors.primaryOrange,
                                    side: const BorderSide(color: AppColors.primaryOrange),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    final box = btnContext.findRenderObject() as RenderBox?;
                                    final pos = box != null
                                        ? box.localToGlobal(box.size.center(Offset.zero))
                                        : const Offset(200, 400);
                                    if (onAddToCartWithPosition != null) {
                                      onAddToCartWithPosition!(pos);
                                    } else {
                                      onAddToCart();
                                    }
                                  },
                                  child: const Icon(Icons.add_shopping_cart, size: 16),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows the modal bottom sheet preview for an On-Sale Deal bundle.
void showSaleDealDetailsModal({
  required BuildContext context,
  required SaleDealModel deal,
  required CustomerCartController cartController,
  required CustomerOrderController orderController,
  bool showActions = true,
}) {
  final employeeProducts = EmployeeInventoryController.instance.products;
  final allCustomerProducts = employeeProducts.map((ep) {
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
      capital: ep.capital,
      sellableQuantity: ep.sellableQuantity,
      image: ep.image ?? '',
      availability: availability,
      isOnSale: ep.hasExpiringSoonBatch,
    );
  }).toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalContext) => SaleDealDetailsSheet(
      deal: deal,
      showActions: showActions,
      onAddToCart: () {
        Navigator.pop(modalContext);
        final success = cartController.addSaleDeal(deal, allCustomerProducts);
        if (success) {
          TopNotification.show(context, 'Added "${deal.title}" promo to your cart!');
        } else {
          TopNotification.show(context, 'Sorry, some items in this promo are out of stock.', isError: true);
        }
      },
      onBuyNow: () {
        Navigator.pop(modalContext);
        cartController.clearCart();
        final success = cartController.addSaleDeal(deal, allCustomerProducts);
        if (success) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerCheckoutPage(
                cartController: cartController,
                orderController: orderController,
              ),
            ),
          );
        } else {
          TopNotification.show(context, 'Sorry, some items in this promo are out of stock.', isError: true);
        }
      },
    ),
  );
}

class SaleDealDetailsSheet extends StatelessWidget {
  final SaleDealModel deal;
  final VoidCallback? onAddToCart;
  final VoidCallback? onBuyNow;
  final bool showActions;

  const SaleDealDetailsSheet({
    super.key,
    required this.deal,
    this.onAddToCart,
    this.onBuyNow,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    final image = deal.effectiveImage;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Promotional Photo Preview Banner (if image exists)
              if (image != null && image.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ProductImage(
                    image: image,
                    width: double.infinity,
                    height: 140,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Deal Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_offer, color: AppColors.primaryOrange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          deal.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkText,
                          ),
                        ),
                        if (deal.discountPercentage > 0)
                          Text(
                            'Save ₱${deal.discountSavings.toStringAsFixed(2)} (${deal.discountPercentage}% OFF)',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              const Text(
                'Items Included in this Promo:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.darkText),
              ),
              const SizedBox(height: 10),

              // Items List with Product Photos!
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: deal.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = deal.items[index];
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: Row(
                        children: [
                          // Product Photo
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: ProductImage(
                                image: item.image,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Quantity Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${item.quantity}x',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Product Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkText),
                                ),
                                Text(
                                  'Reg: ₱${item.originalPrice.toStringAsFixed(2)} each',
                                  style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₱${item.totalOriginalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.darkText),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Price Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Value', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                        Text(
                          '₱${deal.originalTotalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Special Deal Price', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                        Text(
                          '₱${deal.salePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons or Close Button
              if (showActions)
                Row(
                  children: [
                    // Purchase
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 18),
                          label: Text(
                            'Purchase (₱${deal.salePrice.toStringAsFixed(2)})',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          onPressed: onBuyNow,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Add to Cart
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryOrange,
                            side: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text(
                            'Add to Cart',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: onAddToCart,
                        ),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

