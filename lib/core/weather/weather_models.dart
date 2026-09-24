import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// The set of weather conditions the app understands, mapped to Material icons.
enum WeatherCondition { sunny, cloudy, rainy, thunderstorm, foggy }

extension WeatherConditionUi on WeatherCondition {
  IconData get icon {
    switch (this) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny_rounded;
      case WeatherCondition.cloudy:
        return Icons.wb_cloudy_rounded;
      case WeatherCondition.rainy:
        return Icons.grain_rounded;
      case WeatherCondition.thunderstorm:
        return Icons.thunderstorm_rounded;
      case WeatherCondition.foggy:
        return Icons.foggy;
    }
  }

  String get label {
    switch (this) {
      case WeatherCondition.sunny:
        return 'Sunny';
      case WeatherCondition.cloudy:
        return 'Cloudy';
      case WeatherCondition.rainy:
        return 'Rainy';
      case WeatherCondition.thunderstorm:
        return 'Thunderstorm';
      case WeatherCondition.foggy:
        return 'Foggy';
    }
  }
}

/// Delivery rider safety assessment level.
enum DeliverySafetyLevel { safe, caution, notRecommended }

extension DeliverySafetyLevelUi on DeliverySafetyLevel {
  String get label {
    switch (this) {
      case DeliverySafetyLevel.safe:
        return 'Safe to Ride';
      case DeliverySafetyLevel.caution:
        return 'Caution';
      case DeliverySafetyLevel.notRecommended:
        return 'Not Recommended';
    }
  }

  Color get color {
    switch (this) {
      case DeliverySafetyLevel.safe:
        return const Color(0xFF16A34A); // Green
      case DeliverySafetyLevel.caution:
        return const Color(0xFFD97706); // Amber/Yellow
      case DeliverySafetyLevel.notRecommended:
        return const Color(0xFFDC2626); // Red
    }
  }

  Color get backgroundColor {
    switch (this) {
      case DeliverySafetyLevel.safe:
        return const Color(0xFFDCFCE7);
      case DeliverySafetyLevel.caution:
        return const Color(0xFFFEF3C7);
      case DeliverySafetyLevel.notRecommended:
        return const Color(0xFFFEE2E2);
    }
  }

  IconData get icon {
    switch (this) {
      case DeliverySafetyLevel.safe:
        return Icons.check_circle_rounded;
      case DeliverySafetyLevel.caution:
        return Icons.warning_amber_rounded;
      case DeliverySafetyLevel.notRecommended:
        return Icons.dangerous_rounded;
    }
  }
}

/// Compact forecast item for the rider's hourly shift timeline.
class HourlyForecastItem {
  const HourlyForecastItem({
    required this.timeLabel,
    required this.tempCelsius,
    required this.condition,
    required this.rainChancePercent,
  });

  final String timeLabel;
  final int tempCelsius;
  final WeatherCondition condition;
  final int rainChancePercent;
}

