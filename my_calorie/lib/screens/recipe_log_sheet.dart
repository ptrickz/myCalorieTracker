import "package:flutter/cupertino.dart";
import "package:flutter/material.dart";
import "../constants.dart";
import "../services/api_service.dart";
import "../services/auth_storage.dart";
import "../theme.dart";
import "../widgets/app_toast.dart";

String _mealTypeForNow() {
  final hour = DateTime.now().hour;
  if (hour < 11) return "BREAKFAST";
  if (hour < 15) return "LUNCH";
  if (hour < 21) return "DINNER";
  return "SNACK";
}

/// Asks which meal the servings belong to, then writes the entry. Returns true
/// when something was logged, so the caller can refresh its diary.
///
/// No time picker here: "Log this" means now, and leaving loggedAt off lets the
/// server stamp the entry itself.
Future<bool> showRecipeLogSheet(BuildContext context, Map<String, dynamic> recipe) async {
  final macros = recipe["macrosPerServing"] as Map<String, dynamic>;
  var mealType = _mealTypeForNow();
  var servings = 1.0;

  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final calories = (macros["calories"] as num) * servings;
        final protein = (macros["protein"] as num) * servings;

        return CupertinoAlertDialog(
          title: Text(recipe["name"] as String),
          content: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: mealType,
                    decoration: const InputDecoration(labelText: "Meal"),
                    items: mealTypeLabels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (value) => setDialogState(() => mealType = value!),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Servings"),
                      Row(
                        children: [
                          IconButton(
                            onPressed: servings <= 0.5
                                ? null
                                : () => setDialogState(() => servings -= 0.5),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            servings == servings.roundToDouble()
                                ? servings.round().toString()
                                : servings.toString(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            onPressed: servings >= 10
                                ? null
                                : () => setDialogState(() => servings += 0.5),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${calories.round()} kcal · ${protein.round()}g protein",
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
              child: const Text("Log"),
            ),
          ],
        );
      },
    ),
  );

  if (confirmed != true || !context.mounted) return false;

  try {
    final token = await AuthStorage().readToken();
    await ApiService().logRecipe(
      token!,
      recipe["id"] as String,
      mealType: mealType,
      servings: servings,
    );
    if (!context.mounted) return true;
    AppToast.show(
      context,
      "Logged ${recipe["name"]} to ${mealTypeLabels[mealType]}",
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    AppToast.show(context, e.toString());
    return false;
  }
}
