import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "dashboard_screen.dart";

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  DateTime? _dateOfBirth;
  String? _sex;
  String? _activityLevel;
  String? _goalType;
  bool _isLoading = false;
  String? _errorMessage;

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

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  bool get _canSubmit =>
      _dateOfBirth != null &&
      _sex != null &&
      _activityLevel != null &&
      _goalType != null &&
      _heightController.text.isNotEmpty &&
      _weightController.text.isNotEmpty;

  Future<void> _handleSubmit() async {
    setState(() {
      _isLoading = true;
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
        weightKg: double.parse(_weightController.text),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set up your profile")),
      body: ListView(
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
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Current weight (kg)"),
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
            onPressed: (_canSubmit && !_isLoading) ? _handleSubmit : null,
            child: _isLoading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Save and continue"),
          ),
        ],
      ),
    );
  }
}
