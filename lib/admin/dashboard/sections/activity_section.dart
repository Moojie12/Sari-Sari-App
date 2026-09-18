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
  String _logActionFilter = 'All activity';

  List<AdminAuditLog> _filteredLogs() {
    final query = widget.searchQuery.toLowerCase().trim();
    return widget.controller.allAuditLogs.where((log) {
      final matchesQuery = query.isEmpty ||
          log.entityName.toLowerCase().contains(query) ||
          log.performedBy.toLowerCase().contains(query) ||
          log.entityType.toLowerCase().contains(query);
      final matchesAction = _logActionFilter == 'All activity' ||
          log.action.label == _logActionFilter;
      return matchesQuery && matchesAction;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toolbar(
          filters: [
            dropdownFilter(
              label: 'Show',
              value: _logActionFilter,
              options: [
                'All activity',
                ...AuditAction.values.map((a) => a.label),
              ],
              onChanged: (value) => setState(() {
                _logActionFilter = value;
                widget.onPageChange('activity', 1);
              }),
            ),
          ],
          action: const SizedBox.shrink(),
        ),
        const SizedBox(height: 20),
        if (logs.isEmpty)
          emptyState(
            icon: Icons.history,
            title: 'Nothing to show',
            message: 'Every create, edit, archive and delete is recorded here. This log can\'t be edited.',
          )
        else
          _buildTable(logs),
      ],
    );
  }

  Widget _buildTable(List<AdminAuditLog> logs) {
    final paged = paginate(logs, 'activity', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 880,
      columnWidths: const {
        0: FlexColumnWidth(1.2),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(1.6),
        3: FlexColumnWidth(1.6),
      },
      header: [
        header('Action'),
        header('What changed'),
        header('By'),
        header('When'),
      ],
      rows: [
        for (final log in paged.items)
          [
            cell(statusPill(log.action.label, _actionColor(log.action))),
            cell(InkWell(
              onTap: () => widget.onShowAuditDetail(log),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${log.entityType} "${log.entityName}"',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.note ?? '${log.previousStatus} → ${log.newStatus}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.placeholderColor,
                    ),
                  ),
                ],
              ),
            )),
            cell(Text(
              log.performedBy,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
            )),
            cell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatRelative(log.timestamp),
                  style: const TextStyle(fontSize: 13, color: AppColors.darkText),
                ),
                Text(
                  formatDateTime(log.timestamp),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.placeholderColor,
                  ),
                ),
              ],
            )),
          ],
      ],
      footer: paginationBar(paged, 'activity', 'entries', widget.pages, widget.onPageChange),
    );
  }

  Color _actionColor(AuditAction action) {
    switch (action) {
      case AuditAction.create:
        return Colors.green;
      case AuditAction.update:
        return Colors.blue;
      case AuditAction.archive:
        return Colors.orange;
      case AuditAction.restore:
        return Colors.teal;
      case AuditAction.permanentDelete:
        return Colors.red;
      case AuditAction.voidSale:
        return Colors.red[900]!;
    }
  }
}
