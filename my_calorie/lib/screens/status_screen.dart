import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../widgets/app_text_field.dart";
import "../widgets/app_toast.dart";
import "../widgets/background_image_body.dart";
import "../widgets/seven_day_trend_card.dart";
import "../widgets/streak_card.dart";
import "../widgets/weight_trend_card.dart";
import "profile_screen.dart";

/// Trends-over-time analytics: streak, weight trend, and 7-day intake —
/// the Dashboard stays focused on today's logging.
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => StatusScreenState();
}

class StatusScreenState extends State<StatusScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _weightLogs = const [];
  double? _goalWeightKg;
  double? _milestoneWeightKg;
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

  /// Public so HomeShell's center FAB can trigger it for this tab.
  Future<void> openLogWeightDialog() async {
    final controller = TextEditingController();
    final weightKg = await showCupertinoDialog<double>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Log today's weight"),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: AppTextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            placeholder: "Weight (kg)",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () =>
                Navigator.of(context).pop(double.tryParse(controller.text)),
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

  /// Goals now live on the Profile screen; reload on return in case they
  /// changed.
  Future<void> _openGoals() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: BackgroundImageBody(
        imagePath: "assets/img/analytics.png",
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                      onEditGoals: _openGoals,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
