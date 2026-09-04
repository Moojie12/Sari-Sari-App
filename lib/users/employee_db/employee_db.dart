import 'package:flutter/material.dart';

import 'employee_dashboard.dart';

/// Entry point widget for the employee (Cashier / Inventory Staff) side
/// of the app.
///
/// This is the widget your login/authentication flow already navigates to
/// once an employee signs in. It delegates straight to
/// [EmployeeDashboard], which owns the floating bottom navigation bar and
/// the employee tabs (Home, POS, Inventory, Profile).
///
/// Kept as its own class — rather than deleted or renamed — so nothing
/// elsewhere in your app that references `EmployeeDb()` (e.g. in your
/// auth/login flow) needs to change.
class EmployeeDb extends StatelessWidget {
  const EmployeeDb({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmployeeDashboard();
  }
}