import 'package:flutter/material.dart';

import 'customer_dashboard.dart';

/// Entry point widget for the customer side of the app.
///
/// This is the widget your login/authentication flow already navigates to
/// once a customer signs in. It now delegates straight to
/// [CustomerDashboard], which owns the floating bottom navigation bar and
/// the four customer tabs (Home, Notifications, My Purchases, Profile).
///
/// Kept as its own class — rather than deleted or renamed — so nothing
/// elsewhere in your app that references `CustomerDb()` (e.g. in your
/// auth/login flow) needs to change.
class CustomerDb extends StatelessWidget {
  const CustomerDb({super.key});

  @override
  Widget build(BuildContext context) {
    return const CustomerDashboard();
  }
}