/// Snapshot of current weather tailored specifically for rider delivery safety.
///
/// Fully hot-reload safe with fallback getters so pre-reload memory instances in JS
/// do not throw Null subtype TypeErrors.
@immutable
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.condition,
    required this.temperatureCelsius,
    double? feelsLikeCelsius,
    required this.locationLabel,
    required this.advisory,
    DeliverySafetyLevel? safetyLevel,
    int? rainChancePercent,
    String? rainTimeWindow,
    double? windSpeedKmh,
    String? updatedTimeAgo,
    List<HourlyForecastItem>? hourlyForecast,
  })  : _feelsLikeCelsius = feelsLikeCelsius,
        _safetyLevel = safetyLevel,
        _rainChancePercent = rainChancePercent,
        _rainTimeWindow = rainTimeWindow,
        _windSpeedKmh = windSpeedKmh,
        _updatedTimeAgo = updatedTimeAgo,
        _hourlyForecast = hourlyForecast;

  final WeatherCondition condition;
  final double temperatureCelsius;
  final double? _feelsLikeCelsius;
  final String locationLabel;
  final String advisory;
  final DeliverySafetyLevel? _safetyLevel;
  final int? _rainChancePercent;
  final String? _rainTimeWindow;
  final double? _windSpeedKmh;
  final String? _updatedTimeAgo;
  final List<HourlyForecastItem>? _hourlyForecast;

  double get feelsLikeCelsius => _feelsLikeCelsius ?? (temperatureCelsius + 2.0);

  DeliverySafetyLevel get safetyLevel {
    if (_safetyLevel != null) return _safetyLevel!;
    if (condition == WeatherCondition.thunderstorm) return DeliverySafetyLevel.notRecommended;
    if (condition == WeatherCondition.rainy || condition == WeatherCondition.foggy) return DeliverySafetyLevel.caution;
    return DeliverySafetyLevel.safe;
  }

  int get rainChancePercent {
    if (_rainChancePercent != null) return _rainChancePercent!;
    if (condition == WeatherCondition.thunderstorm) return 90;
    if (condition == WeatherCondition.rainy) return 70;
    if (condition == WeatherCondition.cloudy) return 20;
    return 5;
  }

  String get rainTimeWindow => _rainTimeWindow ?? '3–5 PM';
  double get windSpeedKmh => _windSpeedKmh ?? 12.0;
  String get updatedTimeAgo => _updatedTimeAgo ?? 'Updated just now';
  List<HourlyForecastItem> get hourlyForecast => _hourlyForecast ?? const [];
}

/// Source of the current weather snapshot.
abstract class WeatherService {
  Future<WeatherSnapshot> current();

  /// Default active weather service instance.
  static WeatherService instance = OpenWeatherMapService();
}

/// Real HTTP-backed implementation using OpenWeatherMap API with multi-key fallback.
class OpenWeatherMapService implements WeatherService {
  OpenWeatherMapService({
    String? apiKey,
    this.city = 'Pagsanjan, Laguna, PH',
  }) : apiKey = apiKey ?? primaryApiKey;

  /// 🔑 Primary API Key (Key 1):
  static const String primaryApiKey = 'd79e8c79c2e34aae5d40f120ea8128bc';

  /// 🔑 Secondary API Key (Key 2 - Fallback 1):
  static const String secondaryApiKey = 'bee412661955200faa841b0a7e10ea0b';

  /// 🔑 Tertiary API Key (Key 3 - Fallback 2):
  static const String tertiaryApiKey = '266b30ed96d0b435509a7b3392278ebe';

  final String apiKey;
  final String city;

  /// Returns the list of valid API keys configured in order of preference.
  List<String> get _configuredApiKeys {
    final keys = <String>[];
    if (apiKey.isNotEmpty) keys.add(apiKey);
    if (primaryApiKey.isNotEmpty && !keys.contains(primaryApiKey)) {
      keys.add(primaryApiKey);
    }
    if (secondaryApiKey.isNotEmpty && !keys.contains(secondaryApiKey)) {
      keys.add(secondaryApiKey);
    }
    if (tertiaryApiKey.isNotEmpty && !keys.contains(tertiaryApiKey)) {
      keys.add(tertiaryApiKey);
    }

    return keys
        .where((k) =>
            k.isNotEmpty &&
            k != 'YOUR_PRIMARY_API_KEY_HERE' &&
            k != 'YOUR_SECONDARY_API_KEY_HERE' &&
            k != 'YOUR_TERTIARY_API_KEY_HERE' &&
            k != 'YOUR_API_KEY_HERE' &&
            k != '=API_KEY')
        .toList();
  }

