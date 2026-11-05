import 'package:flutter_test/flutter_test.dart';
import 'package:sari_sari/core/services/onesignal_config.dart';
import 'package:sari_sari/core/weather/weather_models.dart';
import 'package:sari_sari/shared/utils/password_validator.dart';

void main() {
  group('Security & Environment Configuration Tests', () {
    test('OneSignalConfig should have valid configuration and active push capabilities', () {
      expect(OneSignalConfig.appId, isNotEmpty);
      expect(OneSignalConfig.appId, equals('02fc74ae-f3e7-42b3-9932-25c492412903'));
      expect(OneSignalConfig.isConfigured, isTrue);
      expect(OneSignalConfig.canSendPush, isTrue);
      expect(OneSignalConfig.restApiKey, isNotEmpty);
    });

    test('OpenWeatherMapService safely handles missing environment key with mock fallback', () async {
      final weatherService = OpenWeatherMapService();
      expect(OpenWeatherMapService.primaryApiKey, isEmpty);

      // Should seamlessly fall back to mock data without throwing exceptions or logging secrets
      final snapshot = await weatherService.current();
      expect(snapshot, isNotNull);
      expect(snapshot.locationLabel, isNotEmpty);
      expect(snapshot.temperatureCelsius, isPositive);
    });

    test('PasswordValidator correctly verifies password safety rules', () {
      expect(PasswordValidator.validate(''), isNotNull);
      expect(PasswordValidator.validate('123'), isNotNull);
      expect(PasswordValidator.validate('Secret123!'), isNull);
    });
  });
}
