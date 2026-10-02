import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pagination & Boundary Tests', () {
    final mockDataset = List<int>.generate(105, (i) => i + 1); // 105 mock items

    test('Customer Grid 20-item page boundary calculation', () {
      const itemsPerPage = 20;
      final totalPages = (mockDataset.length / itemsPerPage).ceil();
      expect(totalPages, equals(6)); // 105 / 20 = 6 pages

      final page1 = mockDataset.skip(0).take(itemsPerPage).toList();
      expect(page1.length, equals(20));
      expect(page1.first, equals(1));
      expect(page1.last, equals(20));

      final page6 = mockDataset.skip(5 * itemsPerPage).take(itemsPerPage).toList();
      expect(page6.length, equals(5)); // Remaining 5 items
      expect(page6.last, equals(105));
    });

    test('Admin Table 10-row page boundary calculation', () {
      const rowsPerPage = 10;
      final totalPages = (mockDataset.length / rowsPerPage).ceil();
      expect(totalPages, equals(11)); // 105 / 10 = 11 pages

      final page1 = mockDataset.skip(0).take(rowsPerPage).toList();
      expect(page1.length, equals(10));

      final page11 = mockDataset.skip(10 * rowsPerPage).take(rowsPerPage).toList();
      expect(page11.length, equals(5));
    });
  });
}
