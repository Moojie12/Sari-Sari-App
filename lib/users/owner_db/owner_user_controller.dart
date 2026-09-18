import 'package:flutter/material.dart';
import '../../admin/models/admin_models.dart';

class OwnerUserController extends ChangeNotifier {
  OwnerUserController._() {
    _initMockData();
  }

  static final OwnerUserController instance = OwnerUserController._();
  factory OwnerUserController() => instance;

  final List<AdminUser> _users = [];

  List<AdminUser> get users => List.unmodifiable(_users);
  List<AdminUser> get activeUsers => _users.where((u) => !u.isArchived).toList();
  List<AdminUser> get archivedUsers => _users.where((u) => u.isArchived).toList();

  void _initMockData() {
    _users.addAll([
      AdminUser(
        id: 'U001',
        fullName: 'Juan Dela Cruz',
        username: 'juan_employee',
        email: 'juan@sarisari.com',
        phone: '09123456789',
        role: AdminRole.employee,
        status: 'Active',
        verificationStatus: 'Verified',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      AdminUser(
        id: 'U002',
        fullName: 'Maria Santos',
        username: 'maria_owner',
        email: 'maria@sarisari.com',
        phone: '09187654321',
        role: AdminRole.owner,
        status: 'Active',
        verificationStatus: 'Verified',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        updatedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      AdminUser(
        id: 'U003',
        fullName: 'Pedro Penduko',
        username: 'pedro_buyer',
        email: 'pedro@gmail.com',
        phone: '09223334444',
        role: AdminRole.customer,
        status: 'Active',
        verificationStatus: 'Verified',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ]);
  }

  void addUser(AdminUser user) {
    _users.add(user);
    notifyListeners();
  }

  void updateUser(AdminUser updatedUser) {
    final index = _users.indexWhere((u) => u.id == updatedUser.id);
    if (index != -1) {
      _users[index] = updatedUser;
      notifyListeners();
    }
  }

  void archiveUser(String id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      _users[index] = _users[index].copyWith(
        isArchived: true,
        archivedAt: DateTime.now(),
        archivedBy: 'Owner',
      );
      notifyListeners();
    }
  }

  void restoreUser(String id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      _users[index] = _users[index].copyWith(
        isArchived: false,
        archivedAt: null,
        archivedBy: null,
      );
      notifyListeners();
    }
  }
}
