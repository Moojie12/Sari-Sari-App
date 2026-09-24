import 'dart:async';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

enum RateLimitAction {
  checkout,
  login,
  promoCode,
  productPolling;

  String get dbKey {
    switch (this) {
      case RateLimitAction.checkout:
        return 'checkout';
      case RateLimitAction.login:
        return 'login';
      case RateLimitAction.promoCode:
        return 'promo_code';
      case RateLimitAction.productPolling:
        return 'product_polling';
    }
  }

  int get maxAttempts {
    switch (this) {
      case RateLimitAction.checkout:
        return 3;
      case RateLimitAction.login:
        return 5;
      case RateLimitAction.promoCode:
        return 5;
      case RateLimitAction.productPolling:
        return 60;
    }
  }

  Duration get windowDuration {
    switch (this) {
      case RateLimitAction.checkout:
        return const Duration(seconds: 60);
      case RateLimitAction.login:
        return const Duration(minutes: 5);
      case RateLimitAction.promoCode:
        return const Duration(minutes: 10);
      case RateLimitAction.productPolling:
        return const Duration(seconds: 60);
    }
  }

  Duration get lockoutDuration {
    switch (this) {
      case RateLimitAction.checkout:
        return const Duration(seconds: 60);
      case RateLimitAction.login:
        return const Duration(minutes: 15);
      case RateLimitAction.promoCode:
        return const Duration(minutes: 15);
      case RateLimitAction.productPolling:
        return const Duration(seconds: 30);
    }
  }

  String get friendlyName {
    switch (this) {
      case RateLimitAction.checkout:
        return 'checkout attempts';
      case RateLimitAction.login:
        return 'login attempts';
      case RateLimitAction.promoCode:
        return 'promo code entries';
      case RateLimitAction.productPolling:
        return 'requests';
    }
  }
}

class RateLimitResult {
  final bool isAllowed;
  final int remainingAttempts;
  final int retryAfterSeconds;
  final String? message;

  const RateLimitResult({
    required this.isAllowed,
    required this.remainingAttempts,
    required this.retryAfterSeconds,
    this.message,
  });

  factory RateLimitResult.allowed({required int remaining}) => RateLimitResult(
        isAllowed: true,
        remainingAttempts: remaining,
        retryAfterSeconds: 0,
      );

  factory RateLimitResult.denied({
    required int retryAfterSeconds,
    required String actionName,
  }) {
    final minutes = (retryAfterSeconds / 60).ceil();
    final timeStr = retryAfterSeconds >= 60
        ? '$minutes minute${minutes > 1 ? 's' : ''}'
        : '$retryAfterSeconds second${retryAfterSeconds > 1 ? 's' : ''}';

    return RateLimitResult(
      isAllowed: false,
      remainingAttempts: 0,
      retryAfterSeconds: retryAfterSeconds,
      message: 'Too many $actionName. Please wait $timeStr before trying again.',
    );
  }
}

class _LocalRateRecord {
  final List<DateTime> attempts = [];
  DateTime? lockoutUntil;
}

class RateLimiterService {
  RateLimiterService._();
  static final RateLimiterService instance = RateLimiterService._();
  factory RateLimiterService() => instance;

  final SupabaseService _supabase = SupabaseService();
  final Map<String, _LocalRateRecord> _localCache = {};

  String _buildKey(RateLimitAction action, String identifier) =>
      '${action.dbKey}:$identifier';

  /// Check whether an action is allowed and record the attempt if allowed.
  Future<RateLimitResult> checkAndRecord(
    RateLimitAction action,
    String identifier,
  ) async {
    final key = _buildKey(action, identifier);
    final now = DateTime.now();

    // 1. First check DB persisted rate limits
    try {
      final dbResult = await _supabase.checkRateLimitInDb(
        identifier: identifier,
        actionType: action.dbKey,
        maxAttempts: action.maxAttempts,
        windowSeconds: action.windowDuration.inSeconds,
        lockoutSeconds: action.lockoutDuration.inSeconds,
      );

      if (dbResult != null) {
        final isAllowed = dbResult['is_allowed'] == true;
        final retryAfter = (dbResult['retry_after_seconds'] as num?)?.toInt() ?? 0;
        final remaining = (dbResult['remaining_attempts'] as num?)?.toInt() ?? 0;

        if (!isAllowed) {
          return RateLimitResult.denied(
            retryAfterSeconds: retryAfter,
            actionName: action.friendlyName,
          );
        }
        return RateLimitResult.allowed(remaining: remaining);
      }
    } catch (e) {
      debugPrint('Supabase rate limiter check failed, using local fallback: $e');
    }

    // 2. In-memory local fallback if offline or DB unavailable
    final record = _localCache.putIfAbsent(key, () => _LocalRateRecord());

    // Check if locked out
    if (record.lockoutUntil != null) {
      if (now.isBefore(record.lockoutUntil!)) {
        final diff = record.lockoutUntil!.difference(now).inSeconds;
        return RateLimitResult.denied(
          retryAfterSeconds: diff > 0 ? diff : 1,
          actionName: action.friendlyName,
        );
      } else {
        // Lockout expired
        record.lockoutUntil = null;
        record.attempts.clear();
      }
    }

    // Clean up attempts outside sliding window
    final windowStart = now.subtract(action.windowDuration);
    record.attempts.removeWhere((t) => t.isBefore(windowStart));

    if (record.attempts.length >= action.maxAttempts) {
      record.lockoutUntil = now.add(action.lockoutDuration);
      final diff = action.lockoutDuration.inSeconds;
      return RateLimitResult.denied(
        retryAfterSeconds: diff,
        actionName: action.friendlyName,
      );
    }

    // Record attempt
    record.attempts.add(now);
    final remaining = action.maxAttempts - record.attempts.length;
    return RateLimitResult.allowed(remaining: remaining);
  }

  /// Reset/clear rate limits for a given key (e.g. after successful login).
  Future<void> reset(RateLimitAction action, String identifier) async {
    final key = _buildKey(action, identifier);
    _localCache.remove(key);

    try {
      await _supabase.clearRateLimitsInDb(identifier, action.dbKey);
    } catch (e) {
      debugPrint('Failed to clear DB rate limits: $e');
    }
  }

  @visibleForTesting
  void clearLocalCacheForTesting() {
    _localCache.clear();
  }
}
