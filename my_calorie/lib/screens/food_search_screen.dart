import "dart:async";
import "dart:convert";
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../constants.dart";
import "../theme.dart";
import "../widgets/app_text_field.dart";
import "../widgets/app_toast.dart";
import "../widgets/photo_viewer.dart";

/// Full-screen "add food" surface: search, recents, one-tap logging, and
/// repeat-a-meal. Opened from the Food diary; it stays open after each log so
/// several items can be added in a row, calling [onChanged] each time so the
/// diary underneath refreshes.
class FoodSearchScreen extends StatefulWidget {
  final String initialMeal;
  final VoidCallback onChanged;

  const FoodSearchScreen({super.key, required this.initialMeal, required this.onChanged});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();
  final _searchController = TextEditingController();
  final _servingController = TextEditingController(text: "100");

  late String _mealType = widget.initialMeal;
  List<Map<String, dynamic>> _results = const [];
  Map<String, dynamic>? _selectedFood;
  bool _isSearching = false;
  bool _isLogging = false;
  String? _quickLoggingFoodId;
  List<Map<String, dynamic>> _recentMeals = const [];
  String? _errorMessage;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadFoods();
    _loadRecentMeals();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _servingController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _loadFoods(value));
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

  Future<void> _loadRecentMeals() async {
    try {
      final token = await _authStorage.readToken();
      final meals = await _apiService.getRecentMeals(token!, _mealType);
      if (mounted) setState(() => _recentMeals = meals);
    } catch (_) {
      if (mounted) setState(() => _recentMeals = const []);
    }
  }

  /// One-tap log using the food's last-used serving (100g if never logged).
  Future<void> _quickLog(Map<String, dynamic> food) async {
    if (_quickLoggingFoodId != null) return;
    setState(() => _quickLoggingFoodId = food["id"] as String);
    final servingGrams = (food["lastServingGrams"] as num?)?.toDouble() ?? 100;
    try {
      final token = await _authStorage.readToken();
      await _apiService.createLogEntry(
        token!,
        foodItemId: food["id"] as String,
        servingGrams: servingGrams,
        mealType: _mealType,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        "Logged ${food["name"]} · ${servingGrams.round()}g to ${mealTypeLabels[_mealType]}",
      );
      widget.onChanged();
      _loadFoods();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _quickLoggingFoodId = null);
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
      widget.onChanged();
      // Back to the list so the next item can be added.
      setState(() {
        _selectedFood = null;
        _servingController.text = "100";
      });
      _loadFoods();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  String _relativeDayLabel(String isoDate) {
    final date = DateTime.parse(isoDate);
    final today = DateTime.now();
    final days = DateTime(today.year, today.month, today.day)
        .difference(DateTime(date.year, date.month, date.day))
        .inDays;
    if (days == 1) return "Yesterday";
    if (days < 7) return "$days days ago";
    return isoDate;
  }

  Future<void> _openRepeatMealPicker() async {
    final label = mealTypeLabels[_mealType]!;
    final picked = await showCupertinoDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: Text("Repeat a previous $label"),
        content: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _recentMeals.map((meal) {
                final names = (meal["entries"] as List)
                    .cast<Map<String, dynamic>>()
                    .map((e) => e["name"] as String)
                    .join(", ");
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "${_relativeDayLabel(meal["date"] as String)} · "
                    "${(meal["calories"] as num).round()} kcal",
                    style: const TextStyle(fontSize: 14),
                  ),
                  subtitle: Text(
                    names,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () => Navigator.of(context).pop(meal["date"] as String),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );

    if (picked == null) return;

    try {
      final token = await _authStorage.readToken();
      final created = await _apiService.repeatMeal(token!, date: picked, mealType: _mealType);
      if (!mounted) return;
      AppToast.show(context, "Added $created item${created == 1 ? "" : "s"} to $label");
      widget.onChanged();
      _loadRecentMeals();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add food")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: _selectedFood == null ? _buildSearch() : _buildLogStep(),
        ),
      ),
    );
  }

  Widget _buildSearch() {
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
        _buildMealSelector(),
        if (_recentMeals.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openRepeatMealPicker,
              icon: const Icon(Icons.replay, size: 18),
              label: Text("Repeat a previous ${mealTypeLabels[_mealType]}"),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _searchController,
          placeholder: "Search foods",
          autofocus: true,
          onChanged: _onSearchChanged,
        ),
        const SizedBox(height: 16),
        if (_errorMessage != null)
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
        if (_isSearching) const LinearProgressIndicator(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (recents.isNotEmpty) ...[
                Text("Recent", style: Theme.of(context).textTheme.labelLarge),
                ...recents.map(_buildFoodTile),
                const SizedBox(height: 8),
              ],
              if (others.isNotEmpty) ...[
                if (isBrowsingDefault)
                  Text("All Foods", style: Theme.of(context).textTheme.labelLarge),
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

  Widget _buildMealSelector() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: mealTypeLabels.entries.map((entry) {
          final isSelected = entry.key == _mealType;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _mealType = entry.key);
                _loadRecentMeals();
              },
              showCheckmark: false,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.surface,
              side: BorderSide(color: isSelected ? AppColors.accent : AppColors.border),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFoodTile(Map<String, dynamic> food) {
    final photoBase64 = food["photoBase64"] as String?;
    final perHundred = (food["caloriesPer100g"] as num).toDouble();
    final lastServing = (food["lastServingGrams"] as num?)?.toDouble();
    final subtitle = lastServing == null
        ? "${perHundred.round()} kcal / 100g"
        : "${(perHundred * lastServing / 100).round()} kcal · ${lastServing.round()}g";
    final isQuickLogging = _quickLoggingFoodId == food["id"];

    return ListTile(
      leading: photoBase64 == null
          ? const CircleAvatar(child: Icon(Icons.restaurant))
          : GestureDetector(
              onTap: () => showFoodPhotoViewer(context, photoBase64),
              child: CircleAvatar(backgroundImage: MemoryImage(base64Decode(photoBase64))),
            ),
      title: Text(food["name"] as String),
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: isQuickLogging
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.add_circle_outline, color: AppColors.accent),
        tooltip: "Log ${(lastServing ?? 100).round()}g to ${mealTypeLabels[_mealType]}",
        onPressed: isQuickLogging ? null : () => _quickLog(food),
      ),
      onTap: () => setState(() => _selectedFood = food),
    );
  }

  Widget _buildLogStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_selectedFood!["name"] as String, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        AppTextField(
          controller: _servingController,
          keyboardType: TextInputType.number,
          placeholder: "Serving size (grams)",
        ),
        const SizedBox(height: 12),
        _buildMealSelector(),
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
