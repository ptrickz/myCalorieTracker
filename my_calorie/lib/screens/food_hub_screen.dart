import "dart:convert";
import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../constants.dart";
import "../theme.dart";
import "../widgets/app_text_field.dart";
import "../widgets/app_toast.dart";
import "../widgets/background_image_body.dart";
import "../widgets/empty_state.dart";
import "../widgets/food_photo_picker.dart";
import "../widgets/photo_viewer.dart";
import "food_search_screen.dart";

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

  FoodHubTab _tab = FoodHubTab.logFood;

  // Custom Food state
  bool _isLoadingCustom = true;
  String? _customErrorMessage;
  List<Map<String, dynamic>> _customFoods = const [];

  // Day-log (diary) state — the Log Food tab's main content.
  bool _isLoadingDay = false;
  Map<String, dynamic> _dayTotals = const {"calories": 0, "protein": 0, "carbs": 0, "fat": 0};
  List<Map<String, dynamic>> _entries = const [];
  DateTime _viewedDate = DateTime.now();

  bool get _isViewingToday => _dateKey(_viewedDate) == _dateKey(DateTime.now());

  String _dateKey(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  String _dateLabel(DateTime date) {
    if (_isViewingToday) return "Today";
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (_dateKey(date) == _dateKey(yesterday)) return "Yesterday";
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  static String _mealTypeForNow() {
    final hour = DateTime.now().hour;
    if (hour < 11) return "BREAKFAST";
    if (hour < 16) return "LUNCH";
    if (hour < 21) return "DINNER";
    return "SNACK";
  }

  @override
  void initState() {
    super.initState();
    _loadCustomFoods();
    _loadDayLogs(DateTime.now());
  }

  /// Called by HomeShell after the FAB's CreateFoodScreen push returns.
  Future<void> refreshAfterCreate() => _loadCustomFoods();

  void _switchTab(FoodHubTab tab) {
    setState(() => _tab = tab);
    widget.onSubTabChanged?.call(tab);
  }

  Future<void> _loadDayLogs(DateTime date) async {
    setState(() {
      _viewedDate = date;
      _isLoadingDay = true;
    });
    try {
      final token = await _authStorage.readToken();
      final logs = await _apiService.getLogs(token!, date: _dateKey(date));
      if (!mounted) return;
      setState(() {
        _dayTotals = logs["totals"] as Map<String, dynamic>;
        _entries = (logs["entries"] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingDay = false);
    }
  }

  void _goToPreviousDay() => _loadDayLogs(_viewedDate.subtract(const Duration(days: 1)));

  void _goToNextDay() {
    if (_isViewingToday) return;
    _loadDayLogs(_viewedDate.add(const Duration(days: 1)));
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(
          initialMeal: _mealTypeForNow(),
          onChanged: () => _loadDayLogs(_viewedDate),
        ),
      ),
    );
  }

  Future<void> _openEditLogEntryDialog(Map<String, dynamic> entry) async {
    final servingController = TextEditingController(
      text: (entry["servingGrams"] as num).round().toString(),
    );
    var mealType = entry["mealType"] as String;

    // Returns "save", "delete", or null (cancel/dismiss).
    final action = await showCupertinoDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: Text(entry["foodItem"]["name"] as String),
          content: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: servingController,
                    keyboardType: TextInputType.number,
                    placeholder: "Serving size (grams)",
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: mealType,
                    decoration: const InputDecoration(labelText: "Meal"),
                    items: mealTypeLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (value) => setDialogState(() => mealType = value!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop("delete"),
              child: const Text("Delete"),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(context).pop("save"),
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );

    if (action == null) return;

    try {
      final token = await _authStorage.readToken();
      if (action == "delete") {
        await _apiService.deleteLogEntry(token!, entry["id"] as String);
      } else {
        final servingGrams = double.tryParse(servingController.text);
        if (servingGrams == null || servingGrams <= 0) {
          if (!mounted) return;
          AppToast.show(context, "Enter a valid serving size");
          return;
        }
        await _apiService.updateLogEntry(
          token!,
          entry["id"] as String,
          servingGrams: servingGrams,
          mealType: mealType,
        );
      }
      await _loadDayLogs(_viewedDate);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
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

  Future<void> _openEditDialog(Map<String, dynamic> food) async {
    final nameController = TextEditingController(text: food["name"] as String);
    final caloriesController = TextEditingController(text: (food["caloriesPer100g"] as num).toString());
    final proteinController = TextEditingController(text: (food["proteinPer100g"] as num).toString());
    final carbsController = TextEditingController(text: (food["carbsPer100g"] as num).toString());
    final fatController = TextEditingController(text: (food["fatPer100g"] as num).toString());
    var photoBase64 = food["photoBase64"] as String?;

    final saved = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text("Edit custom food"),
          content: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FoodPhotoPicker(
                    photoBase64: photoBase64,
                    onChanged: (value) => setDialogState(() => photoBase64 = value),
                  ),
                  const SizedBox(height: 12),
                  AppTextField(controller: nameController, placeholder: "Name"),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: caloriesController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: "Calories per 100g",
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: proteinController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: "Protein per 100g (g)",
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: carbsController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: "Carbs per 100g (g)",
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: fatController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: "Fat per 100g (g)",
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Changing macros will recalculate every past log entry for this food.",
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
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
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Delete food?"),
        content: Text('Delete "${food["name"]}"? This can\'t be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text("Food")),
      body: BackgroundImageBody(
        imagePath: "assets/img/food.png",
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.of(context).padding.top + kToolbarHeight + 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<FoodHubTab>(
                segments: const [
                  ButtonSegment(value: FoodHubTab.logFood, label: Text("Log Food"), icon: Icon(Icons.book_outlined)),
                  ButtonSegment(value: FoodHubTab.customFood, label: Text("Custom Food"), icon: Icon(Icons.restaurant_menu)),
                ],
                selected: {_tab},
                onSelectionChanged: (selection) => _switchTab(selection.first),
              ),
              const SizedBox(height: 16),
              Expanded(child: _tab == FoodHubTab.logFood ? _buildDiary() : _buildCustomFoodBody()),
            ],
          ),
        ),
      ),
    );
  }

  // --- Log Food tab: the day's diary ---

  Widget _buildDiary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDayNav(),
        const SizedBox(height: 12),
        _buildSearchBar(),
        const SizedBox(height: 12),
        Expanded(child: _buildDayLog()),
      ],
    );
  }

  Widget _buildDayNav() {
    return Row(
      children: [
        IconButton(
          onPressed: _isLoadingDay ? null : _goToPreviousDay,
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Column(
            children: [
              Text(_dateLabel(_viewedDate), style: Theme.of(context).textTheme.titleMedium),
              Text(
                _isLoadingDay
                    ? "Loading..."
                    : "${(_dayTotals["calories"] as num).round()} kcal · "
                        "${(_dayTotals["protein"] as num).round()}g protein",
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _isLoadingDay || _isViewingToday ? null : _goToNextDay,
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return InkWell(
      onTap: _openSearch,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: AppColors.textSecondary),
            SizedBox(width: 12),
            Text("Search food", style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildDayLog() {
    if (_isLoadingDay && _entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.restaurant_outlined,
          title: _isViewingToday ? "Nothing logged yet today" : "Nothing logged this day",
          hint: _isViewingToday ? "Search or scan a food to start your day." : null,
        ),
      );
    }

    // Group entries under their meal, in the fixed Breakfast→Snack order, each
    // with a per-meal calorie subtotal.
    final byMeal = <String, List<Map<String, dynamic>>>{};
    for (final entry in _entries) {
      byMeal.putIfAbsent(entry["mealType"] as String, () => []).add(entry);
    }

    final children = <Widget>[];
    for (final mealKey in mealTypeLabels.keys) {
      final items = byMeal[mealKey];
      if (items == null || items.isEmpty) continue;
      final subtotal = items.fold<double>(0, (sum, e) => sum + (e["calories"] as num));
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(mealTypeLabels[mealKey]!, style: Theme.of(context).textTheme.titleSmall),
              Text("${subtotal.round()} kcal",
                  style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
      children.addAll(items.map(_buildEntryTile));
    }

    return RefreshIndicator(
      onRefresh: () => _loadDayLogs(_viewedDate),
      child: ListView(padding: EdgeInsets.zero, children: children),
    );
  }

  Widget _buildEntryTile(Map<String, dynamic> entry) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(entry["foodItem"]["name"] as String),
      subtitle: Text("${(entry["servingGrams"] as num).round()}g"),
      trailing: Text("${(entry["calories"] as num).round()} kcal"),
      onTap: () => _openEditLogEntryDialog(entry),
    );
  }

  // --- Custom Food tab ---

  Widget _buildCustomFoodBody() {
    if (_isLoadingCustom) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_customErrorMessage != null) {
      return Center(child: Text(_customErrorMessage!, style: const TextStyle(color: Colors.red)));
    }
    if (_customFoods.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.add_box_outlined,
          title: "No custom foods yet",
          hint: "Tap + to add a food that isn't in the list.",
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCustomFoods,
      child: ListView.builder(
        padding: EdgeInsets.zero,
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
                    child: CircleAvatar(backgroundImage: MemoryImage(base64Decode(photoBase64))),
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
