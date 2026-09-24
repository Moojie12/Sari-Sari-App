import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/weather/weather_models.dart';
import '../../../shared/widgets/skeleton.dart';

/// Compact, thin weather strip component used across Owner and Employee dashboards.
///
/// Tapping the strip opens a full Rider Safety & Weather Forecast Modal Bottom Sheet.
class OwnerWeatherCard extends StatefulWidget {
  const OwnerWeatherCard({super.key});

  @override
  State<OwnerWeatherCard> createState() => _OwnerWeatherCardState();
}

class _OwnerWeatherCardState extends State<OwnerWeatherCard> {
  late final Future<WeatherSnapshot> _future = WeatherService.instance.current();

  void _showFullForecastModal(BuildContext context, WeatherSnapshot weather) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _WeatherDetailsModal(weather: weather),
    );
  }

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
              : InkWell(
                  key: const ValueKey('weather_content'),
                  onTap: () => _showFullForecastModal(context, weather),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(weather.condition.icon, color: AppColors.primaryOrange, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '${weather.temperatureCelsius.round()}°C ${weather.condition.label}',
                          style: const TextStyle(
                            color: AppColors.darkText,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '· ${weather.locationLabel}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.secondaryText.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Color-coded Safety Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: weather.safetyLevel.backgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: weather.safetyLevel.color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                weather.safetyLevel.icon,
                                size: 11,
                                color: weather.safetyLevel.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                weather.safetyLevel.label,
                                style: TextStyle(
                                  color: weather.safetyLevel.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.secondaryText,
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// Modal Bottom Sheet displaying full rider safety & weather forecast details.
class _WeatherDetailsModal extends StatelessWidget {
  const _WeatherDetailsModal({required this.weather});

  final WeatherSnapshot weather;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 16, color: AppColors.primaryOrange),
                    const SizedBox(width: 4),
                    Text(
                      weather.locationLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Prominent Safety Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: weather.safetyLevel.backgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: weather.safetyLevel.color.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: weather.safetyLevel.color.withValues(alpha: 0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(
                      weather.safetyLevel.icon,
                      color: weather.safetyLevel.color,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DELIVERY SAFETY STATUS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: weather.safetyLevel.color,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          weather.safetyLevel.label,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: weather.safetyLevel.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Temperature & Conditions Block
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    weather.condition.icon,
                    color: AppColors.primaryOrange,
                    size: 30,
                  ),
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
                              color: AppColors.darkText,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Feels like ${weather.feelsLikeCelsius.round()}°C',
                            style: const TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        weather.condition.label,
                        style: const TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Stats Bar: Rain & Wind
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.lightBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.umbrella_outlined, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        '${weather.rainChancePercent}% rain (${weather.rainTimeWindow})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                  Container(width: 1, height: 18, color: AppColors.borderColor),
                  Row(
                    children: [
                      const Icon(Icons.air, size: 16, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(
                        '${weather.windSpeedKmh.round()} km/h wind',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Rider Advisory Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: weather.safetyLevel.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: weather.safetyLevel.color.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 18,
                    color: weather.safetyLevel.color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      weather.advisory,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4-Hour Shift Forecast Strip
            if (weather.hourlyForecast.isNotEmpty) ...[
              const Text(
                '4-HOUR RIDER SHIFT FORECAST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.secondaryText,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: weather.hourlyForecast.map((item) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.lightBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Text(
                            item.timeLabel,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Icon(
                            item.condition.icon,
                            size: 18,
                            color: AppColors.primaryOrange,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${item.tempCelsius}°C',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.darkText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.water_drop, size: 10, color: Colors.blue),
                              Text(
                                '${item.rainChancePercent}%',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Last Updated Timestamp
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                weather.updatedTimeAgo,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}