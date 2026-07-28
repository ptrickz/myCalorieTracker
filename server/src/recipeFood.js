const prisma = require("./db");

// Logging a recipe serving records absolute macros, but LogEntry still needs a
// FoodItem — so each recipe gets one stand-in food, created the first time a
// serving is logged. It exists to carry the recipe's name into the diary; its
// per-100g values stay zero because a serving has no known gram weight (the
// entry holds the macros, exactly as quick-add does).
//
// These are marked source RECIPE and filtered out of every food picker, the
// same way the quick-add placeholder is.
async function ensureRecipeFood(recipe) {
  const existing = await prisma.foodItem.findUnique({ where: { recipeId: recipe.id } });
  if (existing) {
    // Keep the diary honest if the recipe was renamed after its first log.
    if (existing.name === recipe.name) return existing;
    return prisma.foodItem.update({ where: { id: existing.id }, data: { name: recipe.name } });
  }

  return prisma.foodItem.create({
    data: {
      name: recipe.name,
      caloriesPer100g: 0,
      proteinPer100g: 0,
      carbsPer100g: 0,
      fatPer100g: 0,
      source: "RECIPE",
      createdByUserId: null,
      recipeId: recipe.id,
    },
  });
}

module.exports = { ensureRecipeFood };
