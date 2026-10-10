import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/core/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Signup and Role Resolution Tests', () {
    final authService = AuthService();

    test('Arbitrary email with "owner" substring does not get owner role', () async {
      // Prior bug: emailLower.contains('owner') granted owner access to anyone with 'owner' in email
      final isOwner = await authService.hasRole('owner', 'shopowner@gmail.com');
      expect(isOwner, isFalse);

      final isCustomer = await authService.hasRole('customer', 'shopowner@gmail.com');
      expect(isCustomer, isTrue);
    });

    test('Regular customer sign-up email resolves to customer role', () async {
      final isCustomer = await authService.hasRole('customer', 'juan.delacruz@gmail.com');
      expect(isCustomer, isTrue);

      final isOwner = await authService.hasRole('owner', 'juan.delacruz@gmail.com');
      expect(isOwner, isFalse);

      final isEmployee = await authService.hasRole('employee', 'juan.delacruz@gmail.com');
      expect(isEmployee, isFalse);
    });

    test('Predefined owner demo email still resolves correctly', () async {
      final isOwnerSariSari = await authService.hasRole('owner', 'owner@sarisari.com');
      expect(isOwnerSariSari, isTrue);

      final isOwnerGmail = await authService.hasRole('owner', 'owner@gmail.com');
      expect(isOwnerGmail, isTrue);

      final isCustomer = await authService.hasRole('customer', 'owner@sarisari.com');
      expect(isCustomer, isFalse);
    });

    test('Predefined employee and admin demo emails resolve correctly', () async {
      final isEmployee = await authService.hasRole('employee', 'employee@sarisari.com');
      expect(isEmployee, isTrue);

      final isAdmin = await authService.hasRole('admin', 'admin@sarisari.com');
      expect(isAdmin, isTrue);
    });
  });
}
