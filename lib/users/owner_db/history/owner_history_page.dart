import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class OwnerHistoryPage extends StatefulWidget {
  const OwnerHistoryPage({super.key, this.initialTabIndex = 0});
  final int initialTabIndex;

  @override
  State<OwnerHistoryPage> createState() => _OwnerHistoryPageState();
}

class _OwnerHistoryPageState extends State<OwnerHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('History & Logs',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primaryOrange,
          unselectedLabelColor: AppColors.secondaryText,
          indicatorColor: AppColors.primaryOrange,
          tabs: const [
            Tab(text: 'Transactions'),
            Tab(text: 'Payments'),
            Tab(text: 'Employee Activity'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TransactionsList(),
          _PaymentsList(),
          _ActivityLogsList(),
        ],
      ),
    );
  }
}

class _TransactionsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: 10,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _HistoryCard(
        title: 'Order #ORD-102$index',
        subtitle: 'Cashier: Maria Santos · 3 items',
        trailingText: '₱ 450.00',
        date: 'Today, 2:45 PM',
        canVoid: true,
      ),
    );
  }
}

class _PaymentsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _HistoryCard(
        title: 'Payment from Juan Dela Cruz',
        subtitle: 'GCash · Ref: 902130',
        trailingText: '₱ 1,200.00',
        date: 'Yesterday, 5:30 PM',
      ),
    );
  }
}

class _ActivityLogsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: 15,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
              child: const Icon(Icons.person, color: AppColors.primaryOrange, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(color: AppColors.darkText, fontSize: 13),
                      children: [
                        TextSpan(text: 'Maria Santos ', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(text: '(Employee) '),
                        TextSpan(text: 'adjusted stock for ', style: TextStyle(color: AppColors.secondaryText)),
                        TextSpan(text: 'Bear Brand Milk', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Today, 10:15 AM', style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.5), fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.title,
    required this.subtitle,
    required this.trailingText,
    required this.date,
    this.canVoid = false,
  });

  final String title;
  final String subtitle;
  final String trailingText;
  final String date;
  final bool canVoid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
                  ],
                ),
              ),
              Text(trailingText, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryOrange)),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.5), fontSize: 11)),
              if (canVoid)
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Void', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
