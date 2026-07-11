import "package:flutter/material.dart";
import "../theme.dart";

class AppLogo extends StatelessWidget {
  final double radius;

  const AppLogo({super.key, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent,
      child: Text(
        "MCT",
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.55,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
