import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../theme.dart";
import "../widgets/app_text_field.dart";
import "../widgets/app_toast.dart";
import "../widgets/background_image_body.dart";
import "../widgets/workout_week_calendar.dart";
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
      final logs = await _apiService.getWorkoutLogs(token!, limit: 100);
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

    final venue = await showCupertinoDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text("Log a session"),
          // Material ancestor for the dropdown, which Cupertino dialogs
          // don't provide on their own.
          content: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedVenue,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Where?"),
                    items: _venueOptions
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedVenue = value!),
                  ),
                  if (selectedVenue == "Other") ...[
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: otherController,
                      autofocus: true,
                      placeholder: "Venue name",
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop(
                selectedVenue == "Other"
                    ? otherController.text.trim()
                    : selectedVenue,
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
          builder: (_) => WorkoutSessionScreen(
            workoutLogId: log["id"] as String,
            initialExercises: const [],
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

  @override
  Widget build(BuildContext context) {
    final dayTag = _todaysDayTag;
    final restNote = _restDayNotes[DateTime.now().weekday];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: BackgroundImageBody(
        imagePath: "assets/img/workouts.png",
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
                    if (dayTag != null) ...[
                      Text(
                        "Today's workout ($dayTag)",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      WorkoutWeekCalendar(logs: _recentLogs),

                      const SizedBox(height: 12),
                    ] else ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(restNote ?? "No workout planned today."),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    Text(
                      "This week",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),

                    const SizedBox(height: 24),
                    Text(
                      "Session history",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_recentLogs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text("No sessions logged yet."),
                      )
                    else
                      ..._buildWeekGroups(),
                  ],
                ),
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
                child: Image.network(
                  imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
        title: Text(exercise["name"] as String),
        subtitle: Text(
          "${exercise["defaultSets"] ?? "?"} x ${exercise["defaultReps"] ?? "?"}",
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  static const _monthNames = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];

  String _formatShortDate(DateTime date) =>
      "${_monthNames[date.month - 1]} ${date.day}";

  /// Sessions grouped by calendar week (Monday-start), newest week first.
  List<Widget> _buildWeekGroups() {
    final groups = <DateTime, List<Map<String, dynamic>>>{};
    for (final log in _recentLogs) {
      final loggedAt = DateTime.parse(log["loggedAt"] as String).toLocal();
      final day = DateTime(loggedAt.year, loggedAt.month, loggedAt.day);
      final weekStart = day.subtract(
        Duration(days: day.weekday - DateTime.monday),
      );
      groups.putIfAbsent(weekStart, () => []).add(log);
    }

    final sortedWeeks = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return [
      for (final weekStart in sortedWeeks) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            "${_formatShortDate(weekStart)} - ${_formatShortDate(weekStart.add(const Duration(days: 6)))}",
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...groups[weekStart]!.map(_buildSessionTile),
      ],
    ];
  }

  Widget _buildSessionTile(Map<String, dynamic> log) {
    final sets = (log["sets"] as List).cast<Map<String, dynamic>>();
    final exerciseNames = sets
        .map((s) => (s["exercise"] as Map<String, dynamic>)["name"] as String)
        .toSet();
    final loggedAt = DateTime.parse(log["loggedAt"] as String).toLocal();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text("${log["venue"]} · ${_formatShortDate(loggedAt)}"),
      subtitle: Text(
        exerciseNames.isEmpty ? "No sets logged" : exerciseNames.join(", "),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: "Delete session",
        onPressed: () => _confirmDeleteSession(log),
      ),
    );
  }

  Future<void> _confirmDeleteSession(Map<String, dynamic> log) async {
    final loggedAt = DateTime.parse(log["loggedAt"] as String).toLocal();
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Delete session?"),
        content: Text(
          'Delete the ${log["venue"]} session from ${_formatShortDate(loggedAt)}? This can\'t be undone.',
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await _authStorage.readToken();
      await _apiService.deleteWorkoutLog(token!, log["id"] as String);
      if (!mounted) return;
      AppToast.show(context, "Session deleted");
      _load();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }
}
