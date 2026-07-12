import "package:flutter/material.dart";
import "../theme.dart";
import "progress_track.dart";

class NutrientHeroCard extends StatelessWidget {
  final IconData icon;
  final double consumed;
  final double target;
  final String Function(double remaining) titleBuilder;
  final String Function(double consumed, double target) subtitleBuilder;

  const NutrientHeroCard({
    super.key,
    required this.icon,
    required this.consumed,
    required this.target,
    required this.titleBuilder,
    required this.subtitleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = target - consumed;
    final fraction = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 30),
            const SizedBox(height: 8),
            Text(
              titleBuilder(remaining),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitleBuilder(consumed, target),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ProgressTrack(fraction: fraction),
          ],
        ),
      ),
    );
  }
}
