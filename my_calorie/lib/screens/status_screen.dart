import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../widgets/app_toast.dart";
import "../widgets/seven_day_trend_card.dart";
import "../widgets/streak_card.dart";
import "../widgets/weight_trend_card.dart";

/// Trends-over-time analytics: streak, weight trend, and 7-day intake —
/// the Dashboard stays focused on today's logging.
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _weightLogs = const [];
  double? _goalWeightKg;
  double? _milestoneWeightKg;
  double _proteinTargetG = 0;
  bool _useCustomCalorieTargets = false;
  double _weekdayTargetCalories = 0;
  double _weekendTargetCalories = 0;
  int _currentStreak = 0;
  int _longestStreak = 0;
  bool _loggedToday = false;
  List<Map<String, dynamic>> _rangeDays = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      final profile = await _apiService.getProfile(token!);
      final weightLogs = await _apiService.getWeightLogs(token);
      final streak = await _apiService.getStreak(token);
      final range = await _apiService.getLogsRange(token);

      if (!mounted) return;
      setState(() {
        _weightLogs = weightLogs;
        _goalWeightKg = (profile["goalWeightKg"] as num?)?.toDouble();
        _milestoneWeightKg = (profile["milestoneWeightKg"] as num?)?.toDouble();
        _proteinTargetG = (profile["proteinTargetG"] as num?)?.toDouble() ?? 0;
        _useCustomCalorieTargets = profile["useCustomCalorieTargets"] as bool? ?? false;
        _weekdayTargetCalories = (profile["weekdayTargetCalories"] as num?)?.toDouble() ?? 0;
        _weekendTargetCalories = (profile["weekendTargetCalories"] as num?)?.toDouble() ?? 0;
        _currentStreak = streak["currentStreak"] as int;
        _longestStreak = streak["longestStreak"] as int;
        _loggedToday = streak["loggedToday"] as bool;
        _rangeDays = (range["days"] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  Future<void> _openEditGoalsDialog() async {
    final goalController = TextEditingController(text: _goalWeightKg?.toString() ?? "");
    final milestoneController = TextEditingController(text: _milestoneWeightKg?.toString() ?? "");
    final proteinController =
        TextEditingController(text: _proteinTargetG > 0 ? _proteinTargetG.round().toString() : "");
    final weekdayController = TextEditingController(
      text: _weekdayTargetCalories > 0 ? _weekdayTargetCalories.round().toString() : "",
    );
    final weekendController = TextEditingController(
      text: _weekendTargetCalories > 0 ? _weekendTargetCalories.round().toString() : "",
    );
    var useCustomTargets = _useCustomCalorieTargets;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit goals"),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: useCustomTargets,
                      onChanged: (value) => setDialogState(() => useCustomTargets = value ?? false),
                    ),
                    const Expanded(child: Text("Custom weekday/weekend targets")),
                  ],
                ),
                if (useCustomTargets) ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: weekdayController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Weekday calorie target"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: weekendController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Weekend calorie target"),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Save")),
          ],
        ),
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
        useCustomCalorieTargets: useCustomTargets,
        weekdayTargetCalories: useCustomTargets ? double.tryParse(weekdayController.text) : null,
        weekendTargetCalories: useCustomTargets ? double.tryParse(weekendController.text) : null,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Status")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      StreakCard(
                        currentStreak: _currentStreak,
                        longestStreak: _longestStreak,
                        loggedToday: _loggedToday,
                      ),
                      const SizedBox(height: 16),
                      SevenDayTrendCard(days: _rangeDays),
                      const SizedBox(height: 16),
                      WeightTrendCard(
                        weightLogs: _weightLogs,
                        goalWeightKg: _goalWeightKg,
                        milestoneWeightKg: _milestoneWeightKg,
                        onEditGoals: _openEditGoalsDialog,
                        onLogWeight: _openLogWeightDialog,
                      ),
                    ],
                  ),
                ),
    );
  }
}
