import 'package:flutter/material.dart';

/// GlobalKeys used to anchor the spotlight tutorial onto customer app features.
class CustomerTutorialKeys {
  CustomerTutorialKeys._();

  /// Bottom navigation bar — Home tab
  static GlobalKey homeTabKey = GlobalKey(debugLabel: 'tutorial_home_tab');

  /// Search bar on the customer Home page
  static GlobalKey searchBarKey = GlobalKey(debugLabel: 'tutorial_search_bar');

  /// Add to Cart button on the first product card
  static GlobalKey addToCartKey = GlobalKey(debugLabel: 'tutorial_add_to_cart');

  /// First product card container on Home page
  static GlobalKey firstProductCardKey = GlobalKey(debugLabel: 'tutorial_first_product_card');

  /// Floating Cart shortcut button in the top right
  static GlobalKey cartButtonKey = GlobalKey(debugLabel: 'tutorial_cart_button');

  /// Bottom navigation bar — Notifications tab
  static GlobalKey notificationsTabKey = GlobalKey(debugLabel: 'tutorial_notifications_tab');

  /// Bottom navigation bar — My Purchases / Orders tab
  static GlobalKey ordersTabKey = GlobalKey(debugLabel: 'tutorial_orders_tab');

  /// Bottom navigation bar — Profile tab
  static GlobalKey profileTabKey = GlobalKey(debugLabel: 'tutorial_profile_tab');

  /// Re-generates fresh GlobalKeys to prevent Duplicate GlobalKey assertions when rebuilding routes
  static void reset() {
    homeTabKey = GlobalKey(debugLabel: 'tutorial_home_tab');
    searchBarKey = GlobalKey(debugLabel: 'tutorial_search_bar');
    addToCartKey = GlobalKey(debugLabel: 'tutorial_add_to_cart');
    firstProductCardKey = GlobalKey(debugLabel: 'tutorial_first_product_card');
    cartButtonKey = GlobalKey(debugLabel: 'tutorial_cart_button');
    notificationsTabKey = GlobalKey(debugLabel: 'tutorial_notifications_tab');
    ordersTabKey = GlobalKey(debugLabel: 'tutorial_orders_tab');
    profileTabKey = GlobalKey(debugLabel: 'tutorial_profile_tab');
  }
}
