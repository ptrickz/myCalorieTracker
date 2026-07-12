import "package:flutter/material.dart";
import "screens/root_screen.dart";
import "theme.dart";

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "MyCalorie",
      theme: buildAppTheme(),
      home: const RootScreen(),
      // Mobile is the primary target (this app is meant to be used as an
      // installed PWA on a phone). On wider viewports (desktop browsers),
      // cap content to a phone-like width instead of stretching full-bleed,
      // and apply SafeArea globally so every screen respects notch/home
      // indicator insets without each one needing to remember to add it.
      builder: (context, child) => ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
