import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../theme.dart";
import "../widgets/app_text_field.dart";
import "../widgets/app_toast.dart";
import "../widgets/background_image_body.dart";
import "../widgets/empty_state.dart";
import "../widgets/hiding_app_bar.dart";
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

class WorkoutScreenState extends State<WorkoutScreen> with AppBarVisibilityMixin {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  bool _isLoading = true;
  String? _errorMessage;
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
      final logs = await _apiService.getWorkoutLogs(token!, limit: 100);
      if (!mounted) return;
      setState(() => _recentLogs = logs);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Called by HomeShell's Workout-tab FAB.
  Future<void> startFreeSession() => _startFreeSession();

  Future<void> _startFreeSession() async {
    // Guards against a double-tapped FAB creating two sessions.
    if (_isStarting) return;
    final otherController = TextEditingController();
    var selectedVenue = _venueOptions.first;
    // Defaults to today; can be moved back to backfill a missed session.
    var selectedDate = DateTime.now();

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
                  const SizedBox(height: 4),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.event_outlined,
                      color: AppColors.textSecondary,
                    ),
                    title: Text(
                      DateUtils.isSameDay(selectedDate, DateTime.now())
                          ? "Today"
                          : _formatShortDate(selectedDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                    trailing: const Icon(Icons.edit_calendar, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                  ),
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
      // Keep the current time-of-day so a backfilled session lands sensibly
      // on the week calendar rather than at midnight.
      final now = DateTime.now();
      final loggedAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        now.hour,
        now.minute,
      );
      final log = await _apiService.createWorkoutLog(
        token!,
        venue: venue,
        loggedAt: loggedAt.toIso8601String(),
      );
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
      appBar: HidingAppBar(visible: appBarVisible, title: const Text("Workouts")),
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
            : NotificationListener<UserScrollNotification>(
                onNotification: handleScrollNotification,
                child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      24, MediaQuery.of(context).padding.top + kToolbarHeight + 8, 24, 24),
                  children: [
                    Text(
                      dayTag != null ? "Today's workout ($dayTag)" : "Today — rest day",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (dayTag == null) ...[
                      const SizedBox(height: 4),
                      Text(
                        restNote ?? "No workout planned today.",
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    WorkoutWeekCalendar(logs: _recentLogs),
                    const SizedBox(height: 24),
                    Text(
                      "Session history",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_recentLogs.isEmpty)
                      const EmptyState(
                        icon: Icons.fitness_center_outlined,
                        title: "No sessions logged yet",
                        hint: "Tap + to log your first workout.",
                      )
                    else
                      ..._buildWeekGroups(),
                  ],
                ),
                ),
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
      onTap: () => _openSession(log),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: "Delete session",
        onPressed: () => _confirmDeleteSession(log),
      ),
    );
  }

  /// Re-open a past session so it can be edited (add exercises, log or delete
  /// sets). The session screen loads its existing contents on open.
  Future<void> _openSession(Map<String, dynamic> log) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          workoutLogId: log["id"] as String,
          initialExercises: const [],
        ),
      ),
    );
    _load();
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
