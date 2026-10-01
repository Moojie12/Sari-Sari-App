import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/admin_models.dart';
import '../../services/admin_user_service.dart';
import '../widgets/dashboard_shared.dart';

class UsersSection extends StatefulWidget {
  final AdminUserService userService;
  final String searchQuery;
  final int rowsPerPage;
  final Map<String, int> pages;
  final void Function(String, int) onPageChange;
  final void Function(AdminUser?) onShowUserForm;
  final void Function(AdminUser) onShowUserDetail;
  final void Function(AdminUser) onArchiveUser;
  final void Function(AdminUser) onDeleteUser;
  final void Function() onClearFilters;

  const UsersSection({
    super.key,
    required this.userService,
    required this.searchQuery,
    required this.rowsPerPage,
    required this.pages,
    required this.onPageChange,
    required this.onShowUserForm,
    required this.onShowUserDetail,
    required this.onArchiveUser,
    required this.onDeleteUser,
    required this.onClearFilters,
  });

  @override
  State<UsersSection> createState() => _UsersSectionState();
}

class _UsersSectionState extends State<UsersSection> {
  late TextEditingController _searchController;
  late int _rowsPerPage;
  String _userRoleFilter = 'All roles';
  String _userStatusFilter = 'All';
  String _userSort = 'name';
  bool _userAsc = true;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
    _rowsPerPage = widget.rowsPerPage;
  }

  @override
  void didUpdateWidget(covariant UsersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
    if (widget.rowsPerPage != oldWidget.rowsPerPage) {
      _rowsPerPage = widget.rowsPerPage;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AdminUser> _filteredUsers() {
    // Wait for service to initialize
    if (!widget.userService.isInitialized) {
      return [];
    }

    final query = (_searchController.text.isNotEmpty ? _searchController.text : widget.searchQuery).toLowerCase().trim();
    final list = widget.userService.activeUsers.where((u) {
      final matchesQuery = query.isEmpty ||
          u.fullName.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.phone.contains(query);
      final matchesRole =
          _userRoleFilter == 'All roles' || u.role.label == _userRoleFilter;
      final matchesStatus =
          _userStatusFilter == 'All' || u.status == _userStatusFilter;
      return matchesQuery && matchesRole && matchesStatus;
    }).toList();

    int compare(AdminUser a, AdminUser b) {
      // PRIMARY PRIORITY: Role (Admin > Owner > Employee > Customer)
      final roleOrder = {AdminRole.admin: 0, AdminRole.owner: 1, AdminRole.employee: 2, AdminRole.customer: 3};
      final aRole = roleOrder[a.role] ?? 99;
      final bRole = roleOrder[b.role] ?? 99;
      if (aRole != bRole) return aRole.compareTo(bRole);

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
      _searchController.text.isNotEmpty ||
      widget.searchQuery.isNotEmpty ||
      _userRoleFilter != 'All roles' ||
      _userStatusFilter != 'All';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.userService,
      builder: (context, _) {
        if (!widget.userService.isInitialized || widget.userService.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryOrange,
            ),
          );
        }

        if (widget.userService.error != null && widget.userService.allUsers.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load users from Firebase Realtime Database',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.userService.error!,
                    style: const TextStyle(color: AppColors.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => widget.userService.refresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final users = _filteredUsers();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            toolbar(
              filters: [
                searchFilter(
                  controller: _searchController,
                  hintText: 'Search name, email, phone...',
                  onChanged: (value) => setState(() {
                    widget.onPageChange('users', 1);
                  }),
                  onClear: () => setState(() {
                    widget.onPageChange('users', 1);
                  }),
                ),
                dropdownFilter(
                  label: 'Role',
                  value: _userRoleFilter,
                  options: [
                    'All roles',
                    AdminRole.admin.label,
                    AdminRole.owner.label,
                    AdminRole.customer.label,
                    AdminRole.employee.label,
                  ],
                  onChanged: (value) => setState(() {
                    _userRoleFilter = value;
                    widget.onPageChange('users', 1);
                  }),
                ),
                dropdownFilter(
                  label: 'Status',
                  value: _userStatusFilter,
                  options: const ['All', 'Enabled', 'Disabled'],
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
                    : 'No users yet',
                message: _hasFilters
                    ? 'Try a different role, status or search term.'
                    : 'No user accounts found under /users in Firebase Realtime Database.',
                actionLabel: _hasFilters ? 'Reset Filters' : 'Add user',
                onAction: _hasFilters
                    ? () {
                      setState(() {
                        _searchController.clear();
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
      },
    );
  }

  Widget _buildTable(List<AdminUser> users) {
    final paged = paginate(users, 'users', _rowsPerPage, widget.pages);

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
                    AdminUserAvatar(
                      photoUrl: user.photoUrl,
                      initials: user.initials,
                      radius: 17,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName : 'Unnamed User',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                          fontSize: 13.5,
                        ),
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
                  user.email.isNotEmpty ? user.email : '—',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.darkText),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      user.phone.isNotEmpty ? user.phone : 'No phone',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.placeholderColor,
                      ),
                    ),
                  ],
                ),
              ],
            )),
            cell(_rolePill(user.role)),
            cell(statusPill(
              user.status,
              user.isActive ? Colors.green : Colors.red,
            )),
            cell(Text(
              formatDate(user.createdAt),
              style: const TextStyle(
                  fontSize: 12.5, color: AppColors.secondaryText),
            )),
            cell(
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  iconAction(Icons.edit_outlined, 'Edit', Colors.blue,
                          () => widget.onShowUserForm(user)),
                  iconAction(Icons.archive_outlined, 'Archive', Colors.orange,
                          () => widget.onArchiveUser(user)),
                  Transform.scale(
                    scale: 0.75,
                    child: Tooltip(
                      message: user.isActive ? 'Disable User' : 'Enable User',
                      child: Switch(
                        value: user.isActive,
                        activeColor: AppColors.primaryOrange,
                        onChanged: (bool enabled) async {
                          final err = await widget.userService.toggleUserStatus(user.id, enabled);
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            ),
          ],
      ],
      footer: paginationBar(
        paged,
        'users',
        'users',
        widget.pages,
        widget.onPageChange,
        currentRowsPerPage: _rowsPerPage,
        onRowsPerPageChange: (newRows) {
          setState(() {
            _rowsPerPage = newRows;
          });
          widget.onPageChange('users', 1);
        },
      ),
    );
  }

  Widget _rolePill(AdminRole role) {
    Color color;
    switch (role) {
      case AdminRole.admin:
        color = Colors.indigo;
        break;
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