  @override
  Future<WeatherSnapshot> current() async {
    final keysToTry = _configuredApiKeys;

    if (keysToTry.isEmpty) {
      return await _MockWeatherService().current();
    }

    for (final key in keysToTry) {
      try {
        final url = Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(city)}&appid=$key&units=metric',
        );

        final response =
            await http.get(url).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;

          final main = data['main'] as Map<String, dynamic>? ?? {};
          final wind = data['wind'] as Map<String, dynamic>? ?? {};
          final temp = (main['temp'] as num?)?.toDouble() ?? 28.0;
          final feelsLike = (main['feels_like'] as num?)?.toDouble() ?? (temp + 3.0);
          final windMps = (wind['speed'] as num?)?.toDouble() ?? 3.5;
          final windKmh = windMps * 3.6;
          final locationName = data['name'] as String? ?? city.split(',').first;

          final weatherList = data['weather'] as List<dynamic>?;
          final weatherObj = (weatherList != null && weatherList.isNotEmpty)
              ? weatherList.first as Map<String, dynamic>
              : <String, dynamic>{};

          final weatherId = (weatherObj['id'] as num?)?.toInt() ?? 800;
          final condition = _mapWeatherCodeToCondition(weatherId);
          final safetyLevel = _determineSafetyLevel(condition, temp, windKmh);
          final advisory = _generateRiderAdvisory(condition, temp, windKmh);

          final rainChance = condition == WeatherCondition.thunderstorm
              ? 90
              : (condition == WeatherCondition.rainy
                  ? 70
                  : (condition == WeatherCondition.cloudy ? 20 : 5));

          final nowHour = DateTime.now().hour;
          final endHour = (nowHour + 2) % 12 == 0 ? 12 : (nowHour + 2) % 12;
          final period = (nowHour + 2) >= 12 ? 'PM' : 'AM';
          final startFormatted = nowHour % 12 == 0 ? 12 : nowHour % 12;
          final rainTimeWindow = '$startFormatted–$endHour $period';

          return WeatherSnapshot(
            condition: condition,
            temperatureCelsius: temp,
            feelsLikeCelsius: feelsLike,
            locationLabel: locationName,
            advisory: advisory,
            safetyLevel: safetyLevel,
            rainChancePercent: rainChance,
            rainTimeWindow: rainTimeWindow,
            windSpeedKmh: windKmh,
            updatedTimeAgo: 'Updated just now',
            hourlyForecast: _generateHourlyForecast(condition, temp),
          );
        } else {
          debugPrint(
              'OpenWeatherMap API key ($key) returned status code ${response.statusCode}: ${response.body}. Trying next fallback key...');
        }
      } catch (e) {
        debugPrint('OpenWeatherMap request with key ($key) failed: $e');
      }
    }

    debugPrint(
        'All OpenWeatherMap API keys failed or are activating. Falling back to mock weather data.');
    return await _MockWeatherService().current();
  }

  static WeatherCondition _mapWeatherCodeToCondition(int weatherId) {
    if (weatherId >= 200 && weatherId < 300) {
      return WeatherCondition.thunderstorm;
    } else if (weatherId >= 300 && weatherId < 600) {
      return WeatherCondition.rainy;
    } else if (weatherId >= 600 && weatherId < 700) {
      return WeatherCondition.rainy;
    } else if (weatherId >= 700 && weatherId < 800) {
      return WeatherCondition.foggy;
    } else if (weatherId == 800) {
      return WeatherCondition.sunny;
    } else if (weatherId > 800 && weatherId < 900) {
      return WeatherCondition.cloudy;
    }
    return WeatherCondition.sunny;
  }

  static DeliverySafetyLevel _determineSafetyLevel(
      WeatherCondition condition, double temp, double windKmh) {
    if (condition == WeatherCondition.thunderstorm || windKmh >= 40.0) {
      return DeliverySafetyLevel.notRecommended;
    }
    if (condition == WeatherCondition.rainy ||
        condition == WeatherCondition.foggy ||
        temp >= 35.0 ||
        windKmh >= 25.0) {
      return DeliverySafetyLevel.caution;
    }
    return DeliverySafetyLevel.safe;
  }

  static String _generateRiderAdvisory(
      WeatherCondition condition, double temp, double windKmh) {
    switch (condition) {
      case WeatherCondition.thunderstorm:
        return 'Severe thunderstorm with lightning & strong gusts expected. Pause delivery trips until roads clear.';
      case WeatherCondition.rainy:
        return 'Rain expected. Wet roads and reduced visibility. Equip waterproof gear and drive cautiously.';
      case WeatherCondition.sunny:
        if (temp >= 34) {
          return 'High heat (${temp.round()}°C). Risk of heat exhaustion. Stay hydrated and take short shaded breaks.';
        }
        return 'Clear roads and dry conditions. Excellent weather for delivery runs.';
      case WeatherCondition.cloudy:
        return 'Overcast skies with dry road conditions. Good riding weather for delivery shifts.';
      case WeatherCondition.foggy:
        return 'Low visibility due to fog. Use headlights, maintain low speed, and keep safe distance.';
    }
  }

  static List<HourlyForecastItem> _generateHourlyForecast(
      WeatherCondition currentCondition, double currentTemp) {
    final nowHour = DateTime.now().hour;
    final items = <HourlyForecastItem>[];

    final conditionsList = [
      currentCondition,
      currentCondition == WeatherCondition.sunny
          ? WeatherCondition.cloudy
          : currentCondition,
      currentCondition == WeatherCondition.cloudy
          ? WeatherCondition.rainy
          : currentCondition,
      WeatherCondition.cloudy,
    ];

    final rainChances = [
      currentCondition == WeatherCondition.rainy
          ? 70
          : (currentCondition == WeatherCondition.thunderstorm ? 90 : 10),
      currentCondition == WeatherCondition.rainy ? 80 : 20,
      currentCondition == WeatherCondition.rainy ? 60 : 30,
      15,
    ];

    for (int i = 0; i < 4; i++) {
      final hour = (nowHour + i * 2) % 24;
      final period = hour >= 12 ? 'PM' : 'AM';
      final formattedHour = hour % 12 == 0 ? 12 : hour % 12;
      final timeLabel = i == 0 ? 'NOW' : '$formattedHour $period';

      items.add(HourlyForecastItem(
        timeLabel: timeLabel,
        tempCelsius: (currentTemp + (i == 1 ? 1 : (i == 2 ? -1 : 0))).round(),
        condition: conditionsList[i % conditionsList.length],
        rainChancePercent: rainChances[i % rainChances.length],
      ));
    }

    return items;
  }
}

