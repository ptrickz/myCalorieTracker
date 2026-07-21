import "dart:async";
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "package:url_launcher/url_launcher.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../theme.dart";
import "../widgets/app_text_field.dart";
import "../widgets/app_toast.dart";

class WorkoutSessionScreen extends StatefulWidget {
  final String workoutLogId;
  final List<Map<String, dynamic>> initialExercises;

  const WorkoutSessionScreen({super.key, required this.workoutLogId, required this.initialExercises});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  late List<Map<String, dynamic>> _exercises;
  // exerciseId -> sets already logged in this session (loaded from the server
  // when re-opening a past session so they can be viewed and edited).
  Map<String, List<Map<String, dynamic>>> _existingSets = {};
  bool _isLoading = true;
  Timer? _restTimer;
  int _restSecondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _exercises = List.of(widget.initialExercises);
    _loadSession();
  }

  /// Loads any sets already logged against this session so re-opening a past
  /// session shows its contents. Exercises with existing sets are merged in
  /// on top of whatever was passed in (e.g. today's plan).
  Future<void> _loadSession() async {
    try {
      final token = await _authStorage.readToken();
      final log = await _apiService.getWorkoutLog(token!, widget.workoutLogId);
      final sets = (log["sets"] as List).cast<Map<String, dynamic>>();

      final byExercise = <String, List<Map<String, dynamic>>>{};
      final exercises = List<Map<String, dynamic>>.of(_exercises);
      for (final set in sets) {
        final exercise = set["exercise"] as Map<String, dynamic>;
        final id = exercise["id"] as String;
        byExercise.putIfAbsent(id, () => []).add(set);
        if (!exercises.any((e) => e["id"] == id)) exercises.add(exercise);
      }

      if (!mounted) return;
      setState(() {
        _existingSets = byExercise;
        _exercises = exercises;
      });
    } catch (e) {
      if (mounted) AppToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    super.dispose();
  }

  void _startRestTimer([int seconds = 75]) {
    _restTimer?.cancel();
    setState(() => _restSecondsLeft = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _restSecondsLeft = 0);
      } else {
        setState(() => _restSecondsLeft--);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    setState(() => _restSecondsLeft = 0);
  }

  static const _createNewSentinel = "__create_new__";

  Future<void> _addExercise() async {
    final token = await _authStorage.readToken();
    final all = await _apiService.getExercises(token!);
    if (!mounted) return;

    String? selectedId;

    final result = await showCupertinoDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text("Add exercise"),
          // Material ancestor for the dropdown, which Cupertino dialogs
          // don't provide on their own.
          content: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: DropdownButtonFormField<String>(
                initialValue: selectedId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "Exercise"),
                items: [
                  ...all.map(
                    (e) => DropdownMenuItem(
                      value: e["id"] as String,
                      child: Text(e["name"] as String, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: _createNewSentinel,
                    child: Text(
                      "+ Create new custom exercise",
                      style: TextStyle(color: AppColors.accent),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (value) => setDialogState(() => selectedId = value),
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
              onPressed: selectedId == null ? null : () => Navigator.of(context).pop(selectedId),
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    if (result == _createNewSentinel) {
      await _createCustomExercise();
      return;
    }

    final picked = all.firstWhere((e) => e["id"] == result);
    if (!_exercises.any((e) => e["id"] == picked["id"])) {
      setState(() => _exercises.add(picked));
    }
  }

  Future<void> _createCustomExercise() async {
    final nameController = TextEditingController();
    final setsController = TextEditingController();
    final repsController = TextEditingController();
    final videoController = TextEditingController();
    final imageController = TextEditingController();

    final name = await showCupertinoDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("New exercise"),
        content: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextField(controller: nameController, autofocus: true, placeholder: "Name"),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: setsController,
                      placeholder: "Sets",
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      controller: repsController,
                      // Free text — targets can be "8-12" or "30 sec". "sec"
                      // marks the exercise as timed in the log card.
                      placeholder: "Reps (8-12, 30 sec)",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: videoController,
                placeholder: "Video URL (optional)",
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: imageController,
                placeholder: "Image URL (optional)",
                keyboardType: TextInputType.url,
              ),
            ],
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(context).pop(nameController.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    try {
      final token = await _authStorage.readToken();
      final exercise = await _apiService.createExercise(
        token!,
        name: name,
        defaultSets: int.tryParse(setsController.text),
        defaultReps: repsController.text.trim().isEmpty ? null : repsController.text.trim(),
        videoUrl: videoController.text.trim().isEmpty ? null : videoController.text.trim(),
        imageUrl: imageController.text.trim().isEmpty ? null : imageController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _exercises.add(exercise));
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Workout Session"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Finish", style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_restSecondsLeft > 0) _buildRestBanner(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ..._exercises.map(
                        (e) => _ExerciseLogCard(
                          key: ValueKey(e["id"]),
                          exercise: e,
                          workoutLogId: widget.workoutLogId,
                          initialSets: _existingSets[e["id"]] ?? const [],
                          onSetLogged: () => _startRestTimer(),
                          onRemoved: () => setState(() {
                            _exercises.removeWhere((x) => x["id"] == e["id"]);
                            _existingSets.remove(e["id"]);
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _addExercise,
                        icon: const Icon(Icons.add),
                        label: const Text("Add exercise"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRestBanner() {
    return Container(
      width: double.infinity,
      color: AppColors.accent,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Rest: ${_restSecondsLeft}s", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          TextButton(onPressed: _skipRest, child: const Text("Skip", style: TextStyle(color: Colors.black))),
        ],
      ),
    );
  }
}

class _ExerciseLogCard extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final String workoutLogId;
  final List<Map<String, dynamic>> initialSets;
  final VoidCallback onSetLogged;

  /// Called after the exercise (and all its logged sets) has been removed
  /// from this session, so the parent can drop the card.
  final VoidCallback onRemoved;

  const _ExerciseLogCard({
    super.key,
    required this.exercise,
    required this.workoutLogId,
    required this.onSetLogged,
    required this.onRemoved,
    this.initialSets = const [],
  });

  @override
  State<_ExerciseLogCard> createState() => _ExerciseLogCardState();
}

class _ExerciseLogCardState extends State<_ExerciseLogCard> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();
  final _repsController = TextEditingController();
  final _weightController = TextEditingController();
  final _durationController = TextEditingController();

  late List<Map<String, dynamic>> _loggedSets = List.of(widget.initialSets);
  Map<String, dynamic>? _progression;
  bool _isLogging = false;

  // Duration-based exercises: short holds target "sec" (planks), cardio
  // targets "min" (walks, bike). The input follows the target's unit; the
  // server always stores seconds.
  bool get _isTimed {
    final reps = widget.exercise["defaultReps"] as String?;
    return reps != null && (reps.contains("sec") || reps.contains("min"));
  }

  bool get _isMinutes => (widget.exercise["defaultReps"] as String?)?.contains("min") ?? false;

  // One past the highest set number so deleting a middle set doesn't cause the
  // next one to reuse a number.
  int get _nextSetNumber => _loggedSets.fold<int>(0, (max, s) {
        final n = (s["setNumber"] as num?)?.toInt() ?? 0;
        return n > max ? n : max;
      }) +
      1;

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadProgression() async {
    try {
      final token = await _authStorage.readToken();
      final result = await _apiService.getExerciseProgression(token!, widget.exercise["id"] as String);
      if (!mounted) return;
      setState(() => _progression = result);
      if (result["hasHistory"] == true) {
        final suggestion = result["suggestion"] as Map<String, dynamic>;
        if (suggestion["reps"] != null) _repsController.text = (suggestion["reps"] as num).round().toString();
        if (suggestion["weightKg"] != null) _weightController.text = (suggestion["weightKg"] as num).toString();
        if (suggestion["durationSeconds"] != null) {
          final seconds = (suggestion["durationSeconds"] as num).round();
          _durationController.text = _isMinutes ? (seconds / 60).round().toString() : seconds.toString();
        }
      }
    } catch (_) {
      // Progression is a nice-to-have hint — fail silently.
    }
  }

  Future<void> _logSet() async {
    setState(() => _isLogging = true);
    try {
      final token = await _authStorage.readToken();
      final set = await _apiService.addWorkoutSet(
        token!,
        widget.workoutLogId,
        exerciseId: widget.exercise["id"] as String,
        setNumber: _nextSetNumber,
        reps: _isTimed ? null : int.tryParse(_repsController.text),
        weightKg: _isTimed ? null : double.tryParse(_weightController.text),
        durationSeconds: !_isTimed
            ? null
            : _isMinutes
                ? (int.tryParse(_durationController.text) == null
                    ? null
                    : int.parse(_durationController.text) * 60)
                : int.tryParse(_durationController.text),
      );
      if (!mounted) return;
      setState(() => _loggedSets = [..._loggedSets, set]);
      widget.onSetLogged();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  Future<void> _deleteSet(Map<String, dynamic> set) async {
    // Sets logged in a previous session have a server id; a set just added in
    // this view also has one (returned by addWorkoutSet).
    final setId = set["id"] as String?;
    if (setId == null) return;
    try {
      final token = await _authStorage.readToken();
      await _apiService.deleteWorkoutSet(token!, widget.workoutLogId, setId);
      if (!mounted) return;
      setState(() => _loggedSets = _loggedSets.where((s) => s["id"] != setId).toList());
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  Future<void> _openVideo() async {
    final url = widget.exercise["videoUrl"] as String?;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Removes this exercise from the session: deletes every logged set on the
  /// server (the session record is just its sets), then tells the parent to
  /// drop the card. The exercise itself stays in the catalog.
  Future<void> _removeFromSession() async {
    final setCount = _loggedSets.length;
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Text("Remove ${widget.exercise["name"]}?"),
        content: Text(
          setCount == 0
              ? "Remove this exercise from the session?"
              : "This deletes its $setCount logged set${setCount == 1 ? "" : "s"} from this session.",
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final token = await _authStorage.readToken();
      for (final set in List.of(_loggedSets)) {
        final setId = set["id"] as String?;
        if (setId != null) await _apiService.deleteWorkoutSet(token!, widget.workoutLogId, setId);
      }
      if (!mounted) return;
      widget.onRemoved();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  /// Minutes once past a minute (trimming a trailing .0), seconds below that.
  String _formatDuration(int seconds) {
    if (seconds < 60) return "$seconds sec";
    final minutes = seconds / 60;
    return minutes == minutes.roundToDouble()
        ? "${minutes.round()} min"
        : "${minutes.toStringAsFixed(1)} min";
  }

  String _formatSet(Map<String, dynamic> s) {
    final seconds = (s["durationSeconds"] as num?)?.toInt();
    if (seconds != null) return "Set ${s["setNumber"]}: ${_formatDuration(seconds)}";
    final weight = s["weightKg"] != null ? " @ ${s["weightKg"]}kg" : "";
    return "Set ${s["setNumber"]}: ${s["reps"]} reps$weight";
  }

  /// Card subtitle. For duration-based work (cardio, holds) the target range
  /// is far less useful than what was actually done, so once something is
  /// logged we show the total logged time instead of the plan.
  String get _subtitle {
    final count = _loggedSets.length;

    if (_isTimed && count > 0) {
      final total = _loggedSets.fold<int>(
        0,
        (sum, s) => sum + ((s["durationSeconds"] as num?)?.toInt() ?? 0),
      );
      return "${_formatDuration(total)} · $count logged";
    }

    final sets = widget.exercise["defaultSets"];
    final reps = widget.exercise["defaultReps"];
    return [
      // Custom exercises have no target — show just the count.
      if (sets != null && reps != null) "$sets x $reps",
      "$count logged",
    ].join(" · ");
  }

  @override
  Widget build(BuildContext context) {
    final formCue = widget.exercise["formCue"] as String?;
    final videoUrl = widget.exercise["videoUrl"] as String?;
    final imageUrl = widget.exercise["imageUrl"] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(widget.exercise["name"] as String),
        subtitle: Text(
          _subtitle,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        onExpansionChanged: (expanded) {
          if (expanded && _progression == null) _loadProgression();
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
                ],
                if (formCue != null) Text(formCue, style: const TextStyle(color: AppColors.textSecondary)),
                if (videoUrl != null) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _openVideo,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text("Watch demo"),
                    ),
                  ),
                ],
                if (_progression?["hasHistory"] == true) ...[
                  const Text(
                    "Pre-filled from your last session",
                    style: TextStyle(color: AppColors.accent, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_isTimed)
                  AppTextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    placeholder: "Duration (${_isMinutes ? "min" : "sec"})",
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _repsController,
                          keyboardType: TextInputType.number,
                          placeholder: "Reps",
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppTextField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          placeholder: "Weight (kg)",
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isLogging ? null : _logSet,
                  child: _isLogging
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text("Log Set $_nextSetNumber"),
                ),
                if (_loggedSets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ..._loggedSets.map(
                    (s) => Row(
                      children: [
                        Expanded(
                          child: Text(_formatSet(s), style: const TextStyle(color: AppColors.textSecondary)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: "Delete set",
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _deleteSet(s),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _removeFromSession,
                    style: TextButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text("Remove from session"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
