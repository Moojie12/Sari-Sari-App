/// Utility class providing validation rules for scanned, custom, and auto-generated barcodes.
/// Implements GS1 Modulo-10 Check Digit verification for EAN-13, EAN-8, and UPC-A standards.
class BarcodeValidator {
  BarcodeValidator._();

  /// Validates GS1 EAN-13 Modulo-10 check digit checksum.
  static bool isValidEan13(String code) {
    if (code.length != 13 || !RegExp(r'^\d{13}$').hasMatch(code)) return false;
    int sum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(code[i]);
      sum += (i % 2 == 0) ? digit * 1 : digit * 3;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(code[12]);
  }

  /// Validates GS1 UPC-A Modulo-10 check digit checksum (12 digits converted to EAN-13 format).
  static bool isValidUpcA(String code) {
    if (code.length != 12 || !RegExp(r'^\d{12}$').hasMatch(code)) return false;
    return isValidEan13('0$code');
  }

  /// Validates GS1 EAN-8 Modulo-10 check digit checksum.
  static bool isValidEan8(String code) {
    if (code.length != 8 || !RegExp(r'^\d{8}$').hasMatch(code)) return false;
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      final digit = int.parse(code[i]);
      sum += (i % 2 == 0) ? digit * 3 : digit * 1;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return checkDigit == int.parse(code[7]);
  }

  /// Validates a barcode string for a product:
  /// - Exact EAN-13 (13 digits), UPC-A (12 digits), or EAN-8 (8 digits) checksum verification.
  /// - Loose custom bounds (3 to 50 characters) for internal SKUs or custom system barcodes.
  /// - Duplicate protection against existing inventory products.
  static String? validate({
    required String barcode,
    bool isRequired = false,
    String? currentProductId,
    required bool Function(String barcode, {String? excludingProductId}) isBarcodeTaken,
  }) {
    final trimmed = barcode.trim();

    if (isRequired && trimmed.isEmpty) {
      return 'Barcode is required.';
    }

    if (trimmed.isEmpty) {
      return null; // Blank optional barcodes get auto-generated automatically
    }

    if (trimmed.contains(' ')) {
      return 'Barcode cannot contain spaces.';
    }

    // Check if code is purely numeric
    final isPureNumeric = RegExp(r'^\d+$').hasMatch(trimmed);

    if (isPureNumeric) {
      if (trimmed.length == 13) {
        if (!isValidEan13(trimmed)) {
          return 'Invalid EAN-13 barcode checksum. Please check for misread or typo.';
        }
      } else if (trimmed.length == 12) {
        if (!isValidUpcA(trimmed)) {
          return 'Invalid UPC-A barcode checksum. Please check for misread or typo.';
        }
      } else if (trimmed.length == 8) {
        if (!isValidEan8(trimmed)) {
          return 'Invalid EAN-8 barcode checksum. Please check for misread or typo.';
        }
      } else if (trimmed.length < 3) {
        return 'Barcode must be at least 3 digits long.';
      } else if (trimmed.length > 50) {
        return 'Barcode cannot exceed 50 digits.';
      }
    } else {
      // Non-pure-numeric custom SKU bounds (e.g. SS-84920194)
      if (trimmed.length < 3) {
        return 'Barcode must be at least 3 characters long.';
      }

      if (trimmed.length > 50) {
        return 'Barcode cannot exceed 50 characters.';
      }

      if (!RegExp(r'^[a-zA-Z0-9\-_.]+$').hasMatch(trimmed)) {
        return 'Barcode contains invalid characters. Only letters, numbers, hyphens (-), and underscores (_) are allowed.';
      }
    }

    if (isBarcodeTaken(trimmed, excludingProductId: currentProductId)) {
      return 'This barcode is already assigned to another product.';
    }

    return null;
  }
}
