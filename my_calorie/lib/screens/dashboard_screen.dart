import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../widgets/weight_trend_card.dart";
import "../widgets/app_toast.dart";
import "../widgets/nutrient_hero_card.dart";
import "../widgets/macro_stat_card.dart";
import "../widgets/streak_card.dart";
import "../theme.dart";
import "../constants.dart";
import "welcome_screen.dart";
import "add_food_screen.dart";
import "my_custom_foods_screen.dart";

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  bool _isLoading = true;
  bool _isLoadingDay = false;
  String? _errorMessage;
  double _targetCalories = 0;
  double _proteinTargetG = 0;
  Map<String, dynamic> _totals = const {"calories": 0, "protein": 0, "carbs": 0, "fat": 0};
  Map<String, dynamic> _dayTotals = const {"calories": 0, "protein": 0, "carbs": 0, "fat": 0};
  List<Map<String, dynamic>> _entries = const [];
  List<Map<String, dynamic>> _weightLogs = const [];
  double? _goalWeightKg;
  double? _milestoneWeightKg;
  int _currentStreak = 0;
  int _longestStreak = 0;
  bool _loggedToday = false;
  DateTime _viewedDate = DateTime.now();

  bool get _isViewingToday => _dateKey(_viewedDate) == _dateKey(DateTime.now());

  String _dateKey(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  String _dateLabel(DateTime date) {
    if (_isViewingToday) return "Today's log";
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    if (_dateKey(date) == _dateKey(yesterday)) return "Yesterday's log";
    return "Log for ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

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
      final weightLogs = await _apiService.getWeightLogs(token);
      final streak = await _apiService.getStreak(token);

      setState(() {
        _targetCalories = (profile["tdee"]?["targetCalories"] as num?)?.toDouble() ?? 0;
        _proteinTargetG = (profile["proteinTargetG"] as num?)?.toDouble() ?? 0;
        _totals = logs["totals"] as Map<String, dynamic>;
        _weightLogs = weightLogs;
        _goalWeightKg = (profile["goalWeightKg"] as num?)?.toDouble();
        _milestoneWeightKg = (profile["milestoneWeightKg"] as num?)?.toDouble();
        _currentStreak = streak["currentStreak"] as int;
        _longestStreak = streak["longestStreak"] as int;
        _loggedToday = streak["loggedToday"] as bool;
        _viewedDate = DateTime.now();
        _dayTotals = logs["totals"] as Map<String, dynamic>;
        _entries = (logs["entries"] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDayLogs(DateTime date) async {
    setState(() {
      _viewedDate = date;
      _isLoadingDay = true;
    });

    try {
      final token = await _authStorage.readToken();
      final logs = await _apiService.getLogs(token!, date: _dateKey(date));
      if (!mounted) return;
      setState(() {
        _dayTotals = logs["totals"] as Map<String, dynamic>;
        _entries = (logs["entries"] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingDay = false);
    }
  }

  void _goToPreviousDay() => _loadDayLogs(_viewedDate.subtract(const Duration(days: 1)));

  void _goToNextDay() {
    if (_isViewingToday) return;
    _loadDayLogs(_viewedDate.add(const Duration(days: 1)));
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

  Future<void> _openAddFood() async {
    final logged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddFoodScreen()),
    );
    if (logged == true) _loadDashboard();
  }

  Future<void> _openMyCustomFoods() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyCustomFoodsScreen()),
    );
    _loadDashboard();
  }

  Future<void> _openLogWeightDialog() async {
    final controller = TextEditingController();
    final weightKg = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log today's weight"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: "Weight (kg)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.of(context).pop(double.tryParse(controller.text)),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (weightKg == null) return;

    try {
      final token = await _authStorage.readToken();
      await _apiService.addWeightLog(token!, weightKg);
      _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  Future<void> _openEditGoalsDialog() async {
    final goalController = TextEditingController(text: _goalWeightKg?.toString() ?? "");
    final milestoneController = TextEditingController(text: _milestoneWeightKg?.toString() ?? "");
    final proteinController = TextEditingController(
      text: _proteinTargetG > 0 ? _proteinTargetG.round().toString() : "",
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit goals"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: goalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Goal weight (kg)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: milestoneController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Milestone weight (kg)"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: proteinController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Protein target (g)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Save")),
        ],
      ),
    );

    if (saved != true) return;

    try {
      final token = await _authStorage.readToken();
      await _apiService.updateGoals(
        token!,
        goalWeightKg: double.tryParse(goalController.text),
        milestoneWeightKg: double.tryParse(milestoneController.text),
        proteinTargetG: double.tryParse(proteinController.text),
      );
      _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  Future<void> _openEditLogEntryDialog(Map<String, dynamic> entry) async {
    final servingController = TextEditingController(
      text: (entry["servingGrams"] as num).round().toString(),
    );
    var mealType = entry["mealType"] as String;

    // Returns "save", "delete", or null (cancel/dismiss).
    final action = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(entry["foodItem"]["name"] as String),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: servingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Serving size (grams)"),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: mealType,
                decoration: const InputDecoration(labelText: "Meal"),
                items: mealTypeLabels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (value) => setDialogState(() => mealType = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop("delete"),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text("Delete"),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.of(context).pop("save"), child: const Text("Save")),
          ],
        ),
      ),
    );

    if (action == null) return;

    try {
      final token = await _authStorage.readToken();
      if (action == "delete") {
        await _apiService.deleteLogEntry(token!, entry["id"] as String);
      } else {
        final servingGrams = double.tryParse(servingController.text);
        if (servingGrams == null || servingGrams <= 0) {
          if (!mounted) return;
          AppToast.show(context, "Enter a valid serving size");
          return;
        }
        await _apiService.updateLogEntry(
          token!,
          entry["id"] as String,
          servingGrams: servingGrams,
          mealType: mealType,
        );
      }
      if (_isViewingToday) {
        _loadDashboard();
      } else {
        _loadDayLogs(_viewedDate);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final consumed = (_totals["calories"] as num).toDouble();
    final proteinConsumed = (_totals["protein"] as num).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text("MyCalorie"),
        actions: [
          IconButton(
            onPressed: _openMyCustomFoods,
            icon: const Icon(Icons.restaurant_menu),
            tooltip: "My Custom Foods",
          ),
          IconButton(onPressed: _handleLogout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      StreakCard(
                        currentStreak: _currentStreak,
                        longestStreak: _longestStreak,
                        loggedToday: _loggedToday,
                      ),
                      const SizedBox(height: 16),
                      NutrientHeroCard(
                        icon: Icons.local_fire_department,
                        consumed: consumed,
                        target: _targetCalories,
                        titleBuilder: (remaining) => "${remaining.round()} kcal",
                        subtitleBuilder: (c, t) => "${c.round()} eaten of ${t.round()} kcal goal",
                        useRingProgress: true,
                      ),
                      const SizedBox(height: 16),
                      NutrientHeroCard(
                        icon: Icons.fitness_center,
                        consumed: proteinConsumed,
                        target: _proteinTargetG,
                        titleBuilder: (remaining) => "${remaining.round()}g protein left",
                        subtitleBuilder: (c, t) => "${c.round()}g eaten of ${t.round()}g goal",
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
                      const SizedBox(height: 24),
                      WeightTrendCard(
                        weightLogs: _weightLogs,
                        goalWeightKg: _goalWeightKg,
                        milestoneWeightKg: _milestoneWeightKg,
                        onEditGoals: _openEditGoalsDialog,
                        onLogWeight: _openLogWeightDialog,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: _isLoadingDay ? null : _goToPreviousDay,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  _dateLabel(_viewedDate),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  "${(_dayTotals["calories"] as num).round()} kcal · ${(_dayTotals["protein"] as num).round()}g protein",
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _isLoadingDay || _isViewingToday ? null : _goToNextDay,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingDay)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(_isViewingToday ? "Nothing logged yet today." : "Nothing logged this day."),
                        )
                      else
                        ..._entries.map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(entry["foodItem"]["name"] as String),
                            subtitle: Text("${entry["mealType"]} · ${(entry["servingGrams"] as num).round()}g"),
                            trailing: Text("${(entry["calories"] as num).round()} kcal"),
                            onTap: () => _openEditLogEntryDialog(entry),
                          ),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddFood,
        child: const Icon(Icons.add),
      ),
    );
  }
}
