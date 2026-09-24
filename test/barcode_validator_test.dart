import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/shared/utils/barcode_validator.dart';

void main() {
  group('BarcodeValidator Tests', () {
    // Valid GS1 test barcodes with correct Modulo-10 check digits
    const validEan13 = '4006381333931';
    const validUpcA = '012345678905';
    const validEan8 = '96385074';

    final Map<String, String> existingBarcodes = {
      validEan13: 'prod_1',
      'SS-994820194': 'prod_2',
    };

    bool mockIsBarcodeTaken(String barcode, {String? excludingProductId}) {
      final match = existingBarcodes[barcode];
      if (match == null) return false;
      if (excludingProductId != null && match == excludingProductId) return false;
      return true;
    }

    test('Valid EAN-13, UPC-A, EAN-8, and system barcodes return null (valid)', () {
      expect(BarcodeValidator.validate(barcode: validEan13, currentProductId: 'prod_1', isBarcodeTaken: mockIsBarcodeTaken), isNull);
      expect(BarcodeValidator.validate(barcode: validUpcA, isBarcodeTaken: mockIsBarcodeTaken), isNull);
      expect(BarcodeValidator.validate(barcode: validEan8, isBarcodeTaken: mockIsBarcodeTaken), isNull);
      expect(BarcodeValidator.validate(barcode: 'SS-123456789', isBarcodeTaken: mockIsBarcodeTaken), isNull);
    });

    test('Rejects invalid Modulo-10 checksum for EAN-13 / UPC-A / EAN-8', () {
      // 13 digits with bad check digit
      final errEan13 = BarcodeValidator.validate(barcode: '4006381333932', isBarcodeTaken: mockIsBarcodeTaken);
      expect(errEan13, contains('Invalid EAN-13 barcode checksum'));

      // 12 digits with bad check digit
      final errUpcA = BarcodeValidator.validate(barcode: '012345678901', isBarcodeTaken: mockIsBarcodeTaken);
      expect(errUpcA, contains('Invalid UPC-A barcode checksum'));

      // 8 digits with bad check digit
      final errEan8 = BarcodeValidator.validate(barcode: '96385071', isBarcodeTaken: mockIsBarcodeTaken);
      expect(errEan8, contains('Invalid EAN-8 barcode checksum'));
    });

    test('Trims outer spaces gracefully while rejecting internal spaces', () {
      final validWithOuterSpaces = ' $validEan13 ';
      final result1 = BarcodeValidator.validate(
        barcode: validWithOuterSpaces,
        currentProductId: 'prod_1',
        isBarcodeTaken: mockIsBarcodeTaken,
      );
      expect(result1, isNull);

      final result2 = BarcodeValidator.validate(
        barcode: '4800 0123',
        isBarcodeTaken: mockIsBarcodeTaken,
      );
      expect(result2, equals('Barcode cannot contain spaces.'));
    });

    test('Rejects barcodes shorter than 3 characters', () {
      final err = BarcodeValidator.validate(barcode: '12', isBarcodeTaken: mockIsBarcodeTaken);
      expect(err, equals('Barcode must be at least 3 digits long.'));
    });

    test('Rejects barcodes longer than 50 characters', () {
      final longBarcode = 'A' * 51;
      final err = BarcodeValidator.validate(barcode: longBarcode, isBarcodeTaken: mockIsBarcodeTaken);
      expect(err, equals('Barcode cannot exceed 50 characters.'));
    });

    test('Rejects special symbols and emojis', () {
      final err1 = BarcodeValidator.validate(barcode: '48000#123', isBarcodeTaken: mockIsBarcodeTaken);
      expect(err1, contains('invalid characters'));

      final err2 = BarcodeValidator.validate(barcode: 'BARCODE🏷️123', isBarcodeTaken: mockIsBarcodeTaken);
      expect(err2, contains('invalid characters'));
    });

    test('Rejects duplicate barcodes assigned to other products', () {
      final err = BarcodeValidator.validate(barcode: validEan13, isBarcodeTaken: mockIsBarcodeTaken);
      expect(err, equals('This barcode is already assigned to another product.'));
    });

    test('Permits duplicate barcode when editing the SAME product', () {
      final err = BarcodeValidator.validate(
        barcode: validEan13,
        currentProductId: 'prod_1',
        isBarcodeTaken: mockIsBarcodeTaken,
      );
      expect(err, isNull);
    });
  });
}
