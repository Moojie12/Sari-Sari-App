import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/utils/top_notification.dart';
import '../../shared/widgets/skeleton.dart';
import '../../admin/models/admin_models.dart';
import 'owner_user_controller.dart';
import 'owner_add_edit_user_page.dart';

class OwnerUsersPage extends StatefulWidget {
  const OwnerUsersPage({super.key});

  @override
  State<OwnerUsersPage> createState() => _OwnerUsersPageState();
}

class _OwnerUsersPageState extends State<OwnerUsersPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedRole = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _simulateLoading();
  }

  void _simulateLoading() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<AdminUser> get _filteredUsers {
    final controller = OwnerUserController.instance;
    final query = _searchQuery.trim().toLowerCase();
    return controller.activeUsers.where((user) {
      final matchesRole = _selectedRole == 'All' || user.role.name.toLowerCase() == _selectedRole.toLowerCase();
      final matchesSearch = query.isEmpty ||
          user.fullName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query);
      return matchesRole && matchesSearch;
    }).toList();
  }

  void _openAddUser() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OwnerAddEditUserPage(),
      ),
    ).then((created) {
      if (created == true) {
        _simulateLoading();
      }
    });
  }

  void _openEditUser(AdminUser user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OwnerAddEditUserPage(user: user),
      ),
    ).then((updated) {
      if (updated == true) {
        _simulateLoading();
      }
    });
  }

  void _showArchiveDialog(AdminUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive User?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to archive "${user.fullName}"? This user will no longer be able to login.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.secondaryText)),
          ),
          ElevatedButton(
            onPressed: () {
              OwnerUserController.instance.archiveUser(user.id);
              Navigator.pop(context);
              TopNotification.show(context, 'User archived successfully');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: OwnerUserController.instance,
      builder: (context, _) {
        final users = _filteredUsers;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              SliverToBoxAdapter(child: _buildSearchBar(context)),
              SliverToBoxAdapter(child: _buildRoleFilters(context)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Text(
                    _searchQuery.isNotEmpty ? 'Search Results' : 'System Users',
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (!_isLoading && users.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              else if (_isLoading)
                _buildGridSkeletons()
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = users[index];
                        return _OwnerUserCard(
                          user: user,
                          onEdit: () => _openEditUser(user),
                          onArchive: () => _showArchiveDialog(user),
                        );
                      },
                      childCount: users.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 50, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Users',
                style: TextStyle(color: AppColors.darkText, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Text(
                'Manage system accounts',
                style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
              ),
            ],
          ),
          IconButton(
            onPressed: _openAddUser,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: AppColors.primaryOrange, shape: BoxShape.circle),
              child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by name, email or username...',
          hintStyle: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.5), fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5)),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleFilters(BuildContext context) {
    final roles = ['All', 'Owner', 'Employee', 'Customer'];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: roles.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final role = roles[index];
          final isSelected = role == _selectedRole;
          return ChoiceChip(
            label: Text(role),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => setState(() {
              _selectedRole = role;
              _simulateLoading();
            }),
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
                color: isSelected ? AppColors.primaryOrange : AppColors.borderColor.withValues(alpha: 0.5),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 40, color: AppColors.secondaryText.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text('No users found', style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildGridSkeletons() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.75,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const ProductCardSkeleton(), // Reuse product skeleton for consistency
          childCount: 4,
        ),
      ),
    );
  }
}

class _OwnerUserCard extends StatelessWidget {
  const _OwnerUserCard({
    required this.user,
    required this.onEdit,
    required this.onArchive,
  });

  final AdminUser user;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: onEdit,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: AppColors.primaryOrange.withValues(alpha: 0.05),
                alignment: Alignment.center,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.1),
                  child: Text(
                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primaryOrange, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.darkText, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.role.label,
                    style: const TextStyle(color: AppColors.primaryOrange, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7), fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onEdit,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade200),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onArchive,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade200),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Archive', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
