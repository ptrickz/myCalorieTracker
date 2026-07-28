const express = require("express");
const prisma = require("../db");
const { ensureRecipeFood } = require("../recipeFood");

const router = express.Router();

// The four per-serving columns travel to the client as one object, which is
// how the app thinks about them; they're stored flat to stay queryable and to
// match FoodItem's per-100g columns.
function toClient(recipe) {
  const {
    caloriesPerServing, proteinPerServing, carbsPerServing, fatPerServing, ...rest
  } = recipe;
  return {
    ...rest,
    macrosPerServing: {
      calories: caloriesPerServing,
      protein: proteinPerServing,
      carbs: carbsPerServing,
      fat: fatPerServing,
    },
  };
}

// Accepts macros either nested under macrosPerServing or flat, so a hand-rolled
// request isn't picky. Returns an error string, or null when valid.
function readMacros(body, into) {
  const macros = body.macrosPerServing ?? body;
  const fields = [
    ["calories", "caloriesPerServing"],
    ["protein", "proteinPerServing"],
    ["carbs", "carbsPerServing"],
    ["fat", "fatPerServing"],
  ];

  for (const [key, column] of fields) {
    const value = macros[key] ?? body[column];
    if (value === undefined) {
      if (key === "calories") return "macrosPerServing.calories is required";
      into[column] = 0;
      continue;
    }
    if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
      return `macrosPerServing.${key} must be a non-negative number`;
    }
    into[column] = value;
  }

  if (!(into.caloriesPerServing > 0)) {
    return "macrosPerServing.calories must be a positive number";
  }
  return null;
}

// Ingredients and steps are plain string lists; drop blanks so a trailing
// newline in a text field doesn't become an empty bullet.
function readLines(value, label) {
  if (value === undefined) return { value: undefined, error: null };
  if (!Array.isArray(value) || value.some((line) => typeof line !== "string")) {
    return { value: undefined, error: `${label} must be an array of strings` };
  }
  return { value: value.map((line) => line.trim()).filter(Boolean), error: null };
}

router.get("/", async (req, res) => {
  const search = req.query.search?.trim();

  const recipes = await prisma.recipe.findMany({
    where: search ? { name: { contains: search, mode: "insensitive" } } : undefined,
    orderBy: { name: "asc" },
    take: 100,
  });

  res.json(recipes.map(toClient));
});

router.get("/:id", async (req, res) => {
  const recipe = await prisma.recipe.findUnique({ where: { id: req.params.id } });
  if (!recipe) return res.status(404).json({ error: "Recipe not found" });
  res.json(toClient(recipe));
});

router.post("/", async (req, res) => {
  const { name, servings, ingredients, steps, sourceName } = req.body;

  if (typeof name !== "string" || !name.trim()) {
    return res.status(400).json({ error: "name is required" });
  }
  if (servings !== undefined && (!Number.isInteger(servings) || servings < 1)) {
    return res.status(400).json({ error: "servings must be a positive whole number" });
  }

  const ingredientLines = readLines(ingredients, "ingredients");
  if (ingredientLines.error) return res.status(400).json({ error: ingredientLines.error });
  const stepLines = readLines(steps, "steps");
  if (stepLines.error) return res.status(400).json({ error: stepLines.error });

  const macros = {};
  const macroError = readMacros(req.body, macros);
  if (macroError) return res.status(400).json({ error: macroError });

  const recipe = await prisma.recipe.create({
    data: {
      name: name.trim(),
      servings: servings ?? 1,
      ingredients: ingredientLines.value ?? [],
      steps: stepLines.value ?? [],
      sourceName: typeof sourceName === "string" && sourceName.trim() ? sourceName.trim() : null,
      createdByUserId: req.userId,
      ...macros,
    },
  });

  res.status(201).json(toClient(recipe));
});

