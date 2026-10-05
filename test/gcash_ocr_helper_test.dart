import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/core/services/ocr_service.dart';
import 'package:sari_sari/shared/utils/gcash_ocr_helper.dart';

void main() {
  group('GcashOcrHelper Tests', () {
    test('Extracts 13-digit reference number from GCash receipt screenshot', () {
      final items = [
        const OcrTextItem(text: 'Amount 2,000.00'),
        const OcrTextItem(text: 'Total Amount Sent P2,000.00'),
        const OcrTextItem(text: 'Ref No. 5045 062 915234 Sep 15, 2026 10:15 AM'),
      ];

      final ref = GcashOcrHelper.extractRefNumber(items);
      expect(ref, equals('5045062915234'));
    });

    test('Extracts reference number when split across multiple OCR lines', () {
      final items = [
        const OcrTextItem(text: 'Ref No.'),
        const OcrTextItem(text: '5045 062 915234'),
      ];

      final ref = GcashOcrHelper.extractRefNumber(items);
      expect(ref, equals('5045062915234'));
    });

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

    test('Formats 13-digit reference number cleanly', () {
      final formatted = GcashOcrHelper.formatRefNumber('5045062915234');
      expect(formatted, equals('5045 062 915234'));
    });

    test('Formats 11-digit reference number cleanly', () {
      final formatted = GcashOcrHelper.formatRefNumber('10023456789');
      expect(formatted, equals('1002 345 6789'));
    });

    test('Returns user-friendly error when OCR items are empty (blurry picture)', () {
      final result = GcashOcrHelper.validateReceipt(items: [], fileSizeBytes: 1024);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('blurry'));
    });
  });
}