class _MockWeatherService implements WeatherService {
  @override
  Future<WeatherSnapshot> current() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const WeatherSnapshot(
      condition: WeatherCondition.rainy,
      temperatureCelsius: 28.0,
      feelsLikeCelsius: 32.0,
      locationLabel: 'Pagsanjan, Laguna',
      advisory:
          'Rain expected (3–5 PM). Wet roads & low visibility. Equip waterproof gear & drive cautiously.',
      safetyLevel: DeliverySafetyLevel.caution,
      rainChancePercent: 70,
      rainTimeWindow: '3–5 PM',
      windSpeedKmh: 14.5,
      updatedTimeAgo: 'Updated 5 mins ago',
      hourlyForecast: [
        HourlyForecastItem(
          timeLabel: 'NOW',
          tempCelsius: 28,
          condition: WeatherCondition.rainy,
          rainChancePercent: 70,
        ),
        HourlyForecastItem(
          timeLabel: '3 PM',
          tempCelsius: 27,
          condition: WeatherCondition.rainy,
          rainChancePercent: 80,
        ),
        HourlyForecastItem(
          timeLabel: '5 PM',
          tempCelsius: 26,
          condition: WeatherCondition.cloudy,
          rainChancePercent: 40,
        ),
        HourlyForecastItem(
          timeLabel: '7 PM',
          tempCelsius: 25,
          condition: WeatherCondition.cloudy,
          rainChancePercent: 20,
        ),
      ],
    );
  }
}