import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/skeleton.dart';

class OwnerActivityLogsPage extends StatefulWidget {
  const OwnerActivityLogsPage({super.key});

  @override
  State<OwnerActivityLogsPage> createState() => _OwnerActivityLogsPageState();
}

class _OwnerActivityLogsPageState extends State<OwnerActivityLogsPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _simulateLoading();
  }

  void _simulateLoading() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.lightBackground,
        elevation: 0,
        foregroundColor: AppColors.darkText,
        title: const Text('Activity Logs', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading 
        ? _buildSkeletons()
        : _buildLogsList(),
    );
  }

  Widget _buildSkeletons() {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: 8,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => Container(
        height: 80,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        child: const Row(
          children: [
            Skeleton(height: 48, width: 48, borderRadius: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Skeleton(height: 14, width: 200),
                  SizedBox(height: 6),
                  Skeleton(height: 10, width: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList() {
    final logs = [
      _ActivityLog(
        actor: 'Maria Santos',
        actorRole: 'Employee',
        action: 'adjusted stock for',
        target: 'Sinandomeng Rice',
        time: 'Today, 10:15 AM',
        icon: Icons.inventory_2_outlined,
      ),
      _ActivityLog(
        actor: 'Juan Dela Cruz',
        actorRole: 'Employee',
        action: 'completed walk-in sale #RC-10020',
        target: '',
        time: 'Today, 9:45 AM',
        icon: Icons.point_of_sale_outlined,
      ),
      _ActivityLog(
        actor: 'System',
        actorRole: '',
        action: 'automatically archived expired batch for',
        target: 'Bear Brand Milk',
        time: 'Today, 12:00 AM',
        icon: Icons.auto_mode,
      ),
      _ActivityLog(
        actor: 'Maria Santos',
        actorRole: 'Employee',
        action: 'received new delivery of',
        target: 'Coca-Cola 1.5L',
        time: 'Yesterday, 4:30 PM',
        icon: Icons.local_shipping_outlined,
      ),
      _ActivityLog(
        actor: 'Owner',
        actorRole: '',
        action: 'updated shop delivery fee configuration',
        target: '',
        time: 'Sep 15, 2026, 2:15 PM',
        icon: Icons.settings_outlined,
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: logs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final log = logs[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(log.icon, color: AppColors.primaryOrange, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: AppColors.darkText, fontSize: 13, height: 1.4),
                        children: [
                          TextSpan(text: log.actor, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (log.actorRole.isNotEmpty)
                            TextSpan(text: ' (${log.actorRole}) ', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText)),
                          TextSpan(text: ' ${log.action} ', style: const TextStyle(color: AppColors.secondaryText)),
                          if (log.target.isNotEmpty)
                            TextSpan(text: log.target, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(log.time, style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.5), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityLog {
  final String actor;
  final String actorRole;
  final String action;
  final String target;
  final String time;
  final IconData icon;

  _ActivityLog({
    required this.actor,
    required this.actorRole,
    required this.action,
    required this.target,
    required this.time,
    required this.icon,
  });
}
