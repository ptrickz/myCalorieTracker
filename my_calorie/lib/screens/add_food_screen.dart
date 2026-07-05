import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "create_food_screen.dart";

class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({super.key});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();
  final _searchController = TextEditingController();
  final _servingController = TextEditingController(text: "100");

  List<Map<String, dynamic>> _results = const [];
  Map<String, dynamic>? _selectedFood;
  String _mealType = "BREAKFAST";
  bool _isSearching = false;
  bool _isLogging = false;
  String? _errorMessage;

  static const _mealTypes = {
    "BREAKFAST": "Breakfast",
    "LUNCH": "Lunch",
    "DINNER": "Dinner",
    "SNACK": "Snack",
  };

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final token = await _authStorage.readToken();
      final results = await _apiService.searchFoods(token!, query);
      setState(() => _results = results);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _openCreateFood() async {
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => CreateFoodScreen(initialName: _searchController.text.trim())),
    );
    if (created != null) setState(() => _selectedFood = created);
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
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add food")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _selectedFood == null ? _buildSearchStep() : _buildLogStep(),
      ),
    );
  }

  Widget _buildSearchStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(labelText: "Search foods"),
                onSubmitted: (_) => _handleSearch(),
              ),
            ),
            IconButton(onPressed: _handleSearch, icon: const Icon(Icons.search)),
          ],
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null)
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        if (_isSearching) const Center(child: CircularProgressIndicator()),
        Expanded(
          child: ListView(
            children: [
              ..._results.map(
                (food) => ListTile(
                  title: Text(food["name"] as String),
                  subtitle: Text("${(food["caloriesPer100g"] as num).round()} kcal / 100g"),
                  onTap: () => setState(() => _selectedFood = food),
                ),
              ),
              TextButton(
                onPressed: _openCreateFood,
                child: const Text("Can't find it? Add a custom food"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_selectedFood!["name"] as String, style: Theme.of(context).textTheme.titleLarge),
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
          items: _mealTypes.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (value) => setState(() => _mealType = value!),
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ),
        ElevatedButton(
          onPressed: _isLogging ? null : _handleLogIt,
          child: _isLogging
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Log it"),
        ),
        TextButton(
          onPressed: () => setState(() => _selectedFood = null),
          child: const Text("Back to search"),
        ),
      ],
    );
  }
}
