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

    test('AdminUser handles photoUrl and copyWith correctly', () {
      const user = AdminUser(
        id: 'u3',
        firstName: 'Maria',
        middleInitial: 'C',
        surname: 'Santos',
        email: 'maria@gmail.com',
        phone: '09123456789',
        role: AdminRole.customer,
        status: 'Enabled',
        photoUrl: 'https://example.com/avatar.jpg',
      );

      expect(user.photoUrl, 'https://example.com/avatar.jpg');

      // Update name while retaining photoUrl
      final updatedName = user.copyWith(firstName: 'Marie');
      expect(updatedName.firstName, 'Marie');
      expect(updatedName.photoUrl, 'https://example.com/avatar.jpg');

      // Update photoUrl
      final updatedPhoto = user.copyWith(photoUrl: 'https://example.com/new_avatar.jpg');
      expect(updatedPhoto.photoUrl, 'https://example.com/new_avatar.jpg');

      // Clear photoUrl
      final clearedPhoto = user.copyWith(clearPhotoUrl: true);
      expect(clearedPhoto.photoUrl, isNull);
    });
  });
}
