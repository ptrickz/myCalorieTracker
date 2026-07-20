import "package:flutter/material.dart";
import "package:my_calorie/widgets/background_image_body.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../widgets/app_logo.dart";
import "../widgets/nutrient_hero_card.dart";
import "../widgets/macro_stat_card.dart";
import "../theme.dart";
import "welcome_screen.dart";
import "profile_screen.dart";

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

      setState(() {
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

  Future<void> _openProfile() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    _loadDashboard();
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
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: AppLogo(radius: 18),
        ),
        actions: [
          IconButton(
            onPressed: _openProfile,
            icon: const Icon(Icons.person),
            tooltip: "Profile",
          ),
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
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: BackgroundImageBody(
                imagePath: "assets/img/home.png",
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
                    Row(
                      children: [
                        Expanded(
                          child: MacroStatCard(
                            label: "Carbs",
                            grams: _totals["carbs"] as num,
                            dotColor: AppColors.carbsDot,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MacroStatCard(
                            label: "Fat",
                            grams: _totals["fat"] as num,
                            dotColor: AppColors.fatDot,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
