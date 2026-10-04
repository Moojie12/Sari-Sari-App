import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/core/services/ocr_service.dart';
import 'package:sari_sari/shared/utils/gcash_ocr_helper.dart';

void main() {
  group('GcashOcrHelper GCash QR Validation Tests', () {
    test('Validates authentic GCash QR Code standee items', () {
      final items = [
        const OcrTextItem(text: 'GCash'),
        const OcrTextItem(text: 'instaPay'),
        const OcrTextItem(text: 'Transfer fees may apply.'),
        const OcrTextItem(text: 'JO*N CY**S N.'),
        const OcrTextItem(text: 'Mobile No.: +63 975 405 ....'),
        const OcrTextItem(text: 'User ID: ..........22WGAZ'),
      ];

      final result = GcashOcrHelper.validateGcashQrCode(items);
      expect(result.isValid, isTrue);
    });

    test('Rejects non-GCash image text like school logo', () {
      final items = [
        const OcrTextItem(text: 'LAGUNA UNIVERSITY 2006'),
      ];

      final result = GcashOcrHelper.validateGcashQrCode(items);
      expect(result.isValid, isFalse);
      expect(result.errorMessage, contains('Invalid Image'));
    });

    test('Rejects empty items list when items required', () {
      final result = GcashOcrHelper.validateGcashQrCode([]);
      expect(result.isValid, isFalse);
    });
  });
}
