import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/shared/utils/password_validator.dart';

void main() {
  group('PasswordValidator Tests', () {
    test('returns error when password is empty', () {
      expect(PasswordValidator.validate(''), equals('Please enter your Password.'));
      expect(PasswordValidator.validate(null), equals('Please enter your Password.'));
    });

    test('returns error when password is less than 8 characters', () {
      expect(PasswordValidator.validate('Abc1!'), equals('Password must be at least 8 characters long.'));
    });

    test('returns error when password lacks uppercase letter', () {
      expect(PasswordValidator.validate('password123!'), equals('Password must contain at least 1 uppercase letter.'));
    });

    test('returns error when password lacks lowercase letter', () {
      expect(PasswordValidator.validate('PASSWORD123!'), equals('Password must contain at least 1 lowercase letter.'));
    });

    test('returns error when password lacks number', () {
      expect(PasswordValidator.validate('Password!@#'), equals('Password must contain at least 1 number.'));
    });

    test('returns error when password lacks special character', () {
      expect(PasswordValidator.validate('Password123'), equals('Password must contain at least 1 special character.'));
    });

    test('returns null when password meets all requirements', () {
      expect(PasswordValidator.validate('Pass1234!'), isNull);
      expect(PasswordValidator.validate('ComplexP@ssw0rd'), isNull);
    });

    test('confirm password validation', () {
      expect(PasswordValidator.validateConfirmPassword('', 'Pass1234!'), equals('Please confirm your password.'));
      expect(PasswordValidator.validateConfirmPassword('Pass1234', 'Pass1234!'), equals('Passwords do not match.'));
      expect(PasswordValidator.validateConfirmPassword('Pass1234!', 'Pass1234!'), isNull);
    });
  });
}