router.patch("/:id", async (req, res) => {
  const recipe = await prisma.recipe.findUnique({ where: { id: req.params.id } });
  if (!recipe) return res.status(404).json({ error: "Recipe not found" });
  // Seeded recipes (no owner) are shared reference data, not the user's to edit.
  if (recipe.createdByUserId !== req.userId) {
    return res.status(403).json({ error: "This recipe can't be edited" });
  }

  const { name, servings, ingredients, steps } = req.body;
  const data = {};

  if (name !== undefined) {
    if (typeof name !== "string" || !name.trim()) {
      return res.status(400).json({ error: "name must not be empty" });
    }
    data.name = name.trim();
  }
  if (servings !== undefined) {
    if (!Number.isInteger(servings) || servings < 1) {
      return res.status(400).json({ error: "servings must be a positive whole number" });
    }
    data.servings = servings;
  }

  if (ingredients !== undefined) {
    const lines = readLines(ingredients, "ingredients");
    if (lines.error) return res.status(400).json({ error: lines.error });
    data.ingredients = lines.value;
  }
  if (steps !== undefined) {
    const lines = readLines(steps, "steps");
    if (lines.error) return res.status(400).json({ error: lines.error });
    data.steps = lines.value;
  }

  if (req.body.macrosPerServing !== undefined || req.body.caloriesPerServing !== undefined) {
    const macros = {};
    const macroError = readMacros(req.body, macros);
    if (macroError) return res.status(400).json({ error: macroError });
    Object.assign(data, macros);
  }

  const updated = await prisma.recipe.update({ where: { id: recipe.id }, data });

  // The stand-in food mirrors the recipe's name; refresh it if one exists.
  if (data.name) {
    const backing = await prisma.foodItem.findUnique({ where: { recipeId: recipe.id } });
    if (backing) {
      await prisma.foodItem.update({ where: { id: backing.id }, data: { name: data.name } });
    }
  }

  res.json(toClient(updated));
});

router.delete("/:id", async (req, res) => {
  const recipe = await prisma.recipe.findUnique({ where: { id: req.params.id } });
  if (!recipe) return res.status(404).json({ error: "Recipe not found" });
  if (recipe.createdByUserId !== req.userId) {
    return res.status(403).json({ error: "This recipe can't be deleted" });
  }

  // Past log entries keep their own macro snapshot, so they survive this; the
  // backing food is only detached from the recipe, never removed, because
  // those entries still point at it.
  const backing = await prisma.foodItem.findUnique({ where: { recipeId: recipe.id } });
  if (backing) {
    await prisma.foodItem.update({ where: { id: backing.id }, data: { recipeId: null } });
  }
  await prisma.recipe.delete({ where: { id: recipe.id } });

  res.status(204).send();
});

// Logs one serving (or `servings` of them) as a diary entry. Macros are copied
// from the recipe rather than referenced, so later edits to the recipe don't
// rewrite history — the same snapshot rule normal food entries follow.
router.post("/:id/log", async (req, res) => {
  const recipe = await prisma.recipe.findUnique({ where: { id: req.params.id } });
  if (!recipe) return res.status(404).json({ error: "Recipe not found" });

  const { mealType, loggedAt } = req.body;
  if (!mealType) return res.status(400).json({ error: "mealType is required" });

  const servings = req.body.servings ?? 1;
  if (typeof servings !== "number" || !Number.isFinite(servings) || servings <= 0) {
    return res.status(400).json({ error: "servings must be a positive number" });
  }

  let loggedAtDate;
  if (loggedAt !== undefined) {
    loggedAtDate = new Date(loggedAt);
    if (Number.isNaN(loggedAtDate.getTime())) {
      return res.status(400).json({ error: "loggedAt must be a valid date" });
    }
  }

  const food = await ensureRecipeFood(recipe);
  const entry = await prisma.logEntry.create({
    data: {
      userId: req.userId,
      foodItemId: food.id,
      // Zero serving marks an entry whose macros are absolute rather than
      // scaled from a per-100g food, matching how quick-add entries are stored.
      servingGrams: 0,
      mealType,
      loggedAt: loggedAtDate ?? new Date(),
      calories: recipe.caloriesPerServing * servings,
      protein: recipe.proteinPerServing * servings,
      carbs: recipe.carbsPerServing * servings,
      fat: recipe.fatPerServing * servings,
    },
    include: { foodItem: { select: { name: true } } },
  });

  res.status(201).json(entry);
});

module.exports = router;
