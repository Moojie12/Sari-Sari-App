import 'customer_product_model.dart';

/// Local product catalogue for the customer Home page.
///
/// Frontend-only: Currently empty to reflect the lack of real data from the backend.
const List<CustomerProduct> kCustomerDummyProducts = [];

/// Category labels shown in the horizontally scrolling filter row.
/// "All" is always first and is selected by default.
const List<String> kCustomerProductCategories = [
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
