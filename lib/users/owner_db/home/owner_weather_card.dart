import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/weather/weather_models.dart';
import '../../../shared/widgets/skeleton.dart';

/// Compact "current weather" strip for the Owner Home dashboard.
///
/// Reads from [WeatherService.instance] (currently mocked — see
/// weather_models.dart). Swapping in a real API later is a one-line
/// change since this widget only depends on the abstract
/// [WeatherService] / [WeatherSnapshot] contract.
class OwnerWeatherCard extends StatefulWidget {
  const OwnerWeatherCard({super.key});

  @override
  State<OwnerWeatherCard> createState() => _OwnerWeatherCardState();
}

class _OwnerWeatherCardState extends State<OwnerWeatherCard> {
  late final Future<WeatherSnapshot> _future = WeatherService.instance.current();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherSnapshot>(
      future: _future,
      builder: (context, snapshot) {
        final weather = snapshot.data;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: weather == null
              ? const WeatherCardSkeleton()
              : Container(
            key: const ValueKey('weather_content'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(weather.condition.icon, color: AppColors.primaryOrange, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${weather.temperatureCelsius.round()}°C',
                            style: const TextStyle(
                                color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· ${weather.condition.label}',
                            style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.8), fontSize: 13),
                          ),
                          const Spacer(),
                          Icon(Icons.place_outlined, size: 13, color: AppColors.secondaryText.withValues(alpha: 0.6)),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              weather.locationLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.secondaryText.withValues(alpha: 0.7), fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weather.advisory,
                        style: const TextStyle(color: AppColors.labelText, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}