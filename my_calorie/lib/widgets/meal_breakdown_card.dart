import "package:flutter/material.dart";
import "../constants.dart";
import "../theme.dart";

const _mealColors = {
  "BREAKFAST": AppColors.accent,
  "LUNCH": AppColors.carbsDot,
  "DINNER": AppColors.fatDot,
  "SNACK": Color(0xFFBA68C8),
};

/// Single stacked bar of today's calories by meal, with a per-meal legend.
class MealBreakdownCard extends StatelessWidget {
  final List<Map<String, dynamic>> entries;

  const MealBreakdownCard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final byMeal = <String, double>{};
    for (final entry in entries) {
      final meal = entry["mealType"] as String;
      byMeal[meal] = (byMeal[meal] ?? 0) + (entry["calories"] as num).toDouble();
    }
    // Keep the canonical meal order rather than insertion order.
    final meals = mealTypeLabels.keys.where((m) => (byMeal[m] ?? 0) > 0).toList();
    final total = byMeal.values.fold<double>(0, (sum, v) => sum + v);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's meals", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            if (meals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  "Nothing logged yet today.",
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Row(
                  children: [
                    for (final meal in meals)
                      Expanded(
                        flex: (byMeal[meal]!).round().clamp(1, 1 << 30),
                        child: Container(
                          height: 14,
                          color: _mealColors[meal] ?? AppColors.textSecondary,
                          margin: EdgeInsets.only(right: meal == meals.last ? 0 : 2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final meal in meals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _mealColors[meal] ?? AppColors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mealTypeLabels[meal] ?? meal,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                      Text(
                        "${byMeal[meal]!.round()} kcal",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 38,
                        child: Text(
                          "${(byMeal[meal]! / total * 100).round()}%",
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
