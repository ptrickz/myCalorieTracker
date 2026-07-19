import "package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart";
import "package:flutter/material.dart";
import "../theme.dart";
import "dashboard_screen.dart";
import "add_food_screen.dart";
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

  // Bumped whenever the user could have logged food elsewhere (the Add Food
  // tab or the Scan FAB), forcing Dashboard to remount and reload next time
  // it's shown instead of quietly going stale inside the IndexedStack.
  int _dashboardRefreshKey = 0;

  static const _icons = [
    Icons.home_outlined,
    Icons.add_circle_outline,
    Icons.restaurant_menu_outlined,
    Icons.person_outline,
  ];
  static const _activeIcons = [Icons.home, Icons.add_circle, Icons.restaurant_menu, Icons.person];
  static const _labels = ["Home", "Add Food", "Foods", "Profile"];

  void _onDestinationSelected(int index) {
    setState(() {
      if (index == 0 && _index != 0) _dashboardRefreshKey++;
      _index = index;
    });
  }

  Future<void> _openScan() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanFoodScreen()));
    if (!mounted) return;
    setState(() => _dashboardRefreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(key: ValueKey(_dashboardRefreshKey)),
      const AddFoodScreen(),
      const MyCustomFoodsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      floatingActionButton: FloatingActionButton(
        onPressed: _openScan,
        child: const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, -6)),
            BoxShadow(color: AppColors.accent.withValues(alpha: 0.06), blurRadius: 40, offset: const Offset(0, -10)),
          ],
        ),
        child: AnimatedBottomNavigationBar.builder(
          itemCount: _labels.length,
          activeIndex: _index,
          gapLocation: GapLocation.center,
          notchSmoothness: NotchSmoothness.softEdge,
          leftCornerRadius: 24,
          rightCornerRadius: 24,
          height: 78,
          elevation: 0,
          backgroundColor: AppColors.surface,
          splashColor: AppColors.accent.withValues(alpha: 0.25),
          onTap: _onDestinationSelected,
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
      ),
    );
  }
}
