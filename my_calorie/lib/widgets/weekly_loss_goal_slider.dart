import "package:flutter/material.dart";
import "../theme.dart";

/// Weekly weight-change pace picker (0.25-1.0 kg/week in 0.25 steps) with a
/// live preview of the resulting daily calorie target and a soft warning for
/// aggressive paces.
class WeeklyLossGoalSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  /// Estimated daily target for the current slider value, or null when the
  /// other profile inputs aren't complete enough to estimate.
  final double? previewTargetCalories;

  /// "loss" for LOSE, "gain" for GAIN — only affects labels.
  final bool isGain;

  const WeeklyLossGoalSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.previewTargetCalories,
    this.isGain = false,
  });

  @override
  Widget build(BuildContext context) {
    final direction = isGain ? "gain" : "loss";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text("Weekly $direction goal", style: const TextStyle(fontSize: 14)),
            ),
            Text(
              "${value.toStringAsFixed(2)} kg/week",
              style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0.25,
          max: 1.0,
          divisions: 3,
          label: "${value.toStringAsFixed(2)} kg/week",
          onChanged: (v) => onChanged((v * 4).round() / 4),
        ),
        Text(
          previewTargetCalories == null
              ? "Complete your profile to preview the daily target."
              : "Daily target: ~${previewTargetCalories!.round()} kcal",
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        if (value > 0.76)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB74D), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "That's an aggressive pace — up to 0.75 kg/week is easier to sustain and kinder on muscle${isGain ? "" : " retention"}.",
                    style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
