import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../widgets/app_text_field.dart";
import "../widgets/food_photo_picker.dart";

class CreateFoodScreen extends StatefulWidget {
  final String initialName;

  const CreateFoodScreen({super.key, this.initialName = ""});

  @override
  State<CreateFoodScreen> createState() => _CreateFoodScreenState();
}

class _CreateFoodScreenState extends State<CreateFoodScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();
  late final _nameController = TextEditingController(text: widget.initialName);
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  String? _photoBase64;

  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _handleSave() async {
    final calories = double.tryParse(_caloriesController.text);
    final protein = double.tryParse(_proteinController.text);
    final carbs = double.tryParse(_carbsController.text);
    final fat = double.tryParse(_fatController.text);

    if (_nameController.text.trim().isEmpty || calories == null || protein == null || carbs == null || fat == null) {
      setState(() => _errorMessage = "Fill in a name and all four macro fields");
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      final food = await _apiService.createFood(
        token!,
        name: _nameController.text.trim(),
        caloriesPer100g: calories,
        proteinPer100g: protein,
        carbsPer100g: carbs,
        fatPer100g: fat,
        photoBase64: _photoBase64,
      );
      if (!mounted) return;
      Navigator.of(context).pop(food);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add a custom food")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppTextField(controller: _nameController, placeholder: "Name"),
          const SizedBox(height: 12),
          FoodPhotoPicker(
            photoBase64: _photoBase64,
            onChanged: (value) => setState(() => _photoBase64 = value),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _caloriesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: "Calories per 100g",
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _proteinController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: "Protein per 100g (g)",
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _carbsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: "Carbs per 100g (g)",
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _fatController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: "Fat per 100g (g)",
          ),
          const SizedBox(height: 24),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Save food"),
          ),
        ],
      ),
    );
  }
}
