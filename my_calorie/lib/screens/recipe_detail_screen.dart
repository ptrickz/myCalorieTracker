import "package:flutter/material.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../theme.dart";
import "../widgets/app_toast.dart";
import "../widgets/background_image_body.dart";
import "recipe_log_sheet.dart";

/// The full recipe: what goes in it, how it's made, and what one serving costs
/// against the day's targets.
class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  final _apiService = ApiService();
  final _authStorage = AuthStorage();

  /// True once a serving has been logged, so the Food page knows to refresh
  /// its diary when this screen pops.
  bool _didLog = false;

  Future<void> _log() async {
    final logged = await showRecipeLogSheet(context, widget.recipe);
    if (logged && mounted) setState(() => _didLog = true);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete recipe?"),
        content: Text("\"${widget.recipe["name"]}\" will be removed. "
            "Servings you've already logged stay in your diary."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final token = await _authStorage.readToken();
      await _apiService.deleteRecipe(token!, widget.recipe["id"] as String);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppToast.show(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final macros = recipe["macrosPerServing"] as Map<String, dynamic>;
    final ingredients = (recipe["ingredients"] as List).cast<String>();
    final steps = (recipe["steps"] as List).cast<String>();
    final sourceName = recipe["sourceName"] as String?;
    // Seeded recipes have no owner and aren't the user's to remove.
    final isOwned = recipe["createdByUserId"] != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_didLog);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(recipe["name"] as String),
          actions: [
            if (isOwned)
              IconButton(
                onPressed: _confirmDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: "Delete",
              ),
          ],
        ),
        body: BackgroundImageBody(
          imagePath: "assets/img/food.png",
          child: ListView(
            padding: EdgeInsets.fromLTRB(
                24, MediaQuery.of(context).padding.top + kToolbarHeight + 8, 24, 100),
            children: [
              _MacroSummary(macros: macros, servings: recipe["servings"] as int),
              if (sourceName != null) ...[
                const SizedBox(height: 12),
                Text(
                  "Source: $sourceName",
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
              const SizedBox(height: 24),
              if (ingredients.isNotEmpty) ...[
                Text("Ingredients", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final line in ingredients)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("•  ", style: TextStyle(color: AppColors.textSecondary)),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
              ],
              if (steps.isNotEmpty) ...[
                Text("Steps", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            "${i + 1}.",
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(child: Text(steps[i])),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _log,
          icon: const Icon(Icons.add),
          label: const Text("Log this"),
        ),
      ),
    );
  }
}

class _MacroSummary extends StatelessWidget {
  final Map<String, dynamic> macros;
  final int servings;

  const _MacroSummary({required this.macros, required this.servings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Per serving · makes $servings",
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Macro(label: "kcal", value: macros["calories"] as num),
              _Macro(label: "protein", value: macros["protein"] as num, unit: "g"),
              _Macro(label: "carbs", value: macros["carbs"] as num, unit: "g"),
              _Macro(label: "fat", value: macros["fat"] as num, unit: "g"),
            ],
          ),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final num value;
  final String unit;

  const _Macro({required this.label, required this.value, this.unit = ""});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          "${value.round()}$unit",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
