import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/users/employee_db/profile/employee_profile_model.dart';
import 'package:sari_sari/users/customer_db/profile/customer_profile_model.dart';
import 'package:sari_sari/users/owner_db/profile/owner_profile_controller.dart';
import 'package:sari_sari/users/employee_db/profile/employee_profile_controller.dart';
import 'package:sari_sari/users/customer_db/profile/customer_profile_controller.dart';

void main() {
  group('Profile User ID Isolation Tests', () {
    test('EmployeeProfile holds distinct userId and preserves it on copyWith', () {
      const employee = EmployeeProfile(
        userId: 'emp_uid_123',
        firstName: 'Juan',
        middleInitial: 'D',
        lastName: 'Dela Cruz',
        email: 'juan.employee@eca.com',
        contactNumber: '09123456789',
        role: 'Cashier',
        photoPath: '/path/to/employee_photo.jpg',
      );

      expect(employee.userId, 'emp_uid_123');
      expect(employee.fullName, 'Juan D. Dela Cruz');
      expect(employee.photoPath, '/path/to/employee_photo.jpg');

      final updatedEmployee = employee.copyWith(
        firstName: 'Johnny',
        photoPath: '/path/to/new_employee_photo.jpg',
      );

      expect(updatedEmployee.userId, 'emp_uid_123');
      expect(updatedEmployee.firstName, 'Johnny');
      expect(updatedEmployee.photoPath, '/path/to/new_employee_photo.jpg');
    });

    test('CustomerProfile holds distinct userId and preserves it on copyWith', () {
      const customer = CustomerProfile(
        userId: 'cust_uid_456',
        firstName: 'Maria',
        middleInitial: 'S',
        lastName: 'Santos',
        email: 'maria.customer@gmail.com',
        contactNumber: '09987654321',
        photoPath: '/path/to/customer_photo.jpg',
      );

      expect(customer.userId, 'cust_uid_456');
      expect(customer.fullName, 'Maria S. Santos');
      expect(customer.photoPath, '/path/to/customer_photo.jpg');

      final updatedCustomer = customer.copyWith(
        contactNumber: '09111111111',
      );

      expect(updatedCustomer.userId, 'cust_uid_456');
      expect(updatedCustomer.contactNumber, '09111111111');
      expect(updatedCustomer.photoPath, '/path/to/customer_photo.jpg');
    });

    test('Owner and Employee profile controllers are distinct and have independent state', () {
      final ownerCtrl = OwnerProfileController.instance;
      final empCtrl = EmployeeProfileController.instance;
      final custCtrl = CustomerProfileController.instance;

      expect(identical(ownerCtrl, empCtrl), isFalse);
      expect(identical(ownerCtrl, custCtrl), isFalse);
      expect(identical(empCtrl, custCtrl), isFalse);

      ownerCtrl.clear();
      empCtrl.clear();
      custCtrl.clear();

      expect(ownerCtrl.currentUserId, '');
      expect(empCtrl.currentUserId, '');
      expect(custCtrl.currentUserId, '');
      expect(ownerCtrl.profile.role, 'Owner');
    });

    test('Employee and Owner can hold different user IDs and photos without collision', () {
      const ownerProfile = EmployeeProfile(
        userId: 'owner_uid_999',
        firstName: 'Boss',
        middleInitial: 'A',
        lastName: 'StoreOwner',
        email: 'owner@eca.com',
        contactNumber: '09180000000',
        role: 'Owner',
        photoPath: 'https://storage.googleapis.com/bucket/owner.jpg',
      );

      const employeeProfile = EmployeeProfile(
        userId: 'emp_uid_111',
        firstName: 'Staff',
        middleInitial: 'B',
        lastName: 'Worker',
        email: 'staff@eca.com',
        contactNumber: '09190000000',
        role: 'Staff',
        photoPath: 'https://storage.googleapis.com/bucket/staff.jpg',
      );

      expect(ownerProfile.userId, isNot(equals(employeeProfile.userId)));
      expect(ownerProfile.photoPath, isNot(equals(employeeProfile.photoPath)));
      expect(ownerProfile.role, 'Owner');
      expect(employeeProfile.role, 'Staff');
    });
  });
}
