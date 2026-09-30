import 'package:flutter/material.dart';

import 'package:sari_sari/core/theme/app_colors.dart';
import 'package:sari_sari/shared/utils/top_notification.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';
import 'package:sari_sari/users/customer_db/customer_cart_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_controller.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_model.dart';
import 'package:sari_sari/users/customer_db/purchases/customer_order_details_page.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_card.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_details_page.dart';
import 'package:sari_sari/users/customer_db/home/customer_product_model.dart';
import 'package:sari_sari/shared/widgets/skeleton.dart';
import '../../../models/sale_deal_model.dart';
import '../../../core/services/sale_deal_controller.dart';

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

  static const int _itemsPerPage = 12;
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

  void _addSaleDealToCart(SaleDealModel deal) {
    final success = widget.cartController.addSaleDeal(deal, _allCustomerProducts);
    if (success) {
      TopNotification.show(context, 'Added "${deal.title}" promo to your cart!');
    } else {
      TopNotification.show(context, 'Sorry, some items in this promo are out of stock.', isError: true);
    }
  }

  void _showSaleDealDetailsModal(BuildContext context, SaleDealModel deal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SaleDealDetailsSheet(
        deal: deal,
        onAddToCart: () {
          Navigator.pop(context);
          _addSaleDealToCart(deal);
        },
      ),
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
            height: 236,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                // 1. Customized On-Sale Deals created by Owner
                ...activeDeals.map((deal) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _SaleDealCard(
                      deal: deal,
                      onTap: () => _showSaleDealDetailsModal(context, deal),
                      onAddToCart: () => _addSaleDealToCart(deal),
                    ),
                  );
                }),

                // 2. Individual expiring-soon on-sale items
                ...onSale.map((product) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: SizedBox(
                      width: 160,
                      child: CustomerProductCard(
                        product: product,
                        onTap: () => _openProductDetails(product),
                        onAddToCart: () => _addToCart(product),
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

  const _SaleDealCard({
    required this.deal,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 175,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryOrange.withValues(alpha: 0.3), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Banner with Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  topRight: Radius.circular(15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_offer, size: 14, color: AppColors.primaryOrange),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${deal.totalItemQuantity} Items',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryOrange,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (deal.discountPercentage > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '-${deal.discountPercentage}%',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),

            // Deal Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deal.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Inclusions Preview Text
                    Text(
                      deal.items.map((i) => '${i.quantity}x ${i.productName}').join(', '),
                      style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // Pricing
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₱${deal.salePrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                        const SizedBox(width: 6),
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

                    // Quick Add Button
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: onAddToCart,
                        child: const Text(
                          'Add Deal',
                          style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleDealDetailsSheet extends StatelessWidget {
  final SaleDealModel deal;
  final VoidCallback onAddToCart;

  const _SaleDealDetailsSheet({
    required this.deal,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: SafeArea(
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.borderColor),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${item.quantity}x',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
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
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: AppColors.darkText),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: Text(
                  'Add Deal to Cart (₱${deal.salePrice.toStringAsFixed(2)})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: onAddToCart,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

