import "package:flutter/material.dart";
import "../theme.dart";

/// Horizontal progress bar with a thumb circle at the fill edge, matching the
/// reference dashboard design. Used by both the calorie and protein hero cards.
class ProgressTrack extends StatelessWidget {
  final double fraction;

  const ProgressTrack({super.key, required this.fraction});

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
