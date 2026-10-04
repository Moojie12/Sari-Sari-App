import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/core/services/ocr_service.dart';
import 'package:sari_sari/shared/utils/gcash_ocr_helper.dart';

void main() {
  group('GcashOcrHelper Tests', () {
    test('Extracts reference number with Ref No prefix', () {
      final items = [
        const OcrTextItem(text: 'GCash Express Send'),
        const OcrTextItem(text: 'Ref No. 1002 345 6789'),
        const OcrTextItem(text: 'Amount: P500.00'),
      ];

      final ref = GcashOcrHelper.extractRefNumber(items);
      expect(ref, equals('10023456789'));
    });

    test('Extracts reference number with Reference No prefix', () {
      final items = [
        const OcrTextItem(text: 'Reference No: 1234567890123'),
      ];

      final ref = GcashOcrHelper.extractRefNumber(items);
      expect(ref, equals('1234567890123'));
    });

    test('Formats reference number cleanly', () {
      final formatted = GcashOcrHelper.formatRefNumber('10023456789');
      expect(formatted, equals('1002 345 6789'));
    });
  });
}
