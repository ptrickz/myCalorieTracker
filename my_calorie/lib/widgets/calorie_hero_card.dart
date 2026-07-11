import "package:flutter/material.dart";
import "../theme.dart";

class CalorieHeroCard extends StatelessWidget {
  final double consumed;
  final double target;

  const CalorieHeroCard({super.key, required this.consumed, required this.target});

  @override
  Widget build(BuildContext context) {
    final remaining = target - consumed;
    final fraction = target <= 0 ? 0.0 : (consumed / target).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          children: [
            const Icon(Icons.local_fire_department, color: AppColors.accent, size: 30),
            const SizedBox(height: 8),
            Text(
              "${remaining.round()} kcal",
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "${consumed.round()} eaten of ${target.round()} kcal goal",
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            _ProgressTrack(fraction: fraction),
          ],
        ),
      ),
    );
  }
}

class _ProgressTrack extends StatelessWidget {
  final double fraction;

  const _ProgressTrack({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbRadius = 10.0;
        final width = constraints.maxWidth;
        final thumbCenter = (width * fraction).clamp(thumbRadius, width - thumbRadius);

        return SizedBox(
          height: thumbRadius * 2,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
              ),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              Positioned(
                left: thumbCenter - thumbRadius,
                child: Container(
                  width: thumbRadius * 2,
                  height: thumbRadius * 2,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
