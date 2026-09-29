import 'package:flutter/services.dart';

/// TextInputFormatter that restricts input to a maximum character length
/// (default 20) and disallows double spaces ("  ") or leading spaces.
class NoDoubleSpaceAndMax20Formatter extends TextInputFormatter {
  final int maxLength;

  NoDoubleSpaceAndMax20Formatter({this.maxLength = 20});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Disallow leading spaces
    if (newValue.text.startsWith(' ')) {
      return oldValue;
    }

    // Disallow double/consecutive spaces ("  ")
    if (newValue.text.contains('  ')) {
      return oldValue;
    }

    // Limit to maximum length
    if (newValue.text.length > maxLength) {
      return oldValue;
    }

    return newValue;
  }
}
