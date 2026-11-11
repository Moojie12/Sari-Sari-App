import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';

class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 8,
  });

  final double? height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.borderColor.withValues(alpha: 0.5),
      highlightColor: Colors.white.withValues(alpha: 0.5),
      period: const Duration(milliseconds: 1500),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(
            child: Skeleton(
              borderRadius: 16,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(height: 13, width: 100),
                const SizedBox(height: 2),
                const Skeleton(height: 14, width: 60),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: Skeleton(height: 34)),
                    const SizedBox(width: 6),
                    const Skeleton(height: 34, width: 34),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrderCardSkeleton extends StatelessWidget {
  const OrderCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(height: 16, width: 120),
              Skeleton(height: 12, width: 60),
            ],
          ),
          Divider(height: 24),
          Skeleton(height: 14, width: 180),
          SizedBox(height: 4),
          Skeleton(height: 14, width: 140),
          Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 16, width: 100),
                  SizedBox(height: 4),
                  Skeleton(height: 12, width: 80),
                ],
              ),
              Skeleton(height: 36, width: 100, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class NotificationSkeleton extends StatelessWidget {
  const NotificationSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: 44, width: 44, borderRadius: 22),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Skeleton(height: 15, width: 120),
                    Skeleton(height: 8, width: 8, borderRadius: 4),
                  ],
                ),
                SizedBox(height: 4),
                Skeleton(height: 13, width: double.infinity),
                SizedBox(height: 4),
                Skeleton(height: 13, width: 200),
                SizedBox(height: 8),
                Skeleton(height: 11, width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Skeleton(height: 28, width: 100),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Row(
            children: [
              Skeleton(height: 60, width: 60, borderRadius: 30),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 18, width: 140),
                    SizedBox(height: 4),
                    Skeleton(height: 14, width: 80),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Skeleton(height: 16, width: 80),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: List.generate(
              6,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const Skeleton(height: 22, width: 22, borderRadius: 11),
                    const SizedBox(width: 14),
                    const Skeleton(height: 15, width: 150),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.placeholderColor.withValues(alpha: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class WeatherCardSkeleton extends StatelessWidget {
  const WeatherCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Skeleton(height: 22, width: 22, borderRadius: 11),
          SizedBox(width: 8),
          Skeleton(height: 14, width: 90),
          SizedBox(width: 6),
          Skeleton(height: 12, width: 70),
          Spacer(),
          Skeleton(height: 20, width: 75, borderRadius: 20),
        ],
      ),
    );
  }
}

class BatchCardSkeleton extends StatelessWidget {
  const BatchCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(height: 18, width: 120),
              Skeleton(height: 22, width: 80, borderRadius: 12),
            ],
          ),
          SizedBox(height: 16),
          Skeleton(height: 14, width: 150),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 12, width: 60),
                    SizedBox(height: 4),
                    Skeleton(height: 14, width: 90),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Skeleton(height: 12, width: 60),
                    SizedBox(height: 4),
                    Skeleton(height: 14, width: 90),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Skeleton(height: 36, width: 110, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class InventoryItemSkeleton extends StatelessWidget {
  const InventoryItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          Skeleton(height: 60, width: 60, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 15, width: 140),
                SizedBox(height: 6),
                Skeleton(height: 12, width: 90),
                SizedBox(height: 6),
                Skeleton(height: 14, width: 70),
              ],
            ),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Skeleton(height: 22, width: 65, borderRadius: 8),
              SizedBox(height: 8),
              Skeleton(height: 12, width: 50),
            ],
          ),
        ],
      ),
    );
  }
}

class StaffItemSkeleton extends StatelessWidget {
  const StaffItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          Skeleton(height: 40, width: 40, borderRadius: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 14, width: 120),
                SizedBox(height: 6),
                Row(
                  children: [
                    Skeleton(height: 18, width: 55, borderRadius: 6),
                    SizedBox(width: 8),
                    Skeleton(height: 12, width: 80),
                  ],
                ),
              ],
            ),
          ),
          Skeleton(height: 20, width: 20, borderRadius: 10),
        ],
      ),
    );
  }
}

class CartItemSkeleton extends StatelessWidget {
  const CartItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Skeleton(height: 70, width: 70, borderRadius: 12),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 15, width: 130),
                SizedBox(height: 6),
                Skeleton(height: 14, width: 60),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Skeleton(height: 28, width: 90, borderRadius: 8),
                    Skeleton(height: 20, width: 20, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TableRowSkeleton extends StatelessWidget {
  const TableRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: const [
          Skeleton(height: 16, width: 100),
          Spacer(),
          Skeleton(height: 16, width: 80),
          Spacer(),
          Skeleton(height: 16, width: 60),
          Spacer(),
          Skeleton(height: 24, width: 70, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Page-level skeleton for Customer Home Page
class CustomerHomeSkeleton extends StatelessWidget {
  const CustomerHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Search
          const Skeleton(height: 24, width: 140),
          const SizedBox(height: 8),
          const Skeleton(height: 14, width: 220),
          const SizedBox(height: 16),
          const Skeleton(height: 48, borderRadius: 14),
          const SizedBox(height: 16),
          // Weather widget
          const WeatherCardSkeleton(),
          const SizedBox(height: 20),
          // Category chips
          Row(
            children: const [
              Skeleton(height: 36, width: 70, borderRadius: 20),
              SizedBox(width: 8),
              Skeleton(height: 36, width: 85, borderRadius: 20),
              SizedBox(width: 8),
              Skeleton(height: 36, width: 90, borderRadius: 20),
              SizedBox(width: 8),
              Skeleton(height: 36, width: 60, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 24),
          // Section title
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Skeleton(height: 18, width: 120),
              Skeleton(height: 14, width: 60),
            ],
          ),
          const SizedBox(height: 14),
          // Product Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => const ProductCardSkeleton(),
          ),
        ],
      ),
    );
  }
}

