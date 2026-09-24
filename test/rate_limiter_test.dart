import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/core/services/rate_limiter_service.dart';

void main() {
  group('RateLimiterService Tests', () {
    late RateLimiterService rateLimiter;

    setUp(() {
      rateLimiter = RateLimiterService.instance;
      rateLimiter.clearLocalCacheForTesting();
    });

    test('Checkout rate limit permits up to 3 attempts within 60s', () async {
      const identifier = 'user123';

      final res1 = await rateLimiter.checkAndRecord(RateLimitAction.checkout, identifier);
      expect(res1.isAllowed, isTrue);

      final res2 = await rateLimiter.checkAndRecord(RateLimitAction.checkout, identifier);
      expect(res2.isAllowed, isTrue);

      final res3 = await rateLimiter.checkAndRecord(RateLimitAction.checkout, identifier);
      expect(res3.isAllowed, isTrue);

      final res4 = await rateLimiter.checkAndRecord(RateLimitAction.checkout, identifier);
      expect(res4.isAllowed, isFalse);
      expect(res4.retryAfterSeconds, greaterThan(0));
      expect(res4.message, contains('Please wait'));
    });

    test('Login rate limit permits up to 5 attempts before lockout', () async {
      const identifier = 'test@example.com';

      for (int i = 0; i < 5; i++) {
        final res = await rateLimiter.checkAndRecord(RateLimitAction.login, identifier);
        expect(res.isAllowed, isTrue, reason: 'Attempt ${i + 1} should be allowed');
      }

      final blockedRes = await rateLimiter.checkAndRecord(RateLimitAction.login, identifier);
      expect(blockedRes.isAllowed, isFalse);
      expect(blockedRes.retryAfterSeconds, greaterThan(0));
    });

    test('Resetting rate limit clears lockout for successful authentication', () async {
      const identifier = 'user@test.com';

      for (int i = 0; i < 5; i++) {
        await rateLimiter.checkAndRecord(RateLimitAction.login, identifier);
      }

      var check = await rateLimiter.checkAndRecord(RateLimitAction.login, identifier);
      expect(check.isAllowed, isFalse);

      await rateLimiter.reset(RateLimitAction.login, identifier);

      check = await rateLimiter.checkAndRecord(RateLimitAction.login, identifier);
      expect(check.isAllowed, isTrue);
    });
  });
}
