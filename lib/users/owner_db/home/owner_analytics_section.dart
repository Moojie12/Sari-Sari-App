import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum _AnalyticsType { descriptive, predictive, prescriptive }

extension on _AnalyticsType {
  String get label {
    switch (this) {
      case _AnalyticsType.descriptive:
        return 'Descriptive';
      case _AnalyticsType.predictive:
        return 'Predictive';
      case _AnalyticsType.prescriptive:
        return 'Prescriptive';
    }
  }
}

class _AnalyticsInsight {
  const _AnalyticsInsight({required this.title, required this.detail, required this.icon, required this.color});
  final String title;
  final String detail;
  final IconData icon;
  final Color color;
}

/// Owner Home's analytics module.
///
/// Groups insights into three tiers:
///  - Descriptive  — what already happened (sales / inventory history)
///  - Predictive   — what's likely to happen next (forecasts)
///  - Prescriptive — what to actually do about it (recommended actions)
///
/// All insight data below is a placeholder.
/// TODO(backend): replace [_insightsFor] with real computed values once
/// analytics is wired to the backend — the widget shape and the three
/// tiers stay the same either way.
class OwnerAnalyticsSection extends StatefulWidget {
  const OwnerAnalyticsSection({super.key});

  @override
  State<OwnerAnalyticsSection> createState() => _OwnerAnalyticsSectionState();
}

class _OwnerAnalyticsSectionState extends State<OwnerAnalyticsSection> {
  _AnalyticsType _selected = _AnalyticsType.descriptive;

  List<_AnalyticsInsight> _insightsFor(_AnalyticsType type) {
    switch (type) {
      case _AnalyticsType.descriptive:
        return const [
          _AnalyticsInsight(
            title: 'Best Seller This Week',
            detail: 'Coke 1.5L — 86 units sold',
            icon: Icons.emoji_events_outlined,
            color: Colors.blue,
          ),
          _AnalyticsInsight(
            title: 'Peak Sales Hour',
            detail: '5:00–7:00 PM, averaging ₱2,140/hr',
            icon: Icons.schedule,
            color: Colors.indigo,
          ),
        ];
      case _AnalyticsType.predictive:
        return const [
          _AnalyticsInsight(
            title: 'Demand Forecast',
            detail: 'Instant noodles demand up ~18% next week',
            icon: Icons.trending_up,
            color: Colors.teal,
          ),
          _AnalyticsInsight(
            title: 'Stock-Out Risk',
            detail: 'Bottled water likely to run out in 3 days',
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
          ),
        ];
      case _AnalyticsType.prescriptive:
        return const [
          _AnalyticsInsight(
            title: 'Recommended Restock',
            detail: 'Reorder 5 cases of Coke 1.5L before Friday',
            icon: Icons.local_shipping_outlined,
            color: Colors.green,
          ),
          _AnalyticsInsight(
            title: 'Weather-Based Tip',
            detail: 'Rain forecast — prioritize instant meals & umbrellas over cold drinks',
            icon: Icons.tips_and_updates_outlined,
            color: Colors.deepPurple,
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final insights = _insightsFor(_selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Analytics',
            style: TextStyle(color: AppColors.darkText, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: _AnalyticsType.values.map((type) {
            final isSelected = type == _selected;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(type.label),
                selected: isSelected,
                onSelected: (_) => setState(() => _selected = type),
                selectedColor: AppColors.primaryOrange,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.darkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: isSelected ? AppColors.primaryOrange : AppColors.borderColor),
                ),
                showCheckmark: false,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: insight.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(insight.icon, color: insight.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(insight.title,
                          style: const TextStyle(
                              color: AppColors.darkText, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(insight.detail,
                          style: TextStyle(
                              color: AppColors.secondaryText.withValues(alpha: 0.85), fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}