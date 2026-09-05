import 'package:flutter/material.dart';

import '../../../core/expiry/expiry_checker.dart';

/// Small pill showing a batch's [ExpiryStatus].
///
/// Used by both entry points of the Expiration Notification flow — the
/// POS batch-selection sheet (Path A) and the Inventory/Home batch-detail
/// sheet (Path B) — so "Expiring Soon" always looks and reads the same no
/// matter which screen surfaced it.
class ExpiryBadge extends StatelessWidget {
  const ExpiryBadge({super.key, required this.status});

  final ExpiryStatus status;

  Color get _color {
    switch (status) {
      case ExpiryStatus.expired:
        return Colors.red;
      case ExpiryStatus.expiringSoon:
        return Colors.deepOrange;
      case ExpiryStatus.none:
        return Colors.green;
    }
  }

  IconData get _icon {
    switch (status) {
      case ExpiryStatus.expired:
        return Icons.block;
      case ExpiryStatus.expiringSoon:
        return Icons.event_busy;
      case ExpiryStatus.none:
        return Icons.check_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12, color: _color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _color),
          ),
        ],
      ),
    );
  }
}