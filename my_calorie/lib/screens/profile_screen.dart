import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../widgets/app_toast.dart";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();
  final _heightController = TextEditingController();

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

  bool _isEditing = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Snapshot taken when entering edit mode, restored on cancel.
  DateTime? _backupDateOfBirth;
  String? _backupSex;
  String? _backupActivityLevel;
  String? _backupGoalType;
  String _backupHeight = "";

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      final profile = await _apiService.getProfile(token!);
      if (!mounted) return;
      setState(() {
        _email = profile["email"] as String?;
        final dob = profile["dateOfBirth"] as String?;
        _dateOfBirth = dob == null ? null : DateTime.parse(dob);
        _sex = profile["sex"] as String?;
        _activityLevel = profile["activityLevel"] as String?;
        _goalType = profile["goalType"] as String?;
        _heightController.text = (profile["heightCm"] as num?)?.toString() ?? "";
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
    _backupHeight = _heightController.text;
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    setState(() {
      _dateOfBirth = _backupDateOfBirth;
      _sex = _backupSex;
      _activityLevel = _backupActivityLevel;
      _goalType = _backupGoalType;
      _heightController.text = _backupHeight;
      _errorMessage = null;
      _isEditing = false;
    });
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
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          if (!_isLoading && !_isEditing)
            IconButton(onPressed: _startEditing, icon: const Icon(Icons.edit), tooltip: "Edit"),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEditing
              ? _buildEditView()
              : _buildReadOnlyView(),
    );
  }

  Widget _buildReadOnlyView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_email != null) ...[
          Text(_email!, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
        ],
        _buildInfoRow(
          "Date of birth",
          _dateOfBirth == null ? "Not set" : _dateOfBirth!.toIso8601String().substring(0, 10),
        ),
        _buildInfoRow("Sex", _sex == null ? "Not set" : (_sex == "MALE" ? "Male" : "Female")),
        _buildInfoRow(
          "Height",
          _heightController.text.isEmpty ? "Not set" : "${_heightController.text} cm",
        ),
        _buildInfoRow("Activity level", _activityLevel == null ? "Not set" : _activityLevels[_activityLevel]!),
        _buildInfoRow("Goal", _goalType == null ? "Not set" : _goalTypes[_goalType]!),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildEditView() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_dateOfBirth == null
              ? "Date of birth"
              : "Date of birth: ${_dateOfBirth!.toIso8601String().substring(0, 10)}"),
          trailing: const Icon(Icons.calendar_today),
          onTap: _pickDateOfBirth,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _sex,
          decoration: const InputDecoration(labelText: "Sex"),
          items: const [
            DropdownMenuItem(value: "MALE", child: Text("Male")),
            DropdownMenuItem(value: "FEMALE", child: Text("Female")),
          ],
          onChanged: (value) => setState(() => _sex = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _heightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Height (cm)"),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _activityLevel,
          decoration: const InputDecoration(labelText: "Activity level"),
          items: _activityLevels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (value) => setState(() => _activityLevel = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _goalType,
          decoration: const InputDecoration(labelText: "Goal"),
          items: _goalTypes.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (value) => setState(() => _goalType = value),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ),
        ElevatedButton(
          onPressed: (_canSave && !_isSaving) ? _handleSave : null,
          child: _isSaving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Save"),
        ),
        TextButton(
          onPressed: _isSaving ? null : _cancelEditing,
          child: const Text("Cancel"),
        ),
      ],
    );
  }
}
