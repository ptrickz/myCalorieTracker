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
  // Seeded from the clock rather than always "Breakfast", and deliberately not
  // reset after a log so a run of dinner items only needs picking once.
  String _mealType = _mealTypeForNow();

  static String _mealTypeForNow() {
    final hour = DateTime.now().hour;
    if (hour < 11) return "BREAKFAST";
    if (hour < 16) return "LUNCH";
    if (hour < 21) return "DINNER";
    return "SNACK";
  }
  bool _isSearching = false;
  bool _isLogging = false;
  // Id of the food currently being one-tap logged, so its row can show a
  // spinner and repeat taps are ignored.
  String? _quickLoggingFoodId;
  // Past days that have the selected meal, so "repeat" only appears when
  // there's actually something to repeat.
  List<Map<String, dynamic>> _recentMeals = const [];
  String? _errorMessage;
  Timer? _debounce;

  // Custom Food state
  bool _isLoadingCustom = true;
  String? _customErrorMessage;
  List<Map<String, dynamic>> _customFoods = const [];

  // Day log state (moved here from the Dashboard): the browsable per-day
  // entry list shown above the sub-tabs.
  bool _isLoadingDay = false;
  Map<String, dynamic> _dayTotals = const {
    "calories": 0,
    "protein": 0,
    "carbs": 0,
    "fat": 0,
  };
  List<Map<String, dynamic>> _entries = const [];
  DateTime _viewedDate = DateTime.now();

  bool get _isViewingToday => _dateKey(_viewedDate) == _dateKey(DateTime.now());

  String _dateKey(DateTime date) =>
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  String _dateLabel(DateTime date) {
    if (_isViewingToday) return "Today's log";
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (_dateKey(date) == _dateKey(yesterday)) return "Yesterday's log";
    return "Log for ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  @override
  void initState() {
    super.initState();
    _loadFoods();
    _loadCustomFoods();
    _loadDayLogs(DateTime.now());
    _loadRecentMeals();
  }

  Future<void> _loadRecentMeals() async {
    try {
      final token = await _authStorage.readToken();
      final meals = await _apiService.getRecentMeals(token!, _mealType);
      if (mounted) setState(() => _recentMeals = meals);
    } catch (_) {
      // Repeating is a convenience — if it can't load, just hide the button.
      if (mounted) setState(() => _recentMeals = const []);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Called by HomeShell after the FAB's CreateFoodScreen push returns.
  Future<void> refreshAfterCreate() => _loadCustomFoods();

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

  void _goToPreviousDay() =>
      _loadDayLogs(_viewedDate.subtract(const Duration(days: 1)));

  void _goToNextDay() {
    if (_isViewingToday) return;
    _loadDayLogs(_viewedDate.add(const Duration(days: 1)));
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
          // Material ancestor for the dropdown, which Cupertino dialogs
          // don't provide on their own.
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
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => mealType = value!),
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
      _loadDayLogs(_viewedDate);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

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
      });
      _loadFoods();
      _loadDayLogs(_viewedDate);
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

  /// Copies a whole past meal onto today in one tap — the common case for
  /// anyone who eats much the same breakfast every day.
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
      _loadFoods();
      _loadDayLogs(_viewedDate);
      _loadRecentMeals();
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  /// Logs a food in one tap, reusing the serving last used for it (100g if it
  /// has never been logged) and whichever meal is currently selected.
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
      _loadFoods();
      _loadDayLogs(_viewedDate);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    } finally {
      if (mounted) setState(() => _quickLoggingFoodId = null);
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

    final saved = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => CupertinoAlertDialog(
          title: const Text("Edit custom food"),
          // Material ancestor for the photo picker, which Cupertino dialogs
          // don't provide on their own.
          content: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FoodPhotoPicker(
                    photoBase64: photoBase64,
                    onChanged: (value) =>
                        setDialogState(() => photoBase64 = value),
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
      // Static app bar: this page's only scrollable is the inner results
      // list, so hide-on-scroll would fire on a list that isn't the page.
      appBar: AppBar(title: const Text("Food")),
      body: BackgroundImageBody(
        imagePath: "assets/img/food.png",
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              24, MediaQuery.of(context).padding.top + kToolbarHeight + 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDayLogSection(),
              const SizedBox(height: 16),
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

  // --- Day log (above the sub-tabs) ---

  Widget _buildDayLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: _isLoadingDay ? null : _goToPreviousDay,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    _dateLabel(_viewedDate),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    "${(_dayTotals["calories"] as num).round()} kcal · ${(_dayTotals["protein"] as num).round()}g protein",
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _isLoadingDay || _isViewingToday ? null : _goToNextDay,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (_isLoadingDay)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _isViewingToday
                  ? "Nothing logged yet today."
                  : "Nothing logged this day.",
              textAlign: TextAlign.center,
            ),
          )
        else
          // Capped so long days don't crowd out the log/search tabs below.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView(
              // Without this the list absorbs the ambient safe-area padding
              // (app-bar height, since the body extends behind it) as blank
              // space above the first entry.
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                ..._entries.map(
                  (entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry["foodItem"]["name"] as String),
                    subtitle: Text(
                      "${entry["mealType"]} · ${(entry["servingGrams"] as num).round()}g",
                    ),
                    trailing: Text(
                      "${(entry["calories"] as num).round()} kcal",
                    ),
                    onTap: () => _openEditLogEntryDialog(entry),
                  ),
                ),
              ],
            ),
          ),
      ],
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
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _searchController,
                placeholder: "Search foods",
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
            // Without this the list absorbs the ambient safe-area padding
            // (app-bar height, since the body extends behind it) as a gap
            // above the first section.
            padding: EdgeInsets.zero,
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

  /// Meal picked once, up front, and kept — so logging several dinner items
  /// doesn't mean choosing "Dinner" over and over.
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
              side: BorderSide(
                color: isSelected ? AppColors.accent : AppColors.border,
              ),
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
    // For a food you've logged before, what it'll actually cost you is more
    // useful than the per-100g unit price.
    final subtitle = lastServing == null
        ? "${perHundred.round()} kcal / 100g"
        : "${(perHundred * lastServing / 100).round()} kcal · ${lastServing.round()}g";
    final isQuickLogging = _quickLoggingFoodId == food["id"];

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
      subtitle: Text(subtitle),
      trailing: IconButton(
        icon: isQuickLogging
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
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
        Text(
          _selectedFood!["name"] as String,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _servingController,
          keyboardType: TextInputType.number,
          placeholder: "Serving size (grams)",
        ),
        const SizedBox(height: 12),
        // Meal is chosen on the search screen and carried through, so this
        // step only needs to show which one it'll land in.
        _buildMealSelector(),
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
    if (_isLoadingCustom) {
      return const Center(child: CircularProgressIndicator());
    }
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
