import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../controllers/admin_controller.dart';
import '../widgets/dashboard_shared.dart';

class ActivitySection extends StatefulWidget {
  final AdminController controller;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final void Function(String, int) onPageChange;
  final void Function(AdminAuditLog) onShowAuditDetail;

  const ActivitySection({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.onPageChange,
    required this.onShowAuditDetail,
  });

  @override
  State<ActivitySection> createState() => _ActivitySectionState();
}

class _ActivitySectionState extends State<ActivitySection> {
  @override
  Widget build(BuildContext context) {
    final query = widget.searchQuery.toLowerCase().trim();
    final list = widget.controller.allAuditLogs.where((log) {
      return query.isEmpty ||
          log.entityName.toLowerCase().contains(query) ||
          log.performedBy.toLowerCase().contains(query) ||
          log.entityType.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (list.isEmpty)
          emptyState(
            icon: Icons.history,
            title: 'No activity found',
            message: 'System logs will appear here as changes are made.',
          )
        else
          _buildTable(list),
      ],
    );
  }

  Widget _buildTable(List<AdminAuditLog> logs) {
    final paged = paginate(logs, 'activity', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 800,
      columnWidths: const {
        0: FlexColumnWidth(1.5),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
        4: FixedColumnWidth(60),
      },
      header: [
        header('Action'),
        header('Subject'),
        header('Performed By'),
        header('Timestamp'),
        header(''),
      ],
      rows: [
        for (final log in paged.items)
          [
            cell(statusPill(log.action.label, _actionColor(log.action))),
            cell(Text('${log.entityType}: ${log.entityName}', style: const TextStyle(fontWeight: FontWeight.w500))),
            cell(Text(log.performedBy, style: const TextStyle(fontSize: 13))),
            cell(Text(formatDateTime(log.timestamp), style: const TextStyle(fontSize: 13, color: AppColors.secondaryText))),
            cell(iconAction(Icons.info_outline, 'Detail', AppColors.primaryOrange, () => widget.onShowAuditDetail(log))),
          ],
      ],
      footer: paginationBar(paged, 'activity', 'entries', widget.pages, widget.onPageChange),
    );
  }

  Color _actionColor(AuditAction action) {
    switch (action) {
      case AuditAction.create: return Colors.green;
      case AuditAction.update: return Colors.blue;
      case AuditAction.archive: return Colors.orange;
      case AuditAction.restore: return Colors.teal;
      case AuditAction.permanentDelete: return Colors.red;
      case AuditAction.voidSale: return Colors.red;
    }
  }
}
