import "package:flutter/material.dart";
import "../theme.dart";
import "../widgets/progress_track.dart";

/// "Is this working?" card: average intake over the last week's logged days
/// vs maintenance TDEE, converted to a projected weekly weight change
/// (7700 kcal ≈ 1 kg) and compared against the user's weekly pace goal.
class DeficitPaceCard extends StatelessWidget {
  final List<Map<String, dynamic>> rangeDays;
  final double? maintenanceTdee;
  final String? goalType;
  final double weeklyLossGoalKg;

  const DeficitPaceCard({
    super.key,
    required this.rangeDays,
    required this.maintenanceTdee,
    required this.goalType,
    required this.weeklyLossGoalKg,
  });

  @override
  Widget build(BuildContext context) {
    final maintenance = maintenanceTdee;
    if (maintenance == null) return const SizedBox.shrink();

    final logged = rangeDays.where((d) => (d["calories"] as num) > 0).toList();

    Widget body;
    if (logged.length < 2) {
      body = const Text(
        "Log a couple of days of meals to see your weekly pace.",
        style: TextStyle(color: AppColors.textSecondary),
      );
    } else {
      final avgIntake =
          logged.fold<double>(0, (sum, d) => sum + (d["calories"] as num)) / logged.length;
      // Positive = eating below maintenance (losing), negative = surplus.
      final dailyDiff = maintenance - avgIntake;
      final weeklyKg = dailyDiff * 7 / 7700;
      final losing = weeklyKg >= 0;

      final headline =
          "≈${weeklyKg.abs().toStringAsFixed(2)} kg/week ${losing ? "loss" : "gain"} pace";
      final subtitle =
          "avg ${avgIntake.round()} kcal over ${logged.length} logged days · "
          "${dailyDiff.abs().round()} kcal/day ${losing ? "below" : "above"} maintenance";

      // Fraction of the weekly pace goal actually achieved (LOSE and GAIN
      // goals only — MAINTAIN has no pace to compare against).
      double? goalFraction;
      if (goalType == "LOSE" && weeklyLossGoalKg > 0) {
        goalFraction = (weeklyKg / weeklyLossGoalKg).clamp(0.0, 1.0);
      } else if (goalType == "GAIN" && weeklyLossGoalKg > 0) {
        goalFraction = (-weeklyKg / weeklyLossGoalKg).clamp(0.0, 1.0);
      }

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                losing ? Icons.trending_down : Icons.trending_up,
                color: AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          if (goalFraction != null) ...[
            const SizedBox(height: 14),
            ProgressTrack(fraction: goalFraction),
            const SizedBox(height: 6),
            Text(
              "Goal: ${weeklyLossGoalKg.toStringAsFixed(2)} kg/week ${goalType == "GAIN" ? "gain" : "loss"}",
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Weekly pace", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}
