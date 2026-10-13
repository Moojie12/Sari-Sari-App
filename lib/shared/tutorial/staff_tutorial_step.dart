import 'package:flutter/material.dart';

/// Keys used to anchor the tutorial spotlight onto Owner and Employee features.
class StaffTutorialKeys {
  StaffTutorialKeys._();

  static final GlobalKey homeTabKey = GlobalKey(debugLabel: 'staff_tut_home_tab');
  static final GlobalKey posTabKey = GlobalKey(debugLabel: 'staff_tut_pos_tab');
  static final GlobalKey inventoryTabKey = GlobalKey(debugLabel: 'staff_tut_inventory_tab');
  static final GlobalKey ordersTabKey = GlobalKey(debugLabel: 'staff_tut_orders_tab');
  static final GlobalKey profileTabKey = GlobalKey(debugLabel: 'staff_tut_profile_tab');
}

/// Represents a single feature step in Owner/Employee tutorials.
class StaffTutorialStep {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final GlobalKey? targetKey;
  final bool isCircle;
  final double borderRadius;
  final EdgeInsets padding;

  const StaffTutorialStep({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.targetKey,
    this.isCircle = true,
    this.borderRadius = 16.0,
    this.padding = const EdgeInsets.all(8.0),
  });

  /// Standard sequence of steps for store Owners.
  static List<StaffTutorialStep> get ownerSteps => [
    StaffTutorialStep(
      id: 'owner_home',
      title: 'Store Dashboard (Home)',
      description:
          'Monitor your real-time store performance, today’s revenue, sales summaries, and weather forecasts to forecast customer demand.',
      icon: Icons.storefront_rounded,
      targetKey: StaffTutorialKeys.homeTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    StaffTutorialStep(
      id: 'owner_pos',
      title: 'POS (Point of Sale)',
      description:
          'Process walk-in customer purchases rapidly, scan barcodes, handle cash or GCash payments, and record daily shift transactions.',
      icon: Icons.point_of_sale_rounded,
      targetKey: StaffTutorialKeys.posTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    StaffTutorialStep(
      id: 'owner_inventory',
      title: 'Inventory & Stock Management',
      description:
          'Manage products, track batches and expiry dates, add new items, record stock adjustments, and log consumables or product losses.',
      icon: Icons.inventory_2_rounded,
      targetKey: StaffTutorialKeys.inventoryTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    StaffTutorialStep(
      id: 'owner_orders',
      title: 'Order Processing & Deliveries',
      description:
          'View online customer orders in real-time, update fulfillment stages, and assign drivers or delivery personnel for fast dispatch.',
      icon: Icons.receipt_long_rounded,
      targetKey: StaffTutorialKeys.ordersTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    StaffTutorialStep(
      id: 'owner_profile',
      title: 'Owner Settings & Analytics',
      description:
          'Access sales reports, operational logs, GCash refund section, promotional deals, and store configuration settings anytime.',
      icon: Icons.person_rounded,
      targetKey: StaffTutorialKeys.profileTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
  ];

  /// Standard sequence of steps for store Employees.
  static List<StaffTutorialStep> get employeeSteps => [
    StaffTutorialStep(
      id: 'emp_home',
      title: 'Employee Home',
      description:
          'View shift announcements, pending store tasks, and real-time operational notifications for low stock and expiring items.',
      icon: Icons.storefront_rounded,
      targetKey: StaffTutorialKeys.homeTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    StaffTutorialStep(
      id: 'emp_pos',
      title: 'Point of Sale (POS)',
      description:
          'Serve walk-in customers quickly. Scan barcodes, select quantities, accept cash or GCash, and print or save sales receipts.',
      icon: Icons.point_of_sale_rounded,
      targetKey: StaffTutorialKeys.posTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    StaffTutorialStep(
      id: 'emp_inventory',
      title: 'Inventory & Restocking',
      description:
          'Check current inventory counts, receive new supplier deliveries, monitor batch expiry alerts, and log consumables or damaged goods.',
      icon: Icons.inventory_2_rounded,
      targetKey: StaffTutorialKeys.inventoryTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    StaffTutorialStep(
      id: 'emp_orders',
      title: 'Customer Orders',
      description:
          'Process incoming orders from local customers, prepare packaging, and coordinate handover with delivery drivers.',
      icon: Icons.receipt_long_rounded,
      targetKey: StaffTutorialKeys.ordersTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
    StaffTutorialStep(
      id: 'emp_profile',
      title: 'My Profile & Records',
      description:
          'View your shift transaction logs, logged consumables, account credentials, and review this tutorial anytime under Settings.',
      icon: Icons.person_rounded,
      targetKey: StaffTutorialKeys.profileTabKey,
      isCircle: true,
      padding: const EdgeInsets.all(10.0),
    ),
  ];
}
