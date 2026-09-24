import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/shared/utils/barcode_generator.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';

void main() {
  group('BarcodeGenerator Tests', () {
    late EmployeeInventoryController inventory;

    setUp(() {
      inventory = EmployeeInventoryController.instance;
      inventory.setProductsForTesting([]);
    });

    test('Generates unique barcode with SS- prefix', () {
      final code1 = BarcodeGenerator.generateUniqueBarcode(inventoryController: inventory);
      final code2 = BarcodeGenerator.generateUniqueBarcode(inventoryController: inventory);

      expect(code1, startsWith('SS-'));
      expect(code2, startsWith('SS-'));
      expect(code1, isNot(equals(code2)));
    });

    test('Avoids barcode collisions when adding products to inventory', () {
      final code = BarcodeGenerator.generateUniqueBarcode(inventoryController: inventory);

      inventory.createProduct(
        name: 'Test Product',
        category: 'Snacks',
        price: 10.0,
        capital: 8.0,
        barcode: code,
      );

      final newCode = BarcodeGenerator.generateUniqueBarcode(inventoryController: inventory);
      expect(newCode, isNot(equals(code)));
      expect(inventory.isBarcodeTaken(code), isTrue);
      expect(inventory.isBarcodeTaken(newCode), isFalse);
    });
  });
}
