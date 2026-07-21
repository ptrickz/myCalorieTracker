import "package:flutter/material.dart";
import "package:my_calorie/widgets/background_image_body.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../widgets/app_logo.dart";
import "../widgets/deficit_pace_card.dart";
import "../widgets/hiding_app_bar.dart";
import "../widgets/macro_split_donut.dart";
import "../widgets/meal_breakdown_card.dart";
import "../widgets/nutrient_hero_card.dart";
import "welcome_screen.dart";

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with AppBarVisibilityMixin {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  bool _isLoading = true;
  String? _errorMessage;
  double _targetCalories = 0;
  double _proteinTargetG = 0;
  double _weekdayTargetCalories = 0;
  double _weekendTargetCalories = 0;
  Map<String, dynamic> _totals = const {
    "calories": 0,
    "protein": 0,
    "carbs": 0,
    "fat": 0,
  };
  List<Map<String, dynamic>> _entries = const [];
  List<Map<String, dynamic>> _rangeDays = const [];
  double? _maintenanceTdee;
  String? _goalType;
  double _weeklyLossGoalKg = 0.5;

  bool get _isWeekendToday =>
      DateTime.now().weekday == DateTime.saturday ||
      DateTime.now().weekday == DateTime.sunday;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      if (token == null) {
        _goToWelcome();
        return;
      }

      final profile = await _apiService.getProfile(token);
      final logs = await _apiService.getLogs(token);
      final range = await _apiService.getLogsRange(token);

      setState(() {
        _entries = (logs["entries"] as List).cast<Map<String, dynamic>>();
        _rangeDays = (range["days"] as List).cast<Map<String, dynamic>>();
        _maintenanceTdee =
            ((profile["tdee"] as Map<String, dynamic>?)?["maintenanceTdee"] as num?)?.toDouble();
        _goalType = profile["goalType"] as String?;
        _weeklyLossGoalKg = (profile["weeklyLossGoalKg"] as num?)?.toDouble() ?? 0.5;
        _proteinTargetG = (profile["proteinTargetG"] as num?)?.toDouble() ?? 0;
        _weekdayTargetCalories =
            (profile["weekdayTargetCalories"] as num?)?.toDouble() ?? 0;
        _weekendTargetCalories =
            (profile["weekendTargetCalories"] as num?)?.toDouble() ?? 0;
        _targetCalories = _isWeekendToday
            ? _weekendTargetCalories
            : _weekdayTargetCalories;
        _totals = logs["totals"] as Map<String, dynamic>;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    await _authStorage.clearToken();
    _goToWelcome();
  }

  void _goToWelcome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final consumed = (_totals["calories"] as num).toDouble();
    final proteinConsumed = (_totals["protein"] as num).toDouble();

    return Scaffold(
      // Body extends behind the transparent app bar so the background photo
      // runs edge-to-edge; the list adds top padding to clear it.
      extendBodyBehindAppBar: true,
      appBar: HidingAppBar(
        visible: appBarVisible,
        title: const Text("Home"),
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: AppLogo(radius: 18),
        ),
        actions: [
          IconButton(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : NotificationListener<UserScrollNotification>(
              onNotification: handleScrollNotification,
              child: RefreshIndicator(
              onRefresh: _loadDashboard,
              child: BackgroundImageBody(
                imagePath: "assets/img/analytics.png",
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      24, MediaQuery.of(context).padding.top + kToolbarHeight + 8, 24, 24),
                  children: [
                    NutrientHeroCard(
                      icon: Icons.local_fire_department,
                      consumed: consumed,
                      target: _targetCalories,
                      titleBuilder: (remaining) => "${remaining.round()} kcal",
                      subtitleBuilder: (c, t) =>
                          "${c.round()} eaten of ${t.round()} kcal goal",
                      useRingProgress: true,
                    ),
                    const SizedBox(height: 16),
                    NutrientHeroCard(
                      icon: Icons.fitness_center,
                      consumed: proteinConsumed,
                      target: _proteinTargetG,
                      titleBuilder: (remaining) =>
                          "${remaining.round()}g protein left",
                      subtitleBuilder: (c, t) =>
                          "${c.round()}g eaten of ${t.round()}g goal",
                    ),
                    const SizedBox(height: 16),
                    MacroSplitDonut(
                      proteinG: (_totals["protein"] as num).toDouble(),
                      carbsG: (_totals["carbs"] as num).toDouble(),
                      fatG: (_totals["fat"] as num).toDouble(),
                    ),
                    const SizedBox(height: 16),
                    MealBreakdownCard(entries: _entries),
                    const SizedBox(height: 16),
                    DeficitPaceCard(
                      rangeDays: _rangeDays,
                      maintenanceTdee: _maintenanceTdee,
                      goalType: _goalType,
                      weeklyLossGoalKg: _weeklyLossGoalKg,
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
