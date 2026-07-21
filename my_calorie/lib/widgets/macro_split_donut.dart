import "package:fl_chart/fl_chart.dart";
import "package:flutter/material.dart";
import "../theme.dart";

/// Donut of today's calories by macro (protein 4 kcal/g, carbs 4, fat 9),
/// with a legend showing grams and share per macro.
class MacroSplitDonut extends StatelessWidget {
  final double proteinG;
  final double carbsG;
  final double fatG;

  const MacroSplitDonut({
    super.key,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  @override
  Widget build(BuildContext context) {
    final proteinKcal = proteinG * 4;
    final carbsKcal = carbsG * 4;
    final fatKcal = fatG * 9;
    final totalKcal = proteinKcal + carbsKcal + fatKcal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Macro split", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (totalKcal <= 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  "Log some food to see today's macro split.",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 3,
                        centerSpaceRadius: 30,
                        startDegreeOffset: -90,
                        sections: [
                          PieChartSectionData(
                            value: proteinKcal,
                            color: AppColors.proteinDot,
                            radius: 22,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: carbsKcal,
                            color: AppColors.carbsDot,
                            radius: 22,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: fatKcal,
                            color: AppColors.fatDot,
                            radius: 22,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      children: [
                        _legendRow("Protein", AppColors.proteinDot, proteinG, proteinKcal / totalKcal),
                        const SizedBox(height: 10),
                        _legendRow("Carbs", AppColors.carbsDot, carbsG, carbsKcal / totalKcal),
                        const SizedBox(height: 10),
                        _legendRow("Fat", AppColors.fatDot, fatG, fatKcal / totalKcal),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _legendRow(String label, Color color, double grams, double share) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ),
        Text("${grams.round()}g", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        SizedBox(
          width: 38,
          child: Text(
            "${(share * 100).round()}%",
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
