import 'employee_batch_model.dart';
import 'employee_product_model.dart';

final DateTime _now = DateTime.now();

/// Local inventory for the employee POS and Inventory tabs.
///
/// Frontend-only: Currently empty to reflect the lack of real data from the backend.
final List<EmployeeProduct> kEmployeeDummyProducts = [];

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
