import 'package:flutter/material.dart';

/// GlobalKeys used to anchor the spotlight tutorial onto customer app features.
class CustomerTutorialKeys {
  CustomerTutorialKeys._();

  /// Bottom navigation bar — Home tab
  static final GlobalKey homeTabKey = GlobalKey(debugLabel: 'tutorial_home_tab');

  /// Search bar on the customer Home page
  static final GlobalKey searchBarKey = GlobalKey(debugLabel: 'tutorial_search_bar');

  /// Add to Cart button on the first product card
  static final GlobalKey addToCartKey = GlobalKey(debugLabel: 'tutorial_add_to_cart');

  /// First product card container on Home page
  static final GlobalKey firstProductCardKey = GlobalKey(debugLabel: 'tutorial_first_product_card');

  /// Floating Cart shortcut button in the top right
  static final GlobalKey cartButtonKey = GlobalKey(debugLabel: 'tutorial_cart_button');

  /// Bottom navigation bar — Notifications tab
  static final GlobalKey notificationsTabKey = GlobalKey(debugLabel: 'tutorial_notifications_tab');

  /// Bottom navigation bar — My Purchases / Orders tab
  static final GlobalKey ordersTabKey = GlobalKey(debugLabel: 'tutorial_orders_tab');

  /// Bottom navigation bar — Profile tab
  static final GlobalKey profileTabKey = GlobalKey(debugLabel: 'tutorial_profile_tab');
}
