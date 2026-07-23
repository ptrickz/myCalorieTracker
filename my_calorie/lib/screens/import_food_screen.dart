import "dart:convert";
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../constants.dart";
import "../theme.dart";
import "../widgets/app_text_field.dart";
import "../widgets/app_toast.dart";
import "../widgets/empty_state.dart";

const _macroFields = ["kcal", "proteinG", "carbsG", "fatG"];

/// Imports a food from the fixed macro-estimate JSON a user might get out of
/// a claude.ai chat (discussing a meal, reading a label together, working
/// through portion math) — so that result can become a food here without
/// retyping numbers already worked out in the conversation.
///
/// Nothing is written to the server just from picking a file: the picked
/// JSON is parsed and shown in an editable review form first, same as the
/// vision-log (camera scan) flow, and only saved once the user confirms.
class ImportFoodScreen extends StatefulWidget {
  final VoidCallback onChanged;

  const ImportFoodScreen({super.key, required this.onChanged});

  @override
  State<ImportFoodScreen> createState() => _ImportFoodScreenState();
}

class _ImportFoodScreenState extends State<ImportFoodScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  Map<String, dynamic>? _parsedImport;
  String? _pickError;
  bool _isPicking = false;
  bool _isSaving = false;

  final _nameController = TextEditingController();
  final _servingController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String _mealType = "BREAKFAST";

  @override
  void dispose() {
    _nameController.dispose();
    _servingController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _isPicking = true;
      _pickError = null;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ["json"],
        withData: true,
      );
      if (result == null) return; // user cancelled

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        setState(() => _pickError = "Could not read that file.");
        return;
      }

      final Map<String, dynamic> json;
      try {
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException("root is not an object");
        }
        json = decoded;
      } catch (_) {
        setState(() => _pickError = "That file isn't valid JSON.");
        return;
      }

      final shapeError = _validateShape(json);
      if (shapeError != null) {
        setState(() => _pickError = shapeError);
        return;
      }

      _applyImportToForm(json);
      setState(() => _parsedImport = json);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  /// Fast, friendly local check before anything touches the network — the
  /// server re-validates (and additionally sanity-checks totalMacros) when
  /// the import is actually confirmed.
  String? _validateShape(Map<String, dynamic> json) {
    final name = json["name"];
    if (name is! String || name.trim().isEmpty) {
      return 'Missing or invalid "name".';
    }
    final weight = json["estimatedTotalWeightG"];
    if (weight is! num || weight <= 0) {
      return 'Missing or invalid "estimatedTotalWeightG".';
    }
    final macros = json["macrosPer100g"];
    if (macros is! Map) {
      return 'Missing "macrosPer100g".';
    }
    for (final field in _macroFields) {
      if (macros[field] is! num) {
        return 'Missing or invalid "macrosPer100g.$field".';
      }
    }
    return null;
  }

  void _applyImportToForm(Map<String, dynamic> json) {
    final macros = json["macrosPer100g"] as Map;
    _nameController.text = json["name"] as String;
    _servingController.text = (json["estimatedTotalWeightG"] as num).round().toString();
    _caloriesController.text = _formatNum(macros["kcal"] as num);
    _proteinController.text = _formatNum(macros["proteinG"] as num);
    _carbsController.text = _formatNum(macros["carbsG"] as num);
    _fatController.text = _formatNum(macros["fatG"] as num);
  }

  String _formatNum(num n) => n == n.roundToDouble() ? n.round().toString() : n.toString();

  void _reset() {
    setState(() {
      _parsedImport = null;
      _pickError = null;
    });
  }

  Map<String, dynamic>? _buildRequestBody() {
    final calories = double.tryParse(_caloriesController.text);
    final protein = double.tryParse(_proteinController.text);
    final carbs = double.tryParse(_carbsController.text);
    final fat = double.tryParse(_fatController.text);
    final serving = double.tryParse(_servingController.text);

    if (_nameController.text.trim().isEmpty ||
        calories == null ||
        protein == null ||
        carbs == null ||
        fat == null ||
        serving == null ||
        serving <= 0) {
      AppToast.show(context, "Fill in a name, all macro fields, and a valid serving size");
      return null;
    }

    // Recomputed from the (possibly edited) review fields rather than the
    // original file's totalMacros, so edits the user makes here are what
    // actually gets sanity-checked and saved.
    final scale = serving / 100;
    return {
      "name": _nameController.text.trim(),
      "estimatedTotalWeightG": serving,
      "macrosPer100g": {
        "kcal": calories,
        "proteinG": protein,
        "carbsG": carbs,
        "fatG": fat,
      },
      "totalMacros": {
        "kcal": calories * scale,
        "proteinG": protein * scale,
        "carbsG": carbs * scale,
        "fatG": fat * scale,
      },
    };
  }

  Future<void> _handleSave({required bool logNow}) async {
    final body = _buildRequestBody();
    if (body == null) return;

    setState(() => _isSaving = true);
    try {
      final token = await _authStorage.readToken();
      final food = await _apiService.importFood(token!, body);

      if (logNow) {
        final dateLogged = _parsedImport?["dateLogged"] as String?;
        await _apiService.createLogEntry(
          token,
          foodItemId: food["id"] as String,
          servingGrams: body["estimatedTotalWeightG"] as double,
          mealType: _mealType,
          loggedAt: dateLogged,
        );
      }

      if (!mounted) return;
      AppToast.show(context, logNow ? "Imported and logged!" : "Food saved");
      widget.onChanged();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Import from file")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _parsedImport == null ? _buildPickStep() : _buildReviewForm(),
        ),
      ),
    );
  }

  Widget _buildPickStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Center(
            child: EmptyState(
              icon: Icons.file_open_outlined,
              title: "Import a food from a file",
              hint: "For macro estimates worked out in a claude.ai chat — "
                  "reading a label together, or calculating a meal from known "
                  "components. Pick the JSON file to review it here.",
            ),
          ),
        ),
        if (_pickError != null) ...[
          Text(_pickError!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
          const SizedBox(height: 12),
        ],
        ElevatedButton.icon(
          onPressed: _isPicking ? null : _pickFile,
          icon: _isPicking
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.file_upload_outlined),
          label: Text(_isPicking ? "Reading..." : "Choose file"),
        ),
      ],
    );
  }

  Widget _buildReviewForm() {
    final confidence = _parsedImport?["confidence"] as String?;
    final source = _parsedImport?["source"] as String?;

    return ListView(
      children: [
        if (confidence != null || source != null)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      ?confidence,
                      if (source != null) "source: $source",
                    ].join(" · "),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        Text("Review and adjust before saving", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        AppTextField(controller: _nameController, placeholder: "Name"),
        const SizedBox(height: 12),
        AppTextField(
          controller: _servingController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: "Serving size",
          suffix: const _UnitLabel("g"),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _caloriesController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                placeholder: "Calories",
                suffix: const _UnitLabel("kcal"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _proteinController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                placeholder: "Protein",
                suffix: const _UnitLabel("g"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _carbsController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                placeholder: "Carbs",
                suffix: const _UnitLabel("g"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                controller: _fatController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                placeholder: "Fat",
                suffix: const _UnitLabel("g"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          "Values are per 100g",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _mealType,
          decoration: const InputDecoration(labelText: "Log to meal"),
          items: mealTypeLabels.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (value) => setState(() => _mealType = value!),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isSaving ? null : () => _handleSave(logNow: true),
          child: _isSaving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Save & log it"),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isSaving ? null : () => _handleSave(logNow: false),
          child: const Text("Save as food only, don't log"),
        ),
        TextButton(
          onPressed: _isSaving ? null : _reset,
          child: const Text("Choose a different file"),
        ),
      ],
    );
  }
}

/// Small unit suffix shown inside a macro input (e.g. "kcal", "g") so the
/// unit stays visible after the placeholder is replaced by a value.
class _UnitLabel extends StatelessWidget {
  final String text;

  const _UnitLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14));
  }
}
