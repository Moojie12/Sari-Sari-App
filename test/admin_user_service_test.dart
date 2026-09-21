import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/admin/models/admin_models.dart';

void main() {
  group('AdminUser model and parsing tests', () {
    test('AdminUser handles displayName fallback and initials properly', () {
      const userWithoutNames = AdminUser(
        id: 'user1',
        firstName: '',
        middleInitial: '',
        surname: '',
        email: 'admin@eca.com',
        phone: '09123456789',
        role: AdminRole.admin,
        status: 'Enabled',
      );

      expect(userWithoutNames.fullName, 'admin');
      expect(userWithoutNames.initials, 'A');

      const userWithNames = AdminUser(
        id: 'user2',
        firstName: 'Juan',
        middleInitial: 'D',
        surname: 'Cruz',
        email: 'juan@gmail.com',
        phone: '09123456789',
        role: AdminRole.customer,
        status: 'Enabled',
      );

      expect(userWithNames.fullName, 'Juan D. Cruz');
      expect(userWithNames.initials, 'JC');
    });

    test('AdminUser archive flags work correctly', () {
      const activeUser = AdminUser(
        id: 'u1',
        firstName: 'Active',
        middleInitial: '',
        surname: 'User',
        email: 'active@eca.com',
        phone: '',
        role: AdminRole.employee,
        status: 'Enabled',
        isArchived: false,
      );

      const archivedUser = AdminUser(
        id: 'u2',
        firstName: 'Archived',
        middleInitial: '',
        surname: 'User',
        email: 'archived@eca.com',
        phone: '',
        role: AdminRole.customer,
        status: 'Disabled',
        isArchived: true,
      );

      expect(activeUser.isArchived, isFalse);
      expect(archivedUser.isArchived, isTrue);
    });
  });
}
