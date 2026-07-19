import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "../theme.dart";

/// Bar charts of daily calories and protein for the last N days, fed by
/// GET /logs/range. Purely presentational, mirroring WeightTrendCard's style.
class SevenDayTrendCard extends StatelessWidget {
  final List<Map<String, dynamic>> days;

  const SevenDayTrendCard({super.key, required this.days});

  bool get _hasData => days.any((d) => (d["calories"] as num) > 0 || (d["protein"] as num) > 0);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Last 7 days", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            if (!_hasData)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text("Log some food to see your weekly trend."),
              )
            else ...[
              _buildAverages(),
              const SizedBox(height: 16),
              _buildSection("Calories", "calories", AppColors.accent, 120),
              const SizedBox(height: 16),
              _buildSection("Protein (g)", "protein", AppColors.carbsDot, 80),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAverages() {
    // Average over days that actually have logs, so an empty day doesn't
    // drag the number down misleadingly.
    final loggedDays = days.where((d) => (d["calories"] as num) > 0).toList();
    if (loggedDays.isEmpty) return const SizedBox.shrink();
    final avgCalories =
        loggedDays.fold<double>(0, (sum, d) => sum + (d["calories"] as num)) / loggedDays.length;
    final avgProtein =
        loggedDays.fold<double>(0, (sum, d) => sum + (d["protein"] as num)) / loggedDays.length;

    return Text(
      "avg ${avgCalories.round()} kcal · ${avgProtein.round()}g protein per logged day",
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
    );
  }

  Widget _buildSection(String label, String field, Color color, double height) {
    final maxValue = days.fold<double>(0, (max, d) {
      final v = (d[field] as num).toDouble();
      return v > max ? v : max;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: maxValue == 0 ? 1 : maxValue * 1.15,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= days.length) return const SizedBox.shrink();
                      final date = DateTime.parse(days[index]["date"] as String);
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text("${date.day}", style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: (days[i][field] as num).toDouble(),
                        color: color,
                        width: 14,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
