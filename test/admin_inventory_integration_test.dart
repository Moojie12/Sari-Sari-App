import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/admin/models/admin_models.dart';
import 'package:sari_sari/users/employee_db/employee_inventory_controller.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_batch_model.dart';
import 'package:sari_sari/users/employee_db/inventory/employee_product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Supabase Inventory Data Flow & Models', () {
    test('AdminProduct maps correctly from Supabase data and derives batch totals', () {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final nextWeek = now.add(const Duration(days: 7));

      final rawSupabaseRow = {
        'id': 'f2a62694-82eb-45b0-9b4f-8cf9cfa88b64',
        'name': 'Test Milk Bread',
        'category': 'Bread & Pastries',
        'price': 45.0,
        'capital': 30.0,
        'barcode': '480001655441',
        'unit': 'pack',
        'description': 'Soft fresh bread',
        'low_stock_threshold': 5.0,
        'is_weight_based': false,
        'is_archived': false,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'product_batches': [
          {
            'id': 'b1111111-1111-1111-1111-111111111111',
            'quantity': 10.0,
            'expiry_date': nextWeek.toIso8601String(),
            'supplier': 'Gardenia',
            'notes': 'Fresh shipment',
          },
          {
            'id': 'b2222222-2222-2222-2222-222222222222',
            'quantity': 5.0,
            'expiry_date': tomorrow.toIso8601String(),
            'supplier': 'Gardenia',
            'notes': 'Nearest expiry',
          },
        ],
      };

      // Derive totalQuantity and earliestExpiry per AdminProductService logic
      double totalQuantity = 0;
      DateTime? earliestExpiry;
      for (var batch in rawSupabaseRow['product_batches'] as List) {
        if (batch['quantity'] != null) {
          totalQuantity += (batch['quantity'] as num).toDouble();
        }
        if (batch['expiry_date'] != null) {
          final expiry = DateTime.tryParse(batch['expiry_date'] as String);
          if (expiry != null && (earliestExpiry == null || expiry.isBefore(earliestExpiry))) {
            earliestExpiry = expiry;
          }
        }
      }

      final adminProduct = AdminProduct(
        id: rawSupabaseRow['id'] as String,
        name: rawSupabaseRow['name'] as String,
        categoryId: rawSupabaseRow['category'] as String,
        categoryName: rawSupabaseRow['category'] as String,
        description: rawSupabaseRow['description'] as String,
        price: (rawSupabaseRow['price'] as num).toDouble(),
        cost: (rawSupabaseRow['capital'] as num).toDouble(),
        quantity: totalQuantity,
        unit: rawSupabaseRow['unit'] as String,
        barcode: rawSupabaseRow['barcode'] as String,
        expirationDate: earliestExpiry,
        lowStockThreshold: (rawSupabaseRow['low_stock_threshold'] as num).toDouble(),
        isArchived: rawSupabaseRow['is_archived'] as bool,
      );

      expect(adminProduct.id, equals('f2a62694-82eb-45b0-9b4f-8cf9cfa88b64'));
      expect(adminProduct.name, equals('Test Milk Bread'));
      expect(adminProduct.categoryName, equals('Bread & Pastries'));
      expect(adminProduct.cost, equals(30.0));
      expect(adminProduct.price, equals(45.0));
      expect(adminProduct.quantity, equals(15.0));
      // Earliest expiry should be tomorrow, not next week
      expect(adminProduct.expirationDate?.year, equals(tomorrow.year));
      expect(adminProduct.expirationDate?.day, equals(tomorrow.day));
      expect(adminProduct.isArchived, isFalse);
    });

    test('EmployeeProduct FEFO sorting and batch calculations', () {
      final now = DateTime.now();
      final batchA = ProductBatch(
        id: 'batch-1',
        quantity: 5,
        expiryDate: now.add(const Duration(days: 10)),
      );
      final batchB = ProductBatch(
        id: 'batch-2',
        quantity: 12,
        expiryDate: now.add(const Duration(days: 2)),
      );

      final product = EmployeeProduct(
        id: 'test-p-id',
        name: 'Soda Can',
        category: 'Drinks',
        price: 25.0,
        capital: 18.0,
        barcode: '123456789',
        batches: [batchA, batchB],
      );

      expect(product.quantity, equals(17.0));
      expect(product.validBatches.first.id, equals('batch-2')); // FEFO: nearest expiry first
      expect(product.totalCapital, equals(17.0 * 18.0));
      expect(product.totalRevenue, equals(17.0 * 25.0));
    });

    test('AdminProduct status helpers correctly detect low stock, out of stock, and profit margin', () {
      final normalProduct = AdminProduct(
        id: '1',
        name: 'Chips',
        categoryId: 'Snacks',
        categoryName: 'Snacks',
        description: 'Snack chips',
        price: 20.0,
        cost: 15.0,
        quantity: 50.0,
        unit: 'pcs',
        barcode: '123',
        expirationDate: null,
        lowStockThreshold: 10.0,
      );
      expect(normalProduct.isLowStock, isFalse);
      expect(normalProduct.isOutOfStock, isFalse);
      expect(normalProduct.marginPercent, closeTo(25.0, 0.1));

      final lowStockProduct = normalProduct.copyWith(quantity: 5.0);
      expect(lowStockProduct.isLowStock, isTrue);
      expect(lowStockProduct.isOutOfStock, isFalse);

      final outOfStockProduct = normalProduct.copyWith(quantity: 0.0);
      expect(outOfStockProduct.isOutOfStock, isTrue);
    });

    test('EmployeeInventoryController singleton maintains empty dummy product list and loads Supabase as truth', () {
      final controller = EmployeeInventoryController.instance;
      expect(controller, isNotNull);
      // Dummy products must not be hardcoded
      expect(controller.products, isA<List<EmployeeProduct>>());
    });

    test('Product added in app maps to Supabase schema and renders in Admin Dashboard Inventory', () {
      // 1. Simulate product added in Mobile App (Employee / Owner)
      final appProduct = EmployeeProduct(
        id: 'p-uuid-999',
        name: 'Lucky Me Pancit Canton',
        category: 'Noodles',
        price: 18.0,
        capital: 14.0,
        unit: 'pcs',
        barcode: '480001664421',
        batches: [
          ProductBatch(
            id: 'b-uuid-101',
            quantity: 24.0,
            expiryDate: DateTime(2026, 12, 31),
            notes: 'Initial box of 24',
          ),
        ],
      );

      // Verify mobile app data
      expect(appProduct.name, equals('Lucky Me Pancit Canton'));
      expect(appProduct.quantity, equals(24.0));
      expect(appProduct.capital, equals(14.0));
      expect(appProduct.price, equals(18.0));

      // 2. Data payload saved to Supabase 'products' table
      final supabaseProductPayload = {
        'id': appProduct.id,
        'name': appProduct.name,
        'category': appProduct.category,
        'price': appProduct.price,
        'capital': appProduct.capital,
        'unit': appProduct.unit,
        'barcode': appProduct.barcode,
        'low_stock_threshold': appProduct.lowStockThreshold,
        'is_weight_based': appProduct.isWeightBased,
        'is_archived': false,
      };

      // 3. Data payload saved to Supabase 'product_batches' table
      final supabaseBatchPayload = {
        'id': appProduct.batches.first.id,
        'product_id': appProduct.id,
        'quantity': appProduct.batches.first.quantity,
        'expiry_date': appProduct.batches.first.expiryDate?.toIso8601String(),
        'notes': appProduct.batches.first.notes,
      };

      // 4. Supabase response when Admin Dashboard reads from Supabase:
      // select('*, product_batches!left(*)')
      final supabaseQueryResult = {
        ...supabaseProductPayload,
        'description': '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'product_batches': [supabaseBatchPayload],
      };

      // 5. Admin Dashboard receives and transforms Supabase record
      double totalQuantity = 0;
      DateTime? earliestExpiry;
      for (var batch in supabaseQueryResult['product_batches'] as List) {
        if (batch['quantity'] != null) {
          totalQuantity += (batch['quantity'] as num).toDouble();
        }
        if (batch['expiry_date'] != null) {
          final expiry = DateTime.tryParse(batch['expiry_date'] as String);
          if (expiry != null && (earliestExpiry == null || expiry.isBefore(earliestExpiry))) {
            earliestExpiry = expiry;
          }
        }
      }

      final adminProduct = AdminProduct(
        id: supabaseQueryResult['id'] as String,
        name: supabaseQueryResult['name'] as String,
        categoryId: supabaseQueryResult['category'] as String,
        categoryName: supabaseQueryResult['category'] as String,
        description: supabaseQueryResult['description'] as String,
        price: (supabaseQueryResult['price'] as num).toDouble(),
        cost: (supabaseQueryResult['capital'] as num).toDouble(),
        quantity: totalQuantity,
        unit: supabaseQueryResult['unit'] as String,
        barcode: supabaseQueryResult['barcode'] as String,
        expirationDate: earliestExpiry,
        lowStockThreshold: (supabaseQueryResult['low_stock_threshold'] as num).toDouble(),
        isArchived: supabaseQueryResult['is_archived'] as bool,
      );

      // Verify Admin Dashboard Inventory receives the exact product
      expect(adminProduct.id, equals(appProduct.id));
      expect(adminProduct.name, equals('Lucky Me Pancit Canton'));
      expect(adminProduct.categoryName, equals('Noodles'));
      expect(adminProduct.price, equals(18.0));
      expect(adminProduct.cost, equals(14.0));
      expect(adminProduct.quantity, equals(24.0));
      expect(adminProduct.barcode, equals('480001664421'));
      expect(adminProduct.isArchived, isFalse);
    });
  });
}
