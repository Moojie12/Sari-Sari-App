import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/shared/utils/per_barcode_debouncer.dart';

void main() {
  group('PerBarcodeDebouncer Tests', () {
    late PerBarcodeDebouncer debouncer;

    setUp(() {
      debouncer = PerBarcodeDebouncer(debounceWindow: const Duration(milliseconds: 400));
    });

    test('Accepts initial scan', () {
      expect(debouncer.shouldIgnore('480001234567'), isFalse);
    });

    test('Ignores duplicate scan of SAME barcode within 400ms', () {
      expect(debouncer.shouldIgnore('480001234567'), isFalse); // 1st scan -> accept
      expect(debouncer.shouldIgnore('480001234567'), isTrue);  // 2nd scan within 400ms -> ignore
    });

    test('Accepts DIFFERENT barcode immediately without delay', () {
      expect(debouncer.shouldIgnore('480001234567'), isFalse); // Item A -> accept
      expect(debouncer.shouldIgnore('480009999999'), isFalse); // Item B -> accept immediately!
    });

    test('Accepts same barcode after 400ms window elapses', () async {
      expect(debouncer.shouldIgnore('480001234567'), isFalse);
      await Future.delayed(const Duration(milliseconds: 450));
      expect(debouncer.shouldIgnore('480001234567'), isFalse); // Window elapsed -> accept again
    });
  });
}
