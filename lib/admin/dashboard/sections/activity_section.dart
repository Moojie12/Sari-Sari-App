import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../services/admin_audit_service.dart';
import '../widgets/dashboard_shared.dart';

class ActivitySection extends StatefulWidget {
  final AdminAuditService auditService;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final void Function(String, int) onPageChange;
  final void Function(AdminAuditLog) onShowAuditDetail;

  const ActivitySection({
    super.key,
    required this.auditService,
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
  late TextEditingController _searchController;
  int _selectedTab = 0; // 0: All, 1: Owner, 2: Employee, 3: Admin
  String? _selectedActionFilter; // null = All Actions

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant ActivitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _searchController.text.isNotEmpty ||
      widget.searchQuery.isNotEmpty ||
      _selectedTab != 0 ||
      _selectedActionFilter != null;

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedTab = 0;
      _selectedActionFilter = null;
    });
    widget.onPageChange('activity', 1);
  }

  List<AdminAuditLog> _filteredLogs() {
    final all = widget.auditService.allAuditLogs;
    final query = (_searchController.text.isNotEmpty ? _searchController.text : widget.searchQuery)
        .toLowerCase()
        .trim();

    return all.where((log) {
      // 1. Role Filter
      if (_selectedTab == 1 && log.performerRole != 'Owner') return false;
      if (_selectedTab == 2 && log.performerRole != 'Employee') return false;
      if (_selectedTab == 3 && log.performerRole != 'Admin') return false;

      // 2. Action Filter
      if (_selectedActionFilter != null && _selectedActionFilter != 'All') {
        if (log.action.label != _selectedActionFilter) return false;
      }

      // 3. Search Query Filter
      if (query.isNotEmpty) {
        final matchesEntity = log.entityName.toLowerCase().contains(query);
        final matchesType = log.entityType.toLowerCase().contains(query);
        final matchesUser = log.performedBy.toLowerCase().contains(query);
        final matchesAction = log.action.label.toLowerCase().contains(query);
        final matchesNote = log.note?.toLowerCase().contains(query) ?? false;
        if (!matchesEntity && !matchesType && !matchesUser && !matchesAction && !matchesNote) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _tabPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _actionPill(AuditAction action) {
    Color color;
    IconData icon;
    switch (action) {
      case AuditAction.create:
        color = Colors.green;
        icon = Icons.add_circle_outline;
        break;
      case AuditAction.update:
        color = Colors.blue;
        icon = Icons.edit_note;
        break;
      case AuditAction.archive:
        color = Colors.orange;
        icon = Icons.archive_outlined;
        break;
      case AuditAction.restore:
        color = Colors.teal;
        icon = Icons.settings_backup_restore;
        break;
      case AuditAction.permanentDelete:
        color = Colors.red;
        icon = Icons.delete_forever;
        break;
      case AuditAction.voidSale:
        color = Colors.red;
        icon = Icons.remove_shopping_cart;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            action.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _performerCell(AdminAuditLog log) {
    final role = log.performerRole;
    Color roleBg;
    Color roleFg;
    switch (role) {
      case 'Owner':
        roleBg = Colors.purple.shade50;
        roleFg = Colors.purple.shade700;
        break;
      case 'Employee':
        roleBg = Colors.blue.shade50;
        roleFg = Colors.blue.shade700;
        break;
      case 'Admin':
      default:
        roleBg = Colors.indigo.shade50;
        roleFg = Colors.indigo.shade700;
        break;
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            log.performedBy,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.darkText,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: roleBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: roleFg.withValues(alpha: 0.3), width: 0.8),
          ),
          child: Text(
            role,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: roleFg,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.auditService,
      builder: (context, _) {
        if (!widget.auditService.isInitialized && widget.auditService.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryOrange,
            ),
          );
        }

        final allLogs = widget.auditService.allAuditLogs;
        final ownerCount = allLogs.where((l) => l.performerRole == 'Owner').length;
        final employeeCount = allLogs.where((l) => l.performerRole == 'Employee').length;
        final adminCount = allLogs.where((l) => l.performerRole == 'Admin').length;

        final filtered = _filteredLogs();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            toolbar(
              filters: [
                searchFilter(
                  controller: _searchController,
                  hintText: 'Search entity, user, action...',
                  onChanged: (value) => setState(() {
                    widget.onPageChange('activity', 1);
                  }),
                  onClear: () => setState(() {
                    widget.onPageChange('activity', 1);
                  }),
                ),
                // Role Filter Tabs
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _tabPill(
                        label: 'All (${allLogs.length})',
                        isSelected: _selectedTab == 0,
                        onTap: () => setState(() {
                          _selectedTab = 0;
                          widget.onPageChange('activity', 1);
                        }),
                      ),
                      const SizedBox(width: 2),
                      _tabPill(
                        label: 'Owner ($ownerCount)',
                        isSelected: _selectedTab == 1,
                        onTap: () => setState(() {
                          _selectedTab = 1;
                          widget.onPageChange('activity', 1);
                        }),
                      ),
                      const SizedBox(width: 2),
                      _tabPill(
                        label: 'Employee ($employeeCount)',
                        isSelected: _selectedTab == 2,
                        onTap: () => setState(() {
                          _selectedTab = 2;
                          widget.onPageChange('activity', 1);
                        }),
                      ),
                      const SizedBox(width: 2),
                      _tabPill(
                        label: 'Admin ($adminCount)',
                        isSelected: _selectedTab == 3,
                        onTap: () => setState(() {
                          _selectedTab = 3;
                          widget.onPageChange('activity', 1);
                        }),
                      ),
                    ],
                  ),
                ),
                // Action Filter Dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedActionFilter ?? 'All',
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.darkText,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Actions')),
                        DropdownMenuItem(value: 'Created', child: Text('Created')),
                        DropdownMenuItem(value: 'Updated', child: Text('Updated')),
                        DropdownMenuItem(value: 'Archived', child: Text('Archived')),
                        DropdownMenuItem(value: 'Restored', child: Text('Restored')),
                        DropdownMenuItem(value: 'Deleted', child: Text('Deleted')),
                        DropdownMenuItem(value: 'Voided', child: Text('Voided')),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedActionFilter = (val == 'All') ? null : val;
                          widget.onPageChange('activity', 1);
                        });
                      },
                    ),
                  ),
                ),
              ],
              action: const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            if (filtered.isEmpty)
              emptyState(
                icon: Icons.history,
                title: _hasFilters ? 'No activity matches your filters' : 'No activity logs recorded yet',
                message: _hasFilters
                    ? 'Try clearing your search query or changing filter tabs.'
                    : 'System activity logs from Owner, Employee, and Admin will automatically appear here in real-time.',
                actionLabel: _hasFilters ? 'Reset Filters' : null,
                onAction: _hasFilters ? _resetFilters : null,
              )
            else
              _buildTable(filtered),
          ],
        );
      },
    );
  }

  Widget _buildTable(List<AdminAuditLog> logs) {
    final paged = paginate(logs, 'activity', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 850,
      columnWidths: const {
        0: FlexColumnWidth(1.6),
        1: FlexColumnWidth(3.0),
        2: FlexColumnWidth(2.6),
        3: FlexColumnWidth(2.0),
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
            cell(_actionPill(log.action)),
            cell(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    log.entityName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: AppColors.darkText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    log.entityType,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            cell(_performerCell(log)),
            cell(Text(
              formatDateTime(log.timestamp),
              style: const TextStyle(fontSize: 12.5, color: AppColors.secondaryText),
            )),
            cell(
              iconAction(
                Icons.info_outline,
                'Details',
                AppColors.primaryOrange,
                () => widget.onShowAuditDetail(log),
              ),
            ),
          ],
      ],
      footer: paginationBar(paged, 'activity', 'entries', widget.pages, widget.onPageChange),
    );
  }
}
