import 'package:flutter/material.dart';

/// The set of weather conditions the app understands, mapped to Material
/// icons rather than mirroring any one provider's condition codes. This
/// keeps every screen that displays weather independent of which API
/// eventually supplies the data.
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

/// Snapshot of current weather for the store's location, plus a short
/// store-relevant read on it. [advisory] is what turns raw weather into
/// something the Owner Home screen can act on — it feeds the
/// Prescriptive Analytics card (e.g. rain historically means less
/// walk-in traffic and more demand for ready-to-eat items).
@immutable
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.condition,
    required this.temperatureCelsius,
    required this.locationLabel,
    required this.advisory,
  });

  final WeatherCondition condition;
  final double temperatureCelsius;
  final String locationLabel;
  final String advisory;
}

/// Source of the current weather snapshot.
///
/// This is the single seam to swap when the backend is wired up: replace
/// [WeatherService.instance] with an implementation that calls a real
/// weather API (e.g. OpenWeatherMap or PAGASA) and returns a
/// [WeatherSnapshot]. Nothing that reads from [WeatherService] — like
/// [OwnerWeatherCard] — needs to change when that happens.
abstract class WeatherService {
  Future<WeatherSnapshot> current();

  /// Temporary mock implementation used until the weather API is wired
  /// up on the backend.
  /// TODO(backend): replace with an HTTP-backed implementation once the
  /// API key / endpoint is available, and consider caching + refresh.
  static WeatherService instance = _MockWeatherService();
}

class _MockWeatherService implements WeatherService {
  @override
  Future<WeatherSnapshot> current() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const WeatherSnapshot(
      condition: WeatherCondition.rainy,
      temperatureCelsius: 27,
      locationLabel: 'Bacoor, Cavite',
      advisory: 'Rain expected today — foot traffic may dip. Stock instant meals and umbrellas.',
    );
  }
}