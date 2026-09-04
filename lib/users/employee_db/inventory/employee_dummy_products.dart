import 'employee_product_model.dart';

final DateTime _now = DateTime.now();

/// Local dummy inventory for the employee POS and Inventory tabs.
///
/// TODO: Replace this with real data from a database/API once the
/// inventory backend is available. Both tabs only depend on the
/// `EmployeeProduct` model, so this swap should be a data-layer change.
final List<EmployeeProduct> kEmployeeDummyProducts = [
  EmployeeProduct(id: 'p1', name: 'Coca-Cola 1.5L', category: 'Drinks', price: 75.0, barcode: '4801981123456', quantity: 42),
  EmployeeProduct(id: 'p2', name: 'Lucky Me Pancit Canton', category: 'Noodles', price: 15.0, barcode: '4800016581239', quantity: 6, lowStockThreshold: 10),
  EmployeeProduct(id: 'p3', name: 'Argentina Corned Beef 175g', category: 'Canned Goods', price: 38.0, barcode: '4800392110017', quantity: 25, expiryDate: _now.add(const Duration(days: 5))),
  EmployeeProduct(id: 'p4', name: 'Piattos Cheese', category: 'Snacks', price: 30.0, barcode: '4800016171232', quantity: 18),
  EmployeeProduct(id: 'p5', name: 'Jasmine Rice 5kg', category: 'Rice & Grains', price: 320.0, barcode: '4800000001015', quantity: 12),
  EmployeeProduct(id: 'p6', name: 'Mangga', category: 'Fruits & Vegetables', price: 120.0, barcode: '4800000002019', quantity: 30, expiryDate: _now.add(const Duration(days: 3))),
  EmployeeProduct(id: 'p7', name: 'Nescafe 3-in-1 Twin Pack', category: 'Drinks', price: 12.0, barcode: '4800361231239', quantity: 60),
  EmployeeProduct(id: 'p8', name: 'Sky Flakes Crackers', category: 'Snacks', price: 18.0, barcode: '4800016112238', quantity: 0),
  EmployeeProduct(id: 'p9', name: 'Century Tuna Flakes in Oil', category: 'Canned Goods', price: 32.0, barcode: '4800014112233', quantity: 8, lowStockThreshold: 10),
  EmployeeProduct(id: 'p10', name: 'Datu Puti Soy Sauce 1L', category: 'Household', price: 55.0, barcode: '4800092112230', quantity: 20),
  EmployeeProduct(id: 'p11', name: 'Safeguard Soap', category: 'Personal Care', price: 25.0, barcode: '4800017112236', quantity: 0),
  EmployeeProduct(id: 'p12', name: 'Kopiko Blanca 3-in-1', category: 'Drinks', price: 11.0, barcode: '4800002112238', quantity: 50),
  EmployeeProduct(id: 'p13', name: 'Nissin Cup Noodles', category: 'Noodles', price: 20.0, barcode: '4800005112232', quantity: 33),
  EmployeeProduct(id: 'p14', name: 'Sinigang Mix 44g', category: 'Household', price: 14.0, barcode: '4800016112245', quantity: 5, lowStockThreshold: 10),
  EmployeeProduct(id: 'p15', name: 'Kalamansi', category: 'Fruits & Vegetables', price: 60.0, barcode: '4800000002026', quantity: 15, expiryDate: _now.add(const Duration(days: 2))),
];

/// Category labels shown in the horizontally scrolling filter row.
/// "All" is always first and is selected by default.
const List<String> kEmployeeProductCategories = [
  'All',
  'Snacks',
  'Drinks',
  'Noodles',
  'Canned Goods',
  'Rice & Grains',
  'Fruits & Vegetables',
  'Household',
  'Personal Care',
];