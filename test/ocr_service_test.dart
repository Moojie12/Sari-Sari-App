import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/core/services/ocr_service.dart';

void main() {
  group('MlKitOcrService Unit Tests', () {
    late MlKitOcrService ocrService;

    setUp(() {
      ocrService = MlKitOcrService();
    });

    test('cleanText removes newlines, tabs, and duplicate spaces', () {
      expect(
        ocrService.cleanText('  Lucky   Me!\n\t Pancit Canton  '),
        'Lucky Me! Pancit Canton',
      );
    });

    test('isJunkText correctly identifies junk items', () {
      // Too short
      expect(ocrService.isJunkText('A'), true);
      expect(ocrService.isJunkText('ab'), true);

      // Pure digits
      expect(ocrService.isJunkText('480001602123'), true);
      expect(ocrService.isJunkText('12345'), true);

      // Weights & Volumes
      expect(ocrService.isJunkText('250g'), true);
      expect(ocrService.isJunkText('500ml'), true);
      expect(ocrService.isJunkText('1.5L'), true);
      expect(ocrService.isJunkText('100 g'), true);
      expect(ocrService.isJunkText('1kg'), true);
      expect(ocrService.isJunkText('12 oz'), true);

      // Dates and Expiration codes
      expect(ocrService.isJunkText('EXP 12/26'), true);
      expect(ocrService.isJunkText('MFG 2025-01-01'), true);
      expect(ocrService.isJunkText('USE BY 05/2026'), true);

      // Common packaging headers
      expect(ocrService.isJunkText('NUTRITION FACTS'), true);
      expect(ocrService.isJunkText('INGREDIENTS'), true);
      expect(ocrService.isJunkText('NET WT: 80g'), true);

      // Valid Product Names
      expect(ocrService.isJunkText('Lucky Me!'), false);
      expect(ocrService.isJunkText('Pancit Canton Extra Hot'), false);
      expect(ocrService.isJunkText('Bear Brand Powdered Milk'), false);
    });

    test('filterAndSort removes junk and sorts by boundingBoxHeight descending', () {
      final items = [
        const OcrTextItem(text: '250g', boundingBoxHeight: 50.0), // junk
        const OcrTextItem(text: 'Pancit Canton', boundingBoxHeight: 30.0),
        const OcrTextItem(text: 'Lucky Me!', boundingBoxHeight: 80.0), // most prominent
        const OcrTextItem(text: 'EXP 12/2026', boundingBoxHeight: 20.0), // junk
        const OcrTextItem(text: 'Extra Hot', boundingBoxHeight: 25.0),
      ];

      final filtered = ocrService.filterAndSort(items);

      expect(filtered.length, 3);
      expect(filtered[0].text, 'Lucky Me!');
      expect(filtered[1].text, 'Pancit Canton');
      expect(filtered[2].text, 'Extra Hot');
    });

    test('mergeTexts combines selected strings into a single string', () {
      final merged = ocrService.mergeTexts(['Lucky Me!', 'Pancit Canton', 'Extra Hot']);
      expect(merged, 'Lucky Me! Pancit Canton Extra Hot');
    });
  });
}
