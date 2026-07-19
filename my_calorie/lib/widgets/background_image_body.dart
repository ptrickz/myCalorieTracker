import "package:flutter/material.dart";
import "../theme.dart";

/// Shared full-bleed background photo + dark scrim used behind screen
/// bodies. The scrim fades to the scaffold background at the bottom so
/// content and the nav bar stay legible over busy photos.
class BackgroundImageBody extends StatelessWidget {
  final String imagePath;
  final Widget child;

  const BackgroundImageBody({super.key, required this.imagePath, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(imagePath, fit: BoxFit.cover),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.75),
                AppColors.background,
              ],
              stops: const [0, 0.6, 1],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
