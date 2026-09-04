import 'customer_product_model.dart';

/// Local dummy product catalogue for the customer Home page.
///
/// TODO: Replace this with real data from a database/API. The Home page
/// only depends on the `CustomerProduct` model (not on this list being a
/// static `const`), so that swap should be a data-layer change only.
const List<CustomerProduct> kCustomerDummyProducts = [
  CustomerProduct(
    id: 'p1',
    name: 'Coca-Cola 1.5L',
    category: 'Drinks',
    price: 75.0,
    image: 'assets/products/coke_1_5l.png',
    availability: CustomerProductAvailability.inStock,
    isFeatured: true,
  ),
  CustomerProduct(
    id: 'p2',
    name: 'Lucky Me Pancit Canton',
    category: 'Noodles',
    price: 15.0,
    image: 'assets/products/lucky_me_pancit_canton.png',
    availability: CustomerProductAvailability.lowStock,
    isFeatured: true,
  ),
  CustomerProduct(
    id: 'p3',
    name: 'Argentina Corned Beef 175g',
    category: 'Canned Goods',
    price: 38.0,
    image: 'assets/products/argentina_corned_beef.png',
    availability: CustomerProductAvailability.inStock,
    isFeatured: true,
  ),
  CustomerProduct(
    id: 'p4',
    name: 'Piattos Cheese',
    category: 'Snacks',
    price: 30.0,
    image: 'assets/products/piattos_cheese.png',
    availability: CustomerProductAvailability.inStock,
    isFeatured: true,
  ),
  CustomerProduct(
    id: 'p5',
    name: 'Jasmine Rice 5kg',
    category: 'Rice & Grains',
    price: 320.0,
    image: 'assets/products/jasmine_rice_5kg.png',
    availability: CustomerProductAvailability.inStock,
    isFeatured: true,
  ),
  CustomerProduct(
    id: 'p6',
    name: 'Mangga',
    category: 'Fruits & Vegetables',
    price: 120.0,
    image: 'assets/products/mangga.png',
    availability: CustomerProductAvailability.inStock,
    isFeatured: true,
  ),
  CustomerProduct(
    id: 'p7',
    name: 'Nescafe 3-in-1 Twin Pack',
    category: 'Drinks',
    price: 12.0,
    image: 'assets/products/nescafe_3in1.png',
    availability: CustomerProductAvailability.inStock,
  ),
  CustomerProduct(
    id: 'p8',
    name: 'Sky Flakes Crackers',
    category: 'Snacks',
    price: 18.0,
    image: 'assets/products/sky_flakes.png',
    availability: CustomerProductAvailability.inStock,
  ),
  CustomerProduct(
    id: 'p9',
    name: 'Century Tuna Flakes in Oil',
    category: 'Canned Goods',
    price: 32.0,
    image: 'assets/products/century_tuna.png',
    availability: CustomerProductAvailability.lowStock,
  ),
  CustomerProduct(
    id: 'p10',
    name: 'Datu Puti Soy Sauce 1L',
    category: 'Household',
    price: 55.0,
    image: 'assets/products/datu_puti_soy_sauce.png',
    availability: CustomerProductAvailability.inStock,
  ),
  CustomerProduct(
    id: 'p11',
    name: 'Safeguard Soap',
    category: 'Personal Care',
    price: 25.0,
    image: 'assets/products/safeguard_soap.png',
    availability: CustomerProductAvailability.outOfStock,
  ),
  CustomerProduct(
    id: 'p12',
    name: 'Kopiko Blanca 3-in-1',
    category: 'Drinks',
    price: 11.0,
    image: 'assets/products/kopiko_blanca.png',
    availability: CustomerProductAvailability.inStock,
  ),
  CustomerProduct(
    id: 'p13',
    name: 'Nissin Cup Noodles',
    category: 'Noodles',
    price: 20.0,
    image: 'assets/products/cup_noodles.png',
    availability: CustomerProductAvailability.inStock,
  ),
  CustomerProduct(
    id: 'p14',
    name: 'Sinigang Mix 44g',
    category: 'Household',
    price: 14.0,
    image: 'assets/products/sinigang_mix.png',
    availability: CustomerProductAvailability.inStock,
  ),
  CustomerProduct(
    id: 'p15',
    name: 'Kalamansi',
    category: 'Fruits & Vegetables',
    price: 60.0,
    image: 'assets/products/kalamansi.png',
    availability: CustomerProductAvailability.lowStock,
  ),
];

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