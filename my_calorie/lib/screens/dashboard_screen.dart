import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../widgets/weight_trend_card.dart";
import "welcome_screen.dart";
import "add_food_screen.dart";

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
  Map<String, dynamic> _totals = const {"calories": 0, "protein": 0, "carbs": 0, "fat": 0};
  List<Map<String, dynamic>> _entries = const [];
  List<Map<String, dynamic>> _weightLogs = const [];
  double? _goalWeightKg;
  double? _milestoneWeightKg;

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
      final logs = await _apiService.getTodaysLogs(token);
      final weightLogs = await _apiService.getWeightLogs(token);

      setState(() {
        _targetCalories = (profile["tdee"]?["targetCalories"] as num?)?.toDouble() ?? 0;
        _totals = logs["totals"] as Map<String, dynamic>;
        _entries = (logs["entries"] as List).cast<Map<String, dynamic>>();
        _weightLogs = weightLogs;
        _goalWeightKg = (profile["goalWeightKg"] as num?)?.toDouble();
        _milestoneWeightKg = (profile["milestoneWeightKg"] as num?)?.toDouble();
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
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
  }

  Future<void> _openAddFood() async {
    final logged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddFoodScreen()),
    );
    if (logged == true) _loadDashboard();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _openEditGoalsDialog() async {
    final goalController = TextEditingController(text: _goalWeightKg?.toString() ?? "");
    final milestoneController = TextEditingController(text: _milestoneWeightKg?.toString() ?? "");

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit weight goals"),
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
      );
      _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final consumed = (_totals["calories"] as num).toDouble();
    final remaining = _targetCalories - consumed;

    return Scaffold(
      appBar: AppBar(
        title: const Text("MyCalorie"),
        actions: [IconButton(onPressed: _handleLogout, icon: const Icon(Icons.logout))],
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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text("Remaining today", style: Theme.of(context).textTheme.titleMedium),
                              Text(
                                "${remaining.round()} kcal",
                                style: Theme.of(context).textTheme.headlineMedium,
                              ),
                              const SizedBox(height: 8),
                              Text("${consumed.round()} eaten of ${_targetCalories.round()} kcal goal"),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _MacroStat(label: "Protein", grams: _totals["protein"] as num),
                          _MacroStat(label: "Carbs", grams: _totals["carbs"] as num),
                          _MacroStat(label: "Fat", grams: _totals["fat"] as num),
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
                      Text("Today's log", style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text("Nothing logged yet today."),
                        )
                      else
                        ..._entries.map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(entry["foodItem"]["name"] as String),
                            subtitle: Text("${entry["mealType"]} · ${(entry["servingGrams"] as num).round()}g"),
                            trailing: Text("${(entry["calories"] as num).round()} kcal"),
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

class _MacroStat extends StatelessWidget {
  final String label;
  final num grams;

  const _MacroStat({required this.label, required this.grams});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text("${grams.round()}g", style: Theme.of(context).textTheme.titleMedium),
        Text(label),
      ],
    );
  }
}