/// Page-level skeleton for Notifications Page
class NotificationsPageSkeleton extends StatelessWidget {
  const NotificationsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 26, width: 160),
          const SizedBox(height: 16),
          for (int i = 0; i < 5; i++) ...[
            const NotificationSkeleton(),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Page-level skeleton for Customer Purchases/Orders Page
class CustomerPurchasesSkeleton extends StatelessWidget {
  const CustomerPurchasesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 26, width: 150),
          const SizedBox(height: 16),
          // Tab pills
          Row(
            children: const [
              Expanded(child: Skeleton(height: 38, borderRadius: 10)),
              SizedBox(width: 8),
              Expanded(child: Skeleton(height: 38, borderRadius: 10)),
              SizedBox(width: 8),
              Expanded(child: Skeleton(height: 38, borderRadius: 10)),
            ],
          ),
          const SizedBox(height: 18),
          for (int i = 0; i < 3; i++) ...[
            const OrderCardSkeleton(),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

/// Page-level skeleton for Profile Page
class ProfilePageSkeleton extends StatelessWidget {
  const ProfilePageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: ProfileSkeleton(),
    );
  }
}

/// Page-level skeleton for Employee Home Page
class EmployeeHomeSkeleton extends StatelessWidget {
  const EmployeeHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cashier Shift banner
          const Skeleton(height: 90, borderRadius: 16),
          const SizedBox(height: 16),
          // Stat cards
          Row(
            children: const [
              Expanded(child: Skeleton(height: 80, borderRadius: 14)),
              SizedBox(width: 12),
              Expanded(child: Skeleton(height: 80, borderRadius: 14)),
            ],
          ),
          const SizedBox(height: 20),
          const Skeleton(height: 20, width: 140),
          const SizedBox(height: 12),
          for (int i = 0; i < 3; i++) ...[
            const InventoryItemSkeleton(),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Page-level skeleton for Owner Home Page
class OwnerHomeSkeleton extends StatelessWidget {
  const OwnerHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 24, width: 180),
          const SizedBox(height: 8),
          const Skeleton(height: 14, width: 130),
          const SizedBox(height: 18),
          // Top 2 Analytics Cards
          Row(
            children: const [
              Expanded(child: Skeleton(height: 90, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: Skeleton(height: 90, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 12),
          // Bottom Analytics Card
          const Skeleton(height: 90, borderRadius: 16),
          const SizedBox(height: 18),
          const WeatherCardSkeleton(),
          const SizedBox(height: 20),
          const Skeleton(height: 20, width: 140),
          const SizedBox(height: 12),
          for (int i = 0; i < 2; i++) ...[
            const OrderCardSkeleton(),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// Page-level skeleton for POS Page
class PosSkeleton extends StatelessWidget {
  const PosSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & scan bar
          Row(
            children: const [
              Expanded(child: Skeleton(height: 46, borderRadius: 12)),
              SizedBox(width: 8),
              Skeleton(height: 46, width: 46, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 12),
          // Category pills
          Row(
            children: const [
              Skeleton(height: 32, width: 60, borderRadius: 16),
              SizedBox(width: 6),
              Skeleton(height: 32, width: 80, borderRadius: 16),
              SizedBox(width: 6),
              Skeleton(height: 32, width: 80, borderRadius: 16),
              SizedBox(width: 6),
              Skeleton(height: 32, width: 60, borderRadius: 16),
            ],
          ),
          const SizedBox(height: 16),
          // POS Products Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: 4,
            itemBuilder: (_, __) => const ProductCardSkeleton(),
          ),
        ],
      ),
    );
  }
}

/// Page-level skeleton for Inventory Page
class InventorySkeletonPage extends StatelessWidget {
  const InventorySkeletonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          const Skeleton(height: 46, borderRadius: 12),
          const SizedBox(height: 12),
          // Filter pills
          Row(
            children: const [
              Skeleton(height: 32, width: 70, borderRadius: 16),
              SizedBox(width: 8),
              Skeleton(height: 32, width: 90, borderRadius: 16),
              SizedBox(width: 8),
              Skeleton(height: 32, width: 80, borderRadius: 16),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < 5; i++) ...[
            const InventoryItemSkeleton(),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

