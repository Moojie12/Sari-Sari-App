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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: 46, width: 46, borderRadius: 12),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Skeleton(height: 18, width: 40),
                    SizedBox(width: 6),
                    Skeleton(height: 13, width: 60),
                    Spacer(),
                    Skeleton(height: 11, width: 80),
                  ],
                ),
                SizedBox(height: 6),
                Skeleton(height: 12, width: double.infinity),
                SizedBox(height: 4),
                Skeleton(height: 12, width: 200),
              ],
            ),
          ),
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
