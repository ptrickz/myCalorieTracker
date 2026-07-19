import "dart:async";
import "dart:convert";
import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../constants.dart";
import "../widgets/app_toast.dart";
import "../widgets/background_image_body.dart";
import "../widgets/food_photo_picker.dart";
import "../widgets/photo_viewer.dart";

enum FoodHubTab { logFood, customFood }

class FoodHubScreen extends StatefulWidget {
  /// Lets HomeShell know which sub-tab is active so it can swap the FAB
  /// between the scanner (Log Food) and add-custom-food (Custom Food).
  final ValueChanged<FoodHubTab>? onSubTabChanged;

  const FoodHubScreen({super.key, this.onSubTabChanged});

  @override
  State<FoodHubScreen> createState() => FoodHubScreenState();
}

class FoodHubScreenState extends State<FoodHubScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();
  final _searchController = TextEditingController();
  final _servingController = TextEditingController(text: "100");

  FoodHubTab _tab = FoodHubTab.logFood;

  // Log Food state
  List<Map<String, dynamic>> _results = const [];
  Map<String, dynamic>? _selectedFood;
  String _mealType = "BREAKFAST";
  bool _isSearching = false;
  bool _isLogging = false;
  String? _errorMessage;
  Timer? _debounce;

  // Custom Food state
  bool _isLoadingCustom = true;
  String? _customErrorMessage;
  List<Map<String, dynamic>> _customFoods = const [];

  @override
  void initState() {
    super.initState();
    _loadFoods();
    _loadCustomFoods();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Called by HomeShell after the FAB's CreateFoodScreen push returns.
  Future<void> refreshAfterCreate() => _loadCustomFoods();

  void _switchTab(FoodHubTab tab) {
    setState(() => _tab = tab);
    widget.onSubTabChanged?.call(tab);
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadFoods(value),
    );
  }

  Future<void> _loadFoods([String? query]) async {
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      final results = await _apiService.searchFoods(token!, query);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _loadCustomFoods() async {
    setState(() {
      _isLoadingCustom = true;
      _customErrorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      final foods = await _apiService.getMyFoods(token!);
      if (mounted) setState(() => _customFoods = foods);
    } catch (e) {
      if (mounted) setState(() => _customErrorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingCustom = false);
    }
  }

  Future<void> _handleLogIt() async {
    final servingGrams = double.tryParse(_servingController.text);
    if (servingGrams == null || servingGrams <= 0) {
      setState(() => _errorMessage = "Enter a valid serving size in grams");
      return;
    }

    setState(() {
      _isLogging = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      await _apiService.createLogEntry(
        token!,
        foodItemId: _selectedFood!["id"] as String,
        servingGrams: servingGrams,
        mealType: _mealType,
      );
      if (!mounted) return;
      AppToast.show(context, "Logged!");
      setState(() {
        _selectedFood = null;
        _servingController.text = "100";
        _mealType = "BREAKFAST";
      });
      _loadFoods();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  Future<void> _openEditDialog(Map<String, dynamic> food) async {
    final nameController = TextEditingController(text: food["name"] as String);
    final caloriesController = TextEditingController(
      text: (food["caloriesPer100g"] as num).toString(),
    );
    final proteinController = TextEditingController(
      text: (food["proteinPer100g"] as num).toString(),
    );
    final carbsController = TextEditingController(
      text: (food["carbsPer100g"] as num).toString(),
    );
    final fatController = TextEditingController(
      text: (food["fatPer100g"] as num).toString(),
    );
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
                  onChanged: (value) =>
                      setDialogState(() => photoBase64 = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Calories per 100g",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: proteinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Protein per 100g (g)",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: carbsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Carbs per 100g (g)",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fatController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Fat per 100g (g)",
                  ),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final calories = double.tryParse(caloriesController.text);
    final protein = double.tryParse(proteinController.text);
    final carbs = double.tryParse(carbsController.text);
    final fat = double.tryParse(fatController.text);

    if (nameController.text.trim().isEmpty ||
        calories == null ||
        protein == null ||
        carbs == null ||
        fat == null) {
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
      _loadCustomFoods();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete food?"),
        content: Text('Delete "${food["name"]}"? This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await _authStorage.readToken();
      await _apiService.deleteFood(token!, food["id"] as String);
      if (!mounted) return;
      AppToast.show(context, "Food deleted");
      _loadCustomFoods();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Food")),
      body: BackgroundImageBody(
        imagePath: "assets/img/food.png",
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<FoodHubTab>(
                segments: const [
                  ButtonSegment(
                    value: FoodHubTab.logFood,
                    label: Text("Log Food"),
                    icon: Icon(Icons.search),
                  ),
                  ButtonSegment(
                    value: FoodHubTab.customFood,
                    label: Text("Custom Food"),
                    icon: Icon(Icons.restaurant_menu),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (selection) => _switchTab(selection.first),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _tab == FoodHubTab.logFood
                    ? _buildLogFoodBody()
                    : _buildCustomFoodBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Log Food sub-tab ---

  Widget _buildLogFoodBody() {
    return _selectedFood == null ? _buildSearchStep() : _buildLogStep();
  }

  Widget _buildSearchStep() {
    final isBrowsingDefault = _searchController.text.trim().isEmpty;
    final recents = isBrowsingDefault
        ? _results.where((f) => f["isRecent"] == true).toList()
        : <Map<String, dynamic>>[];
    final others = isBrowsingDefault
        ? _results.where((f) => f["isRecent"] != true).toList()
        : _results;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(labelText: "Search foods"),
                onChanged: _onSearchChanged,
              ),
            ),
            IconButton(
              onPressed: () => _loadFoods(_searchController.text),
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null)
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        if (_isSearching) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            children: [
              if (recents.isNotEmpty) ...[
                Text("Recent", style: Theme.of(context).textTheme.labelLarge),
                ...recents.map(_buildFoodTile),
                const SizedBox(height: 8),
              ],
              if (others.isNotEmpty) ...[
                if (isBrowsingDefault)
                  Text(
                    "All Foods",
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ...others.map(_buildFoodTile),
              ],
              if (!_isSearching && _results.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text("No foods found."),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFoodTile(Map<String, dynamic> food) {
    final photoBase64 = food["photoBase64"] as String?;
    return ListTile(
      leading: photoBase64 == null
          ? const CircleAvatar(child: Icon(Icons.restaurant))
          : GestureDetector(
              onTap: () => showFoodPhotoViewer(context, photoBase64),
              child: CircleAvatar(
                backgroundImage: MemoryImage(base64Decode(photoBase64)),
              ),
            ),
      title: Text(food["name"] as String),
      subtitle: Text("${(food["caloriesPer100g"] as num).round()} kcal / 100g"),
      onTap: () => setState(() => _selectedFood = food),
    );
  }

  Widget _buildLogStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _selectedFood!["name"] as String,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _servingController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Serving size (grams)"),
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
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ElevatedButton(
          onPressed: _isLogging ? null : _handleLogIt,
          child: _isLogging
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Log it"),
        ),
        TextButton(
          onPressed: () => setState(() => _selectedFood = null),
          child: const Text("Back to search"),
        ),
      ],
    );
  }

  // --- Custom Food sub-tab ---

  Widget _buildCustomFoodBody() {
    if (_isLoadingCustom)
      return const Center(child: CircularProgressIndicator());
    if (_customErrorMessage != null) {
      return Center(
        child: Text(
          _customErrorMessage!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }
    if (_customFoods.isEmpty) {
      return const Center(
        child: Text("You haven't added any custom foods yet."),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCustomFoods,
      child: ListView.builder(
        itemCount: _customFoods.length,
        itemBuilder: (context, index) {
          final food = _customFoods[index];
          final photoBase64 = food["photoBase64"] as String?;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: photoBase64 == null
                ? const CircleAvatar(child: Icon(Icons.restaurant))
                : GestureDetector(
                    onTap: () => showFoodPhotoViewer(context, photoBase64),
                    child: CircleAvatar(
                      backgroundImage: MemoryImage(base64Decode(photoBase64)),
                    ),
                  ),
            title: Text(food["name"] as String),
            subtitle: Text(
              "${(food["caloriesPer100g"] as num).round()} kcal / 100g · "
              "${(food["proteinPer100g"] as num).round()}g protein",
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: "Delete",
              onPressed: () => _confirmDelete(food),
            ),
            onTap: () => _openEditDialog(food),
          );
        },
      ),
    );
  }
}
