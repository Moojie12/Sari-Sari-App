import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'customer_cart_controller.dart';
import 'customer_dummy_products.dart';
import 'customer_product_card.dart';
import 'customer_product_details_page.dart';
import 'customer_product_model.dart';

/// Customer "Home" tab: product browsing.
///
/// Layout, top to bottom: header (store name + cart), welcome message,
/// search bar, scrollable category filter, "Featured Products" (hidden
/// while a search/category filter is active), and the searchable
/// "All Products" grid.
///
/// All product data currently comes from [kCustomerDummyProducts] — see
/// that file's TODO for swapping in a real data source later.
class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key, required this.cartController});

  final CustomerCartController cartController;

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  static const int _itemsPerPage = 8;
  int _currentPage = 1;

  // Dummy signed-in customer name used only for the welcome message.
  // TODO: Replace with the real signed-in customer's name.
  static const String _customerName = 'Juan';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isFiltering =>
      _searchQuery.isNotEmpty || _selectedCategory != 'All';

  List<CustomerProduct> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return kCustomerDummyProducts.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;
      final matchesSearch =
          query.isEmpty || product.name.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  List<CustomerProduct> get _featuredProducts =>
      kCustomerDummyProducts.where((product) => product.isFeatured).toList();

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
        ),
      ),
    );
  }

  void _addToCart(CustomerProduct product) {
    final added = widget.cartController.addToCart(product);
    if (!added) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(
            'Added to cart',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primaryOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProducts;
    final int totalCount = filtered.length;
    final int totalPages = (totalCount / _itemsPerPage).ceil();

    // Reset current page if it's out of bounds after filtering
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    }

    final pagedProducts = filtered
        .skip((_currentPage - 1) * _itemsPerPage)
        .take(_itemsPerPage)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        bottom: false,
        top: true,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildTitle(context)),
            SliverToBoxAdapter(child: _buildWelcomeSection(context)),
            SliverToBoxAdapter(child: _buildSearchBar(context)),
            SliverToBoxAdapter(child: _buildCategories(context)),
            if (!_isFiltering)
              SliverToBoxAdapter(child: _buildFeaturedProducts(context)),
            // ...unchanged from here down
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
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
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous Button
          _PageButton(
            icon: Icons.chevron_left,
            onPressed: _currentPage > 1
                ? () => _onPageSelected(_currentPage - 1)
                : null,
          ),
          const SizedBox(width: 8),
          // Page Numbers
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
          // Next Button
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Text(
        'What would you like to buy today?',
        style: TextStyle(
          color: AppColors.secondaryText.withValues(alpha: 0.7),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        'Home',
        style: TextStyle(
          color: AppColors.darkText,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kCustomerProductCategories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = kCustomerProductCategories[index];
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

  Widget _buildFeaturedProducts(BuildContext context) {
    final featured = _featuredProducts;
    if (featured.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Featured Products',
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: featured.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final product = featured[index];
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