import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";

class WeightTrendCard extends StatelessWidget {
  final List<Map<String, dynamic>> weightLogs;
  final double? goalWeightKg;
  final double? milestoneWeightKg;
  const WeightTrendCard({
    super.key,
    required this.weightLogs,
    required this.goalWeightKg,
    required this.milestoneWeightKg,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Weight trend", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (weightLogs.length < 2)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text("Log at least 2 weigh-ins to see a trend."),
              )
            else
              SizedBox(height: 220, child: _buildChart(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final recent = weightLogs.length > 28 ? weightLogs.sublist(weightLogs.length - 28) : weightLogs;

    final spots = [
      for (var i = 0; i < recent.length; i++) FlSpot(i.toDouble(), (recent[i]["weightKg"] as num).toDouble()),
    ];

    final referenceValues = [?goalWeightKg, ?milestoneWeightKg];
    final allValues = [...spots.map((s) => s.y), ...referenceValues];
    final minY = allValues.reduce((a, b) => a < b ? a : b) - 2;
    final maxY = allValues.reduce((a, b) => a > b ? a : b) + 2;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (recent.length / 4).clamp(1, double.infinity).roundToDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= recent.length) return const SizedBox.shrink();
                final date = DateTime.parse(recent[index]["recordedAt"] as String);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text("${date.month}/${date.day}", style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Theme.of(context).colorScheme.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (milestoneWeightKg != null)
              HorizontalLine(
                y: milestoneWeightKg!,
                color: Colors.orange,
                strokeWidth: 2,
                dashArray: const [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  style: const TextStyle(fontSize: 10, color: Colors.orange),
                  labelResolver: (line) => "Milestone ${line.y.toStringAsFixed(1)}kg",
                ),
              ),
            if (goalWeightKg != null)
              HorizontalLine(
                y: goalWeightKg!,
                color: Colors.green,
                strokeWidth: 2,
                dashArray: const [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.bottomRight,
                  style: const TextStyle(fontSize: 10, color: Colors.green),
                  labelResolver: (line) => "Goal ${line.y.toStringAsFixed(1)}kg",
                ),
              ),
          ],
        ),
      ),
    );
  }
}
