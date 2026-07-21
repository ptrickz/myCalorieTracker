import "package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart";
import "package:flutter/material.dart";
import "../theme.dart";
import "dashboard_screen.dart";
import "create_food_screen.dart";
import "food_hub_screen.dart";
import "profile_screen.dart";
import "scan_food_screen.dart";
import "workout_screen.dart";

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Bumped whenever the user could have logged food elsewhere (the Food tab
  // or the Scan FAB), forcing Dashboard to remount and reload next time
  // it's shown instead of quietly going stale inside the IndexedStack.
  int _dashboardRefreshKey = 0;

  final _foodHubKey = GlobalKey<FoodHubScreenState>();
  final _workoutKey = GlobalKey<WorkoutScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();
  final _foodHubTab = ValueNotifier<FoodHubTab>(FoodHubTab.logFood);

  static const _icons = [
    Icons.home_outlined,
    Icons.restaurant_menu_outlined,
    Icons.directions_bike_outlined,
    Icons.person_outline,
  ];
  static const _activeIcons = [
    Icons.home,
    Icons.restaurant_menu,
    Icons.directions_bike,
    Icons.person,
  ];
  static const _labels = ["Home", "Food", "Workout", "Profile"];

  @override
  void dispose() {
    _foodHubTab.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    setState(() {
      if (index == 0 && _index != 0) _dashboardRefreshKey++;
      _index = index;
    });
  }

  Future<void> _openScan() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ScanFoodScreen()));
    if (!mounted) return;
    setState(() => _dashboardRefreshKey++);
  }

  Future<void> _openCreateFood() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateFoodScreen()));
    if (!mounted) return;
    _foodHubKey.currentState?.refreshAfterCreate();
  }

  Widget? _buildFab() {
    switch (_index) {
      case 0:
        return FloatingActionButton(
          onPressed: _openScan,
          child: const Icon(Icons.camera_alt),
        );
      case 1:
        return ValueListenableBuilder<FoodHubTab>(
          valueListenable: _foodHubTab,
          builder: (context, tab, _) => tab == FoodHubTab.logFood
              ? FloatingActionButton(
                  onPressed: _openScan,
                  child: const Icon(Icons.camera_alt),
                )
              : FloatingActionButton(
                  onPressed: _openCreateFood,
                  tooltip: "Add Custom Food",
                  child: const Icon(Icons.add),
                ),
        );
      case 2:
        return FloatingActionButton(
          onPressed: () => _workoutKey.currentState?.startFreeSession(),
          tooltip: "Add a session",
          child: const Icon(Icons.add),
        );
      case 3:
        return FloatingActionButton(
          onPressed: () => _profileKey.currentState?.openLogWeightDialog(),
          tooltip: "Log today's weight",
          child: const Icon(Icons.monitor_weight_outlined),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardScreen(key: ValueKey(_dashboardRefreshKey)),
      FoodHubScreen(
        key: _foodHubKey,
        onSubTabChanged: (tab) => _foodHubTab.value = tab,
      ),
      WorkoutScreen(key: _workoutKey),
      ProfileScreen(key: _profileKey),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.06),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
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
                Icon(
                  isActive ? _activeIcons[index] : _icons[index],
                  size: 24,
                  color: color,
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[index],
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
