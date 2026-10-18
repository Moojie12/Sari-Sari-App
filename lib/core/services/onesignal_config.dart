// lib/core/services/onesignal_config.dart

/// Configuration for OneSignal Push Notification Service.
class OneSignalConfig {
  /// OneSignal App ID
  static String appId = '02fc74ae-f3e7-42b3-9932-25c492412903';

  /// OneSignal REST API Key
  static String restApiKey = const String.fromEnvironment(
    'ONESIGNAL_REST_API_KEY',
    defaultValue: '',
  );

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
