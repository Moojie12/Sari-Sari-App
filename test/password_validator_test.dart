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

    test('random password generator complies 100% with PasswordValidator', () {
      final random = DateTime.now().microsecondsSinceEpoch;
      for (int i = 0; i < 100; i++) {
        const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        const lowercase = 'abcdefghijklmnopqrstuvwxyz';
        const numbers = '0123456789';
        const specials = '!@#\$%^&*(),.?":{}|<>_-+=/\\';
        
        final r = (random + i * 997);
        List<String> chars = [
          uppercase[r % uppercase.length],
          lowercase[(r ~/ 3) % lowercase.length],
          numbers[(r ~/ 7) % numbers.length],
          specials[(r ~/ 11) % specials.length],
        ];
        
        const allChars = uppercase + lowercase + numbers + specials;
        for (int j = 0; j < 8; j++) {
          chars.add(allChars[(r + j * 13) % allChars.length]);
        }
        chars.shuffle();
        final password = chars.join();

        expect(PasswordValidator.validate(password), isNull, reason: 'Failed for password: $password');
      }
    });
  });
}
