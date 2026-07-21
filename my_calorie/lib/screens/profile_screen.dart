import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../theme.dart";
import "../utils/tdee_calc.dart";
import "../widgets/app_text_field.dart";
import "../widgets/app_toast.dart";
import "../widgets/background_image_body.dart";
import "../widgets/hiding_app_bar.dart";
import "../widgets/seven_day_trend_card.dart";
import "../widgets/weekly_loss_goal_slider.dart";
import "../widgets/weight_trend_card.dart";
import "welcome_screen.dart";

/// Combined profile + progress tab: account details and goals, followed by
/// the streak / weekly-trend / weight-trend analytics that used to live on
/// the separate Status page.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> with AppBarVisibilityMixin {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();
  final _heightController = TextEditingController();
  final _goalWeightController = TextEditingController();
  final _milestoneWeightController = TextEditingController();
  final _proteinTargetController = TextEditingController();
  final _weekdayTargetController = TextEditingController();
  final _weekendTargetController = TextEditingController();

  static const _activityLevels = {
    "SEDENTARY": "Sedentary (little to no exercise)",
    "LIGHT": "Light (1-3 days/week)",
    "MODERATE": "Moderate (3-5 days/week)",
    "ACTIVE": "Active (6-7 days/week)",
    "VERY_ACTIVE": "Very active (hard exercise daily)",
  };

  static const _goalTypes = {
    "LOSE": "Lose weight",
    "MAINTAIN": "Maintain weight",
    "GAIN": "Gain weight",
  };

  String? _email;
  DateTime? _dateOfBirth;
  String? _sex;
  String? _activityLevel;
  String? _goalType;
  double _weeklyLossGoalKg = 0.5;
  double? _latestWeightKg;
  bool _useCustomCalorieTargets = false;

  // Progress analytics (moved here from the old Status tab).
  List<Map<String, dynamic>> _weightLogs = const [];
  List<Map<String, dynamic>> _rangeDays = const [];

  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Snapshot taken when entering edit mode, restored on cancel.
  DateTime? _backupDateOfBirth;
  String? _backupSex;
  String? _backupActivityLevel;
  String? _backupGoalType;
  double _backupWeeklyLossGoal = 0.5;
  String _backupHeight = "";
  String _backupGoalWeight = "";
  String _backupMilestoneWeight = "";
  String _backupProteinTarget = "";
  String _backupWeekdayTarget = "";
  String _backupWeekendTarget = "";
  bool _backupUseCustomTargets = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _goalWeightController.dispose();
    _milestoneWeightController.dispose();
    _proteinTargetController.dispose();
    _weekdayTargetController.dispose();
    _weekendTargetController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      final profile = await _apiService.getProfile(token!);
      final weightLogs = await _apiService.getWeightLogs(token);
      final range = await _apiService.getLogsRange(token);
      if (!mounted) return;
      setState(() {
        _weightLogs = weightLogs;
        _rangeDays = (range["days"] as List).cast<Map<String, dynamic>>();
        _email = profile["email"] as String?;
        final dob = profile["dateOfBirth"] as String?;
        _dateOfBirth = dob == null ? null : DateTime.parse(dob);
        _sex = profile["sex"] as String?;
        _activityLevel = profile["activityLevel"] as String?;
        _goalType = profile["goalType"] as String?;
        _weeklyLossGoalKg = (profile["weeklyLossGoalKg"] as num?)?.toDouble() ?? 0.5;
        _latestWeightKg = (profile["latestWeightKg"] as num?)?.toDouble();
        _heightController.text = (profile["heightCm"] as num?)?.toString() ?? "";
        _goalWeightController.text = (profile["goalWeightKg"] as num?)?.toString() ?? "";
        _milestoneWeightController.text = (profile["milestoneWeightKg"] as num?)?.toString() ?? "";
        _proteinTargetController.text = (profile["proteinTargetG"] as num?)?.round().toString() ?? "";
        _useCustomCalorieTargets = profile["useCustomCalorieTargets"] as bool? ?? false;
        _weekdayTargetController.text =
            (profile["weekdayTargetCalories"] as num?)?.round().toString() ?? "";
        _weekendTargetController.text =
            (profile["weekendTargetCalories"] as num?)?.round().toString() ?? "";
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEditing() {
    _backupDateOfBirth = _dateOfBirth;
    _backupSex = _sex;
    _backupActivityLevel = _activityLevel;
    _backupGoalType = _goalType;
    _backupWeeklyLossGoal = _weeklyLossGoalKg;
    _backupHeight = _heightController.text;
    _backupGoalWeight = _goalWeightController.text;
    _backupMilestoneWeight = _milestoneWeightController.text;
    _backupProteinTarget = _proteinTargetController.text;
    _backupWeekdayTarget = _weekdayTargetController.text;
    _backupWeekendTarget = _weekendTargetController.text;
    _backupUseCustomTargets = _useCustomCalorieTargets;
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    setState(() {
      _dateOfBirth = _backupDateOfBirth;
      _sex = _backupSex;
      _activityLevel = _backupActivityLevel;
      _goalType = _backupGoalType;
      _weeklyLossGoalKg = _backupWeeklyLossGoal;
      _heightController.text = _backupHeight;
      _goalWeightController.text = _backupGoalWeight;
      _milestoneWeightController.text = _backupMilestoneWeight;
      _proteinTargetController.text = _backupProteinTarget;
      _weekdayTargetController.text = _backupWeekdayTarget;
      _weekendTargetController.text = _backupWeekendTarget;
      _useCustomCalorieTargets = _backupUseCustomTargets;
      _errorMessage = null;
      _isEditing = false;
    });
  }

  Future<void> _handleLogout() async {
    await _authStorage.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
      _loadProfile();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  bool get _canSave =>
      _dateOfBirth != null && _sex != null && _activityLevel != null && _goalType != null &&
      _heightController.text.isNotEmpty;

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      await _apiService.updateProfile(
        token!,
        dateOfBirth: _dateOfBirth!.toIso8601String(),
        sex: _sex!,
        heightCm: double.parse(_heightController.text),
        activityLevel: _activityLevel!,
        goalType: _goalType!,
      );
      await _apiService.updateGoals(
        token,
        goalWeightKg: double.tryParse(_goalWeightController.text),
        milestoneWeightKg: double.tryParse(_milestoneWeightController.text),
        proteinTargetG: double.tryParse(_proteinTargetController.text),
        weeklyLossGoalKg: _weeklyLossGoalKg,
        useCustomCalorieTargets: _useCustomCalorieTargets,
        weekdayTargetCalories:
            _useCustomCalorieTargets ? double.tryParse(_weekdayTargetController.text) : null,
        weekendTargetCalories:
            _useCustomCalorieTargets ? double.tryParse(_weekendTargetController.text) : null,
      );
      if (!mounted) return;
      AppToast.show(context, "Profile updated");
      setState(() => _isEditing = false);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: HidingAppBar(visible: appBarVisible, title: const Text("Profile")),
      body: BackgroundImageBody(
        imagePath: "assets/img/profile.png",
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<UserScrollNotification>(
              onNotification: handleScrollNotification,
              child: RefreshIndicator(
              onRefresh: _loadProfile,
              child: ListView(
              padding: EdgeInsets.fromLTRB(
                  24, MediaQuery.of(context).padding.top + kToolbarHeight + 8, 24, 24),
              children: [
                SevenDayTrendCard(days: _rangeDays),
                const SizedBox(height: 16),
                WeightTrendCard(
                  weightLogs: _weightLogs,
                  goalWeightKg: double.tryParse(_goalWeightController.text),
                  milestoneWeightKg: double.tryParse(_milestoneWeightController.text),
                ),
                const SizedBox(height: 24),
                // Edit sits with the two cards it edits (About you + Goals),
                // not up in the header card.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionLabel("About you"),
                    if (!_isEditing)
                      TextButton.icon(
                        onPressed: _startEditing,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text("Edit", style: TextStyle(fontSize: 13)),
                      ),
                  ],
                ),
                _buildAboutSection(),
                const SizedBox(height: 24),
                _buildSectionLabel("Goals"),
                _buildGoalsSection(),
                if (_isEditing) ...[
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                    ),
                  ElevatedButton(
                    onPressed: (_canSave && !_isSaving) ? _handleSave : null,
                    child: _isSaving
                        ? const SizedBox(
                            height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text("Save"),
                  ),
                  TextButton(
                    onPressed: _isSaving ? null : _cancelEditing,
                    child: const Text("Cancel"),
                  ),
                ] else if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
                  ),
                // Sits at the very bottom, out of the way of everyday use.
                if (!_isEditing) ...[
                  const SizedBox(height: 32),
                  TextButton.icon(
                    onPressed: _handleLogout,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text("Log out"),
                  ),
                  // Clears the center-docked FAB, which floats over the
                  // bottom of the list.
                  const SizedBox(height: 72),
                ],
              ],
            ),
          ),
          ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAboutSection() {
    if (_isEditing) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Email comes from the account and isn't editable here.
              _buildInfoTile(Icons.alternate_email, "Email", _email ?? "Not set"),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_outlined, color: AppColors.textSecondary),
                title: Text(_dateOfBirth == null
                    ? "Date of birth"
                    : "Date of birth: ${_dateOfBirth!.toIso8601String().substring(0, 10)}"),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: _pickDateOfBirth,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _sex,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "Sex"),
                items: const [
                  DropdownMenuItem(value: "MALE", child: Text("Male")),
                  DropdownMenuItem(value: "FEMALE", child: Text("Female")),
                ],
                onChanged: (value) => setState(() => _sex = value),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                placeholder: "Height (cm)",
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _activityLevel,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "Activity level"),
                items: _activityLevels.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (value) => setState(() => _activityLevel = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _goalType,
                isExpanded: true,
                decoration: const InputDecoration(labelText: "Goal"),
                items: _goalTypes.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (value) => setState(() => _goalType = value),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          _buildInfoTile(Icons.alternate_email, "Email", _email ?? "Not set"),
          _buildInfoTile(
            Icons.cake_outlined,
            "Date of birth",
            _dateOfBirth == null ? "Not set" : _dateOfBirth!.toIso8601String().substring(0, 10),
          ),
          _buildInfoTile(Icons.wc_outlined, "Sex",
              _sex == null ? "Not set" : (_sex == "MALE" ? "Male" : "Female")),
          _buildInfoTile(Icons.height, "Height",
              _heightController.text.isEmpty ? "Not set" : "${_heightController.text} cm"),
          _buildInfoTile(Icons.directions_run, "Activity level",
              _activityLevel == null ? "Not set" : _activityLevels[_activityLevel]!),
          _buildInfoTile(
              Icons.flag_outlined, "Goal", _goalType == null ? "Not set" : _goalTypes[_goalType]!),
        ],
      ),
    );
  }

  /// Live estimate of the daily calorie target for the values currently in
  /// the form; null while required inputs are missing. Uses the latest logged
  /// weight, mirroring the server calculation.
  double? get _previewTargetCalories => estimateDailyTargetCalories(
        weightKg: _latestWeightKg,
        heightCm: double.tryParse(_heightController.text),
        dateOfBirth: _dateOfBirth,
        sex: _sex,
        activityLevel: _activityLevel,
        goalType: _goalType,
        weeklyLossGoalKg: _weeklyLossGoalKg,
      );

  Widget _buildGoalsSection() {
    if (_isEditing) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AppTextField(
                controller: _goalWeightController,
                keyboardType: TextInputType.number,
                placeholder: "Goal weight (kg)",
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _milestoneWeightController,
                keyboardType: TextInputType.number,
                placeholder: "Milestone weight (kg)",
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _proteinTargetController,
                keyboardType: TextInputType.number,
                placeholder: "Protein target (g)",
              ),
              if (_goalType == "LOSE" || _goalType == "GAIN") ...[
                const SizedBox(height: 16),
                WeeklyLossGoalSlider(
                  value: _weeklyLossGoalKg,
                  isGain: _goalType == "GAIN",
                  previewTargetCalories: _previewTargetCalories,
                  onChanged: (value) => setState(() => _weeklyLossGoalKg = value),
                ),
              ],
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Custom weekday/weekend targets", style: TextStyle(fontSize: 14)),
                value: _useCustomCalorieTargets,
                onChanged: (value) => setState(() => _useCustomCalorieTargets = value),
              ),
              if (_useCustomCalorieTargets) ...[
                AppTextField(
                  controller: _weekdayTargetController,
                  keyboardType: TextInputType.number,
                  placeholder: "Weekday calorie target",
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _weekendTargetController,
                  keyboardType: TextInputType.number,
                  placeholder: "Weekend calorie target",
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: [
          _buildInfoTile(Icons.flag_outlined, "Goal weight",
              _goalWeightController.text.isEmpty ? "Not set" : "${_goalWeightController.text} kg"),
          _buildInfoTile(
              Icons.outlined_flag,
              "Milestone weight",
              _milestoneWeightController.text.isEmpty
                  ? "Not set"
                  : "${_milestoneWeightController.text} kg"),
          _buildInfoTile(
              Icons.fitness_center,
              "Protein target",
              _proteinTargetController.text.isEmpty
                  ? "Not set"
                  : "${_proteinTargetController.text} g"),
          if (_goalType == "LOSE" || _goalType == "GAIN")
            _buildInfoTile(
                Icons.speed,
                _goalType == "GAIN" ? "Weekly gain goal" : "Weekly loss goal",
                "${_weeklyLossGoalKg.toStringAsFixed(2)} kg/week"),
          SwitchListTile(
            secondary: const Icon(Icons.tune, color: AppColors.textSecondary),
            title: const Text("Custom weekday/weekend targets", style: TextStyle(fontSize: 14)),
            value: _useCustomCalorieTargets,
            onChanged: null,
          ),
          if (_useCustomCalorieTargets) ...[
            _buildInfoTile(Icons.work_outline, "Weekday target",
                _weekdayTargetController.text.isEmpty ? "Auto" : "${_weekdayTargetController.text} kcal"),
            _buildInfoTile(Icons.weekend_outlined, "Weekend target",
                _weekendTargetController.text.isEmpty ? "Auto" : "${_weekendTargetController.text} kcal"),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(
        value,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }
}
