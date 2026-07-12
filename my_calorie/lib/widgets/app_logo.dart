import "package:flutter/material.dart";

class AppLogo extends StatelessWidget {
  final double radius;

  const AppLogo({super.key, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      "assets/img/logo.png",
      width: radius * 1.5,
      height: radius * 1.5,
    );
  }
}
