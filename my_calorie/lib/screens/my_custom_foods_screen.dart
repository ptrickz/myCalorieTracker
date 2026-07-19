import "dart:convert";
import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../widgets/app_toast.dart";
import "../widgets/food_photo_picker.dart";
import "../widgets/photo_viewer.dart";

class MyCustomFoodsScreen extends StatefulWidget {
  const MyCustomFoodsScreen({super.key});

  @override
  State<MyCustomFoodsScreen> createState() => _MyCustomFoodsScreenState();
}

class _MyCustomFoodsScreenState extends State<MyCustomFoodsScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _foods = const [];

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      final foods = await _apiService.getMyFoods(token!);
      if (mounted) setState(() => _foods = foods);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditDialog(Map<String, dynamic> food) async {
    final nameController = TextEditingController(text: food["name"] as String);
    final caloriesController = TextEditingController(text: (food["caloriesPer100g"] as num).toString());
    final proteinController = TextEditingController(text: (food["proteinPer100g"] as num).toString());
    final carbsController = TextEditingController(text: (food["carbsPer100g"] as num).toString());
    final fatController = TextEditingController(text: (food["fatPer100g"] as num).toString());
    var photoBase64 = food["photoBase64"] as String?;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit custom food"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FoodPhotoPicker(
                  photoBase64: photoBase64,
                  onChanged: (value) => setDialogState(() => photoBase64 = value),
                ),
                const SizedBox(height: 12),
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
                const SizedBox(height: 12),
                TextField(
                  controller: caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Calories per 100g"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: proteinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Protein per 100g (g)"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: carbsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Carbs per 100g (g)"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: "Fat per 100g (g)"),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Changing macros will recalculate every past log entry for this food.",
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Save")),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final calories = double.tryParse(caloriesController.text);
    final protein = double.tryParse(proteinController.text);
    final carbs = double.tryParse(carbsController.text);
    final fat = double.tryParse(fatController.text);

    if (nameController.text.trim().isEmpty || calories == null || protein == null || carbs == null || fat == null) {
      if (!mounted) return;
      AppToast.show(context, "Fill in a name and all four macro fields");
      return;
    }

    try {
      final token = await _authStorage.readToken();
      await _apiService.updateFood(
        token!,
        food["id"] as String,
        name: nameController.text.trim(),
        caloriesPer100g: calories,
        proteinPer100g: protein,
        carbsPer100g: carbs,
        fatPer100g: fat,
        photoBase64: photoBase64,
      );
      if (!mounted) return;
      AppToast.show(context, "Food updated");
      _loadFoods();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Custom Foods")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _foods.isEmpty
                  ? const Center(child: Text("You haven't added any custom foods yet."))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _foods.length,
                      itemBuilder: (context, index) {
                        final food = _foods[index];
                        final photoBase64 = food["photoBase64"] as String?;
                        return ListTile(
                          leading: photoBase64 == null
                              ? const CircleAvatar(child: Icon(Icons.restaurant))
                              : GestureDetector(
                                  onTap: () => showFoodPhotoViewer(context, photoBase64),
                                  child: CircleAvatar(backgroundImage: MemoryImage(base64Decode(photoBase64))),
                                ),
                          title: Text(food["name"] as String),
                          subtitle: Text(
                            "${(food["caloriesPer100g"] as num).round()} kcal / 100g · "
                            "${(food["proteinPer100g"] as num).round()}g protein",
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openEditDialog(food),
                        );
                      },
                    ),
    );
  }
}
