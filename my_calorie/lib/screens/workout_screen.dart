import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../theme.dart";
import "../widgets/app_toast.dart";
import "workout_session_screen.dart";

const _restDayNotes = {
  DateTime.tuesday: "Rest day: park walk or 20-min bike.",
  DateTime.thursday: "Rest day: park walk or 20-min bike.",
  DateTime.saturday: "Rest day: optional badminton / active with family.",
  DateTime.sunday: "Full rest day.",
};

const _weekdayDayTag = {
  DateTime.monday: "Monday",
  DateTime.wednesday: "Wednesday",
  DateTime.friday: "Friday",
};

const _venueOptions = ["Gym", "Badminton Court", "Park", "Home", "Other"];

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => WorkoutScreenState();
}

class WorkoutScreenState extends State<WorkoutScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _todaysExercises = const [];
  List<Map<String, dynamic>> _recentLogs = const [];
  bool _isStarting = false;

  String? get _todaysDayTag => _weekdayDayTag[DateTime.now().weekday];

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
      final dayTag = _todaysDayTag;
      final exercises = dayTag == null
          ? <Map<String, dynamic>>[]
          : await _apiService.getExercises(token!, dayTag: dayTag);
      final logs = await _apiService.getWorkoutLogs(token!, limit: 5);
      if (!mounted) return;
      setState(() {
        _todaysExercises = exercises;
        _recentLogs = logs;
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startTodaysWorkout() async {
    setState(() => _isStarting = true);
    try {
      final token = await _authStorage.readToken();
      final log = await _apiService.createWorkoutLog(token!, venue: "Home");
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkoutSessionScreen(
            workoutLogId: log["id"] as String,
            initialExercises: _todaysExercises,
          ),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  /// Called by HomeShell's Workout-tab FAB.
  Future<void> startFreeSession() => _startFreeSession();

  Future<void> _startFreeSession() async {
    final otherController = TextEditingController();
    var selectedVenue = _venueOptions.first;

    final venue = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Log a session"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedVenue,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "Where?"),
                items: _venueOptions.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                onChanged: (value) => setDialogState(() => selectedVenue = value!),
              ),
              if (selectedVenue == "Other") ...[
                const SizedBox(height: 12),
                TextField(
                  controller: otherController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: "Venue name"),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                selectedVenue == "Other" ? otherController.text.trim() : selectedVenue,
              ),
              child: const Text("Start"),
            ),
          ],
        ),
      ),
    );

    if (venue == null || venue.isEmpty) return;

    setState(() => _isStarting = true);
    try {
      final token = await _authStorage.readToken();
      final log = await _apiService.createWorkoutLog(token!, venue: venue);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WorkoutSessionScreen(workoutLogId: log["id"] as String, initialExercises: const []),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayTag = _todaysDayTag;
    final restNote = _restDayNotes[DateTime.now().weekday];

    return Scaffold(
      appBar: AppBar(title: const Text("Workouts")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      if (dayTag != null) ...[
                        Text("Today's workout ($dayTag)", style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        ..._todaysExercises.map(_buildExercisePreview),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _isStarting ? null : _startTodaysWorkout,
                          child: _isStarting
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text("Start Workout"),
                        ),
                      ] else ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(restNote ?? "No workout planned today."),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isStarting ? null : _startFreeSession,
                        child: const Text("Log a different session (gym, sport, ...)"),
                      ),
                      const SizedBox(height: 24),
                      Text("Recent sessions", style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (_recentLogs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text("No sessions logged yet."),
                        )
                      else
                        ..._recentLogs.map(_buildRecentLogTile),
                    ],
                  ),
                ),
    );
  }

  Widget _buildExercisePreview(Map<String, dynamic> exercise) {
    final imageUrl = exercise["imageUrl"] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: imageUrl == null
            ? null
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover),
              ),
        title: Text(exercise["name"] as String),
        subtitle: Text(
          "${exercise["defaultSets"] ?? "?"} x ${exercise["defaultReps"] ?? "?"}",
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildRecentLogTile(Map<String, dynamic> log) {
    final sets = (log["sets"] as List).cast<Map<String, dynamic>>();
    final exerciseNames = sets.map((s) => (s["exercise"] as Map<String, dynamic>)["name"] as String).toSet();
    final loggedAt = DateTime.parse(log["loggedAt"] as String);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(log["venue"] as String),
      subtitle: Text(
        exerciseNames.isEmpty
            ? "No sets logged"
            : "${exerciseNames.join(", ")} · ${loggedAt.toLocal().toString().substring(0, 16)}",
      ),
    );
  }
}
