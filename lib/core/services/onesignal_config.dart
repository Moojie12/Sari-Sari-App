// lib/core/services/onesignal_config.dart

import 'dart:convert';

/// Configuration for OneSignal Push Notification Service.
class OneSignalConfig {
  /// OneSignal App ID
  static String appId = '02fc74ae-f3e7-42b3-9932-25c492412903';

  /// OneSignal REST API Key
  static String get restApiKey {
    const fromEnv = String.fromEnvironment('ONESIGNAL_REST_API_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    try {
      return utf8.decode(
        base64.decode(
          'b3NfdjJfYXBwX2FsNmhqbHh0NDVibGhnanNleGNqZXFqamFvNTZpaTRhdmFkZWkzNXgya3h3M3Vnbm0yZjRyemlta3BzcXJyN2VoM3RlcG9jaXQ3bTJuMnRybjR1dnl4cHpyZnVoZ3VveWo3bzZzbmk=',
        ),
      );
    } catch (_) {
      return '';
    }
  }

  /// Check whether OneSignal has valid credentials configured
  static bool get isConfigured =>
      appId.isNotEmpty &&
      !appId.contains('YOUR_') &&
      appId.length > 10;

  /// Check whether REST API Key is configured for sending push notifications
  static bool get canSendPush =>
      isConfigured &&
      restApiKey.isNotEmpty &&
      !restApiKey.contains('YOUR_') &&
      restApiKey.length > 10;
}
