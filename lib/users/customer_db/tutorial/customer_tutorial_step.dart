import 'package:flutter/material.dart';
import 'package:sari_sari/users/customer_db/tutorial/customer_tutorial_keys.dart';

/// Represents a single feature step in the customer onboarding tutorial.
class CustomerTutorialStep {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final GlobalKey? targetKey;
  final bool isCircle;
  final double borderRadius;
  final EdgeInsets padding;

  const CustomerTutorialStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.targetKey,
    this.isCircle = false,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(8.0),
  });

  /// The standard sequence of steps guiding the customer through the app features.
  static List<CustomerTutorialStep> get defaultSteps => [
    CustomerTutorialStep(
      id: 'home',
      title: 'Home',
      description:
          'Welcome to Sari-Sari! Discover fresh grocery arrivals, exclusive daily deals, and featured categories right from your home feed.',
      icon: Icons.storefront_rounded,
      targetKey: CustomerTutorialKeys.homeTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    CustomerTutorialStep(
      id: 'search',
      title: 'Products / Search',
      description:
          'Find what you need in seconds. Search by product name or tap category chips to filter snacks, drinks, pantry essentials, and more.',
      icon: Icons.search_rounded,
      targetKey: CustomerTutorialKeys.searchBarKey,
      isCircle: false,
      borderRadius: 14.0,
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
    ),
    CustomerTutorialStep(
      id: 'add_to_cart',
      title: 'Add to Cart',
      description:
          'Easily add items to your basket with a single tap on the cart icon, or open the product card to review stock and details.',
      icon: Icons.add_shopping_cart_rounded,
      targetKey: CustomerTutorialKeys.addToCartKey,
      isCircle: true,
      padding: const EdgeInsets.all(8.0),
    ),
    CustomerTutorialStep(
      id: 'cart',
      title: 'Cart',
      description:
          'Tap this shopping cart button at the top anytime to view your selected items, adjust quantities, and see your live order total.',
      icon: Icons.shopping_cart_outlined,
      targetKey: CustomerTutorialKeys.cartButtonKey,
      isCircle: true,
      padding: const EdgeInsets.all(8.0),
    ),
    CustomerTutorialStep(
      id: 'checkout',
      title: 'Checkout',
      description:
          'Ready to purchase? Checkout in seconds with your preferred payment method: GCash, Cash on Delivery, or convenient Store Pickup.',
      icon: Icons.payment_rounded,
      targetKey: CustomerTutorialKeys.cartButtonKey,
      isCircle: true,
      padding: const EdgeInsets.all(8.0),
    ),
    CustomerTutorialStep(
      id: 'orders',
      title: 'Orders / Delivery Tracking',
      description:
          'Track your purchases in real-time with live driver map navigation, delivery status updates, and your complete past order history.',
      icon: Icons.local_shipping_outlined,
      targetKey: CustomerTutorialKeys.ordersTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    CustomerTutorialStep(
      id: 'notifications',
      title: 'Notifications',
      description:
          'Stay informed with instant alerts on order updates, delivery status changes, restock announcements, and special store discounts.',
      icon: Icons.notifications_active_outlined,
      targetKey: CustomerTutorialKeys.notificationsTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    CustomerTutorialStep(
      id: 'profile',
      title: 'Profile',
      description:
          'Manage your delivery addresses, update GCash settings, chat with store support, or view this tutorial again anytime under Settings.',
      icon: Icons.person_outline_rounded,
      targetKey: CustomerTutorialKeys.profileTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
  ];
}
