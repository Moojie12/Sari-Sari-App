import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../controllers/admin_controller.dart';
import '../widgets/dashboard_shared.dart';

class PeopleSection extends StatefulWidget {
  final AdminController controller;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final void Function(String, int) onPageChange;
  final void Function(AdminUser?) onShowUserForm;
  final void Function(AdminUser) onShowUserDetail;
  final void Function(AdminUser) onArchiveUser;
  final void Function() onClearFilters;

  const PeopleSection({
    super.key,
    required this.controller,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.onPageChange,
    required this.onShowUserForm,
    required this.onShowUserDetail,
    required this.onArchiveUser,
    required this.onClearFilters,
  });

  @override
  State<PeopleSection> createState() => _PeopleSectionState();
}

class _PeopleSectionState extends State<PeopleSection> {
  String _userRoleFilter = 'All roles';
  String _userStatusFilter = 'All';
  String _userSort = 'name';
  bool _userAsc = true;

  List<AdminUser> _filteredUsers() {
    final query = widget.searchQuery.toLowerCase().trim();
    final list = widget.controller.activeUsers.where((u) {
      final matchesQuery = query.isEmpty ||
          u.fullName.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.phone.contains(query);
      final matchesRole =
          _userRoleFilter == 'All roles' || u.role.label == _userRoleFilter;
      final matchesStatus =
          _userStatusFilter == 'All' || u.status == _userStatusFilter;
      return matchesQuery && matchesRole && matchesStatus;
    }).toList();

    int compare(AdminUser a, AdminUser b) {
      // Prioritize Owner, then Employee
      if (a.role != b.role) {
        if (a.role == AdminRole.owner) return -1;
        if (b.role == AdminRole.owner) return 1;
        if (a.role == AdminRole.employee) return -1;
        if (b.role == AdminRole.employee) return 1;
      }

      switch (_userSort) {
        case 'role':
          return a.role.index.compareTo(b.role.index);
        case 'joined':
          final ad = a.createdAt ?? DateTime(1970);
          final bd = b.createdAt ?? DateTime(1970);
          return ad.compareTo(bd);
        default:
          return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
      }
    }

    list.sort((a, b) => _userAsc ? compare(a, b) : compare(b, a));
    return list;
  }

  void _onSort(String key) {
    setState(() {
      if (_userSort == key) {
        _userAsc = !_userAsc;
      } else {
        _userSort = key;
        _userAsc = true;
      }
      widget.onPageChange('users', 1);
    });
  }

  bool get _hasFilters =>
      widget.searchQuery.isNotEmpty ||
          _userRoleFilter != 'All roles' ||
          _userStatusFilter != 'All';

  @override
  Widget build(BuildContext context) {
    final users = _filteredUsers();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        toolbar(
          filters: [
            dropdownFilter(
              label: 'Role',
              value: _userRoleFilter,
              options: [
                'All roles',
                ...AdminRole.values.map((r) => r.label),
              ],
              onChanged: (value) => setState(() {
                _userRoleFilter = value;
                widget.onPageChange('users', 1);
              }),
            ),
            dropdownFilter(
              label: 'Status',
              value: _userStatusFilter,
              options: const ['All', 'Active', 'Inactive'],
              onChanged: (value) => setState(() {
                _userStatusFilter = value;
                widget.onPageChange('users', 1);
              }),
            ),
          ],
          action: primaryButton(
            icon: Icons.person_add_alt,
            label: 'Add User',
            onPressed: () => widget.onShowUserForm(null),
          ),
        ),
        const SizedBox(height: 20),
        if (users.isEmpty)
          emptyState(
            icon: Icons.person_search_outlined,
            title: _hasFilters
                ? 'No one matches those filters'
                : 'No people yet',
            message: _hasFilters
                ? 'Try a different role, status or search term.'
                : 'Add the owner, your staff and your regular customers here.',
            actionLabel: _hasFilters ? 'Clear filters' : 'Add person',
            onAction: _hasFilters
                ? () {
              setState(() {
                _userRoleFilter = 'All roles';
                _userStatusFilter = 'All';
              });
              widget.onClearFilters();
            }
                : () => widget.onShowUserForm(null),
          )
        else
          _buildTable(users),
      ],
    );
  }

  Widget _buildTable(List<AdminUser> users) {
    final paged = paginate(users, 'users', widget.rowsPerPage, widget.pages);

    return tableShell(
      minWidth: 900,
      columnWidths: const {
        0: FlexColumnWidth(2.6),
        1: FlexColumnWidth(2.6),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.4),
        4: FlexColumnWidth(1.4),
        5: FixedColumnWidth(150),
      },
      header: [
        sortableHeader('Name', 'name', _userSort, _userAsc, _onSort),
        header('Contact'),
        sortableHeader('Role', 'role', _userSort, _userAsc, _onSort),
        header('Status'),
        sortableHeader('Joined', 'joined', _userSort, _userAsc, _onSort),
        header('Actions'),
      ],
      rows: [
        for (final user in paged.items)
          [
            cell(
              InkWell(
                onTap: () => widget.onShowUserDetail(user),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: AppColors.lightPeach,
                      child: Text(
                        user.initials,
                        style: const TextStyle(
                          color: AppColors.primaryOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            '@${user.username}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.placeholderColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            cell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.darkText),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      user.phone,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.placeholderColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      user.isVerified
                          ? Icons.verified
                          : Icons.error_outline,
                      size: 13,
                      color: user.isVerified
                          ? Colors.green
                          : AppColors.placeholderColor,
                    ),
                  ],
                ),
              ],
            )),
            cell(_rolePill(user.role)),
            cell(statusPill(
              user.status,
              user.isActive ? Colors.green : AppColors.placeholderColor,
            )),
            cell(Text(
              formatDate(user.createdAt),
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.secondaryText),
            )),
            cell(
              // spaceEvenly gives the three icons even breathing room
              // instead of sitting flush against each other.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  iconAction(Icons.visibility_outlined, 'View', Colors.blueGrey,
                          () => widget.onShowUserDetail(user)),
                  iconAction(Icons.edit_outlined, 'Edit', Colors.blue,
                          () => widget.onShowUserForm(user)),
                  iconAction(Icons.archive_outlined, 'Archive', Colors.orange,
                          () => widget.onArchiveUser(user)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(paged, 'users', 'people', widget.pages, widget.onPageChange),
    );
  }

  Widget _rolePill(AdminRole role) {
    Color color;
    switch (role) {
      case AdminRole.owner:
        color = Colors.purple;
        break;
      case AdminRole.employee:
        color = Colors.blue;
        break;
      case AdminRole.customer:
        color = Colors.teal;
        break;
    }
    return statusPill(role.label, color);
  }
}