import "package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart";
import "package:flutter/material.dart";
import "../theme.dart";
import "dashboard_screen.dart";
import "scan_food_screen.dart";
import "my_custom_foods_screen.dart";
import "profile_screen.dart";

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    DashboardScreen(),
    ScanFoodScreen(),
    MyCustomFoodsScreen(),
    ProfileScreen(),
  ];

  static const _icons = [
    Icons.home_outlined,
    Icons.camera_alt_outlined,
    Icons.restaurant_menu_outlined,
    Icons.person_outline,
  ];
  static const _activeIcons = [Icons.home, Icons.camera_alt, Icons.restaurant_menu, Icons.person];
  static const _labels = ["Home", "Scan", "Foods", "Profile"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: AnimatedBottomNavigationBar.builder(
        itemCount: _labels.length,
        activeIndex: _index,
        gapLocation: GapLocation.none,
        notchSmoothness: NotchSmoothness.softEdge,
        leftCornerRadius: 24,
        rightCornerRadius: 24,
        backgroundColor: AppColors.surface,
        splashColor: AppColors.accent.withValues(alpha: 0.25),
        onTap: (index) => setState(() => _index = index),
        tabBuilder: (index, isActive) {
          final color = isActive ? AppColors.accent : AppColors.textSecondary;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isActive ? _activeIcons[index] : _icons[index], size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                _labels[index],
                style: TextStyle(fontSize: 11, color: color, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
              ),
            ],
          );
        },
      ),
    );
  }
}
