import "dart:convert";
import "dart:typed_data";
import "package:flutter/material.dart";
import "package:image_picker/image_picker.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../widgets/app_text_field.dart";
import "../widgets/app_toast.dart";
import "../constants.dart";
import "../theme.dart";

class ScanFoodScreen extends StatefulWidget {
  const ScanFoodScreen({super.key});

  @override
  State<ScanFoodScreen> createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends State<ScanFoodScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  String _mode = "label";
  Uint8List? _imageBytes;
  String _mediaType = "image/jpeg";
  bool _isAnalyzing = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;

  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _servingController = TextEditingController(text: "100");
  String _mealType = "BREAKFAST";
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Jump straight into the camera on entry; the Camera/Gallery buttons
    // remain as the fallback if the user cancels the shot.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _imageBytes == null) _pickPhoto(ImageSource.camera);
    });
  }

  String _guessMediaType(XFile file) {
    if (file.mimeType != null) return file.mimeType!;
    final lower = file.name.toLowerCase();
    if (lower.endsWith(".png")) return "image/png";
    if (lower.endsWith(".webp")) return "image/webp";
    if (lower.endsWith(".gif")) return "image/gif";
    return "image/jpeg";
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _mediaType = _guessMediaType(picked);
      _result = null;
      _errorMessage = null;
    });
  }

  Future<void> _analyze() async {
    if (_imageBytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      final response = await _apiService.visionLog(
        token!,
        imageBase64: base64Encode(_imageBytes!),
        mediaType: _mediaType,
        mode: _mode,
      );
      final result = response["result"] as Map<String, dynamic>;
      _applyResultToForm(result);
      setState(() => _result = result);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _applyResultToForm(Map<String, dynamic> result) {
    if (_mode == "label") {
      _nameController.text = result["name"] as String;
      _caloriesController.text = (result["caloriesPer100g"] as num).round().toString();
      _proteinController.text = (result["proteinPer100g"] as num).round().toString();
      _carbsController.text = (result["carbsPer100g"] as num).round().toString();
      _fatController.text = (result["fatPer100g"] as num).round().toString();
      _servingController.text = "100";
      return;
    }

    final servingGrams = (result["estimatedServingGrams"] as num).toDouble();
    final calMid = ((result["caloriesMin"] as num) + (result["caloriesMax"] as num)) / 2;
    final proteinMid = ((result["proteinGramsMin"] as num) + (result["proteinGramsMax"] as num)) / 2;
    final carbsMid = ((result["carbsGramsMin"] as num) + (result["carbsGramsMax"] as num)) / 2;
    final fatMid = ((result["fatGramsMin"] as num) + (result["fatGramsMax"] as num)) / 2;
    final scale = servingGrams > 0 ? 100 / servingGrams : 1.0;

    _nameController.text = result["description"] as String;
    _caloriesController.text = (calMid * scale).round().toString();
    _proteinController.text = (proteinMid * scale).round().toString();
    _carbsController.text = (carbsMid * scale).round().toString();
    _fatController.text = (fatMid * scale).round().toString();
    _servingController.text = servingGrams.round().toString();
  }

  Future<void> _handleLogIt() async {
    final calories = double.tryParse(_caloriesController.text);
    final protein = double.tryParse(_proteinController.text);
    final carbs = double.tryParse(_carbsController.text);
    final fat = double.tryParse(_fatController.text);
    final servingGrams = double.tryParse(_servingController.text);

    if (_nameController.text.trim().isEmpty ||
        calories == null ||
        protein == null ||
        carbs == null ||
        fat == null ||
        servingGrams == null ||
        servingGrams <= 0) {
      AppToast.show(context, "Fill in a name, all macro fields, and a valid serving size");
      return;
    }

    setState(() => _isSaving = true);

    try {
      final token = await _authStorage.readToken();
      final food = await _apiService.createFood(
        token!,
        name: _nameController.text.trim(),
        caloriesPer100g: calories,
        proteinPer100g: protein,
        carbsPer100g: carbs,
        fatPer100g: fat,
      );
      await _apiService.createLogEntry(
        token,
        foodItemId: food["id"] as String,
        servingGrams: servingGrams,
        mealType: _mealType,
      );
      if (!mounted) return;
      AppToast.show(context, "Logged!");
      setState(() {
        _imageBytes = null;
        _result = null;
      });
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
      appBar: AppBar(title: const Text("Scan food")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: "label", label: Text("Label"), icon: Icon(Icons.receipt_long)),
              ButtonSegment(value: "plate", label: Text("Plate / Meal"), icon: Icon(Icons.restaurant)),
            ],
            selected: {_mode},
            // The photo is mode-independent (only analysis differs), so keep
            // it when toggling — just drop any result from the other mode.
            onSelectionChanged: (selection) {
              setState(() {
                _mode = selection.first;
                _result = null;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 20),
          if (_imageBytes == null) _buildPickButtons() else _buildImagePreview(),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            _buildReviewForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildPickButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickPhoto(ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text("Camera"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickPhoto(ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text("Gallery"),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(_imageBytes!, height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _isAnalyzing
                    ? null
                    : () => setState(() {
                          _imageBytes = null;
                          _result = null;
                        }),
                child: const Text("Retake"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isAnalyzing ? null : _analyze,
                child: _isAnalyzing
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text("Analyze"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewForm() {
    final result = _result!;
    final ingredients = _mode == "plate" ? (result["ingredients"] as List).cast<String>() : const <String>[];
    final notes = result["notes"] as String;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
              const SizedBox(width: 6),
              Text(
                "Confidence: ${result["confidence"]}",
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
          if (_mode == "plate") ...[
            const SizedBox(height: 8),
            Text(
              "Estimated range: ${(result["caloriesMin"] as num).round()}-${(result["caloriesMax"] as num).round()} kcal total",
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            if (ingredients.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                "Identified: ${ingredients.join(", ")}",
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ],
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              notes,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 16),
          Text("Review and adjust before saving", style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          AppTextField(controller: _nameController, placeholder: "Name"),
          const SizedBox(height: 12),
          AppTextField(
            controller: _servingController,
            keyboardType: TextInputType.number,
            placeholder: "Serving size",
            suffix: const _UnitLabel("g"),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  placeholder: "Calories",
                  suffix: const _UnitLabel("kcal"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _proteinController,
                  keyboardType: TextInputType.number,
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
                  keyboardType: TextInputType.number,
                  placeholder: "Carbs",
                  suffix: const _UnitLabel("g"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _fatController,
                  keyboardType: TextInputType.number,
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
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _mealType,
            decoration: const InputDecoration(labelText: "Meal"),
            items: mealTypeLabels.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (value) => setState(() => _mealType = value!),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleLogIt,
            child: _isSaving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Log it"),
          ),
        ],
      ),
    );
  }
}

/// Small unit suffix shown inside a macro input (e.g. "kcal", "g") so the unit
/// stays visible after the placeholder is replaced by a value.
class _UnitLabel extends StatelessWidget {
  final String text;

  const _UnitLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    );
  }
}
