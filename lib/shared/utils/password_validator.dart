class PasswordValidator {
  PasswordValidator._();

  /// Validates a password against complexity requirements:
  /// - Minimum length: 8 characters
  /// - At least 1 uppercase letter
  /// - At least 1 lowercase letter
  /// - At least 1 number
  /// - At least 1 special character
  static String? validate(String? value, {String fieldName = 'Password'}) {
    if (value == null || value.isEmpty) {
      return 'Please enter your $fieldName.';
    }
    if (value.length < 8) {
      return '$fieldName must be at least 8 characters long.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return '$fieldName must contain at least 1 uppercase letter.';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return '$fieldName must contain at least 1 lowercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return '$fieldName must contain at least 1 number.';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\]').hasMatch(value)) {
      return '$fieldName must contain at least 1 special character.';
    }
    return null;
  }

  /// Validates that the confirm password matches the new password.
  static String? validateConfirmPassword(String? confirmPassword, String newPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password.';
    }
    if (confirmPassword != newPassword) {
      return 'Passwords do not match.';
    }
    return null;
  }
}
