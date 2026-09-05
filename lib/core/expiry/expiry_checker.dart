import 'package:flutter/foundation.dart';

/// Result of checking an expiry date against "today" and the configured
/// notification period.
///
/// This is the single shared vocabulary used by *both* entry points of the
/// Expiration Notification flow:
///  - Path A — POS scan/search, while ringing up a sale
///  - Path B — manual product tap in Inventory or Home
///
/// Neither screen computes its own "is this expiring?" logic; they both
/// ask [ExpiryChecker.statusOf] the same question, so a batch can never be
/// "expiring soon" on one screen and "fine" on another.
enum ExpiryStatus { none, expiringSoon, expired }

extension ExpiryStatusLabel on ExpiryStatus {
  String get label {
    switch (this) {
      case ExpiryStatus.none:
        return 'Fresh';
      case ExpiryStatus.expiringSoon:
        return 'Expiring Soon';
      case ExpiryStatus.expired:
        return 'Expired';
    }
  }
}

/// Single source of truth for "is this expiry date a problem right now?".
///
/// [notificationPeriodDays] is the configurable notification window
/// mentioned in the flow spec (e.g. warn 7 days out). Change it here and
/// every screen that checks expiry status picks it up automatically.
@immutable
class ExpiryChecker {
  const ExpiryChecker({this.notificationPeriodDays = 7});

  /// How many days out from today counts as "expiring soon".
  final int notificationPeriodDays;

  /// Returns [ExpiryStatus.none] for a null date (no expiry tracked),
  /// [ExpiryStatus.expired] if it's already past, or
  /// [ExpiryStatus.expiringSoon] if it falls within
  /// [notificationPeriodDays] from now.
  ExpiryStatus statusOf(DateTime? expiryDate, {DateTime? now}) {
    if (expiryDate == null) return ExpiryStatus.none;
    final today = now ?? DateTime.now();
    if (expiryDate.isBefore(today)) return ExpiryStatus.expired;
    final daysLeft = expiryDate.difference(today).inDays;
    if (daysLeft <= notificationPeriodDays) return ExpiryStatus.expiringSoon;
    return ExpiryStatus.none;
  }

  /// The default checker instance (7-day notification window) shared
  /// across the app unless a screen is explicitly configured otherwise.
  static const ExpiryChecker standard = ExpiryChecker();
}