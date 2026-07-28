import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../theme.dart";
import "../widgets/app_text_field.dart";

class CreateRecipeScreen extends StatefulWidget {
  const CreateRecipeScreen({super.key});

  @override
  State<CreateRecipeScreen> createState() => _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends State<CreateRecipeScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  final _nameController = TextEditingController();
  final _servingsController = TextEditingController(text: "1");
  final _ingredientsController = TextEditingController();
  final _stepsController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _servingsController.dispose();
    _ingredientsController.dispose();
    _stepsController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  /// One ingredient or step per line; blank lines are dropped so a trailing
  /// newline doesn't become an empty bullet.
  List<String> _lines(TextEditingController controller) => controller.text
      .split("\n")
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final servings = int.tryParse(_servingsController.text.trim());
    final calories = double.tryParse(_caloriesController.text);

    if (name.isEmpty) {
      setState(() => _errorMessage = "Give the recipe a name");
      return;
    }
    if (servings == null || servings < 1) {
      setState(() => _errorMessage = "Servings must be a whole number, 1 or more");
      return;
    }
    if (calories == null || calories <= 0) {
      setState(() => _errorMessage = "Enter the calories in one serving");
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      final recipe = await _apiService.createRecipe(
        token!,
        name: name,
        servings: servings,
        ingredients: _lines(_ingredientsController),
        steps: _lines(_stepsController),
        calories: calories,
        protein: double.tryParse(_proteinController.text),
        carbs: double.tryParse(_carbsController.text),
        fat: double.tryParse(_fatController.text),
      );
      if (!mounted) return;
      Navigator.of(context).pop(recipe);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add a recipe")),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppTextField(controller: _nameController, placeholder: "Name"),
          const SizedBox(height: 12),
          AppTextField(
            controller: _servingsController,
            keyboardType: TextInputType.number,
            placeholder: "Servings the recipe makes",
          ),
          const SizedBox(height: 24),
          const _SectionLabel("Per serving"),
          const SizedBox(height: 8),
          AppTextField(
            controller: _caloriesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: "Calories",
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _proteinController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: "Protein (g)",
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _carbsController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: "Carbs (g)",
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _fatController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            placeholder: "Fat (g)",
          ),
          const SizedBox(height: 24),
          const _SectionLabel("Ingredients — one per line"),
          const SizedBox(height: 8),
          AppTextField(
            controller: _ingredientsController,
            maxLines: 6,
            placeholder: "2 chicken breasts\n1 tbsp olive oil",
          ),
          const SizedBox(height: 24),
          const _SectionLabel("Steps — one per line"),
          const SizedBox(height: 8),
          AppTextField(
            controller: _stepsController,
            maxLines: 6,
            placeholder: "Heat the oven to 200C\nSeason and bake 25 minutes",
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
                : const Text("Save recipe"),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
    );
  }
}
