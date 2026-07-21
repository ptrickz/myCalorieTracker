const express = require("express");
const prisma = require("../db");

const router = express.Router();

function dayBounds(dateString) {
  const start = new Date(`${dateString}T00:00:00.000Z`);
  const end = new Date(start);
  end.setUTCDate(end.getUTCDate() + 1);
  return { start, end };
}

router.get("/", async (req, res) => {
  const date = req.query.date || new Date().toISOString().slice(0, 10);
  const { start, end } = dayBounds(date);

  const entries = await prisma.logEntry.findMany({
    where: { userId: req.userId, loggedAt: { gte: start, lt: end } },
    orderBy: { loggedAt: "asc" },
    include: { foodItem: { select: { name: true } } },
  });

  const totals = entries.reduce(
    (acc, entry) => ({
      calories: acc.calories + entry.calories,
      protein: acc.protein + entry.protein,
      carbs: acc.carbs + entry.carbs,
      fat: acc.fat + entry.fat,
    }),
    { calories: 0, protein: 0, carbs: 0, fat: 0 }
  );

  res.json({ date, entries, totals });
});

function dateKey(date) {
  return date.toISOString().slice(0, 10);
}

function addDays(date, n) {
  const result = new Date(date);
  result.setUTCDate(result.getUTCDate() + n);
  return result;
}

router.get("/streak", async (req, res) => {
  const entries = await prisma.logEntry.findMany({
    where: { userId: req.userId },
    select: { loggedAt: true },
  });

  const loggedDays = new Set(entries.map((entry) => dateKey(entry.loggedAt)));

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  const loggedToday = loggedDays.has(dateKey(today));

  // Grace period: if today hasn't been logged yet, the streak isn't broken
  // until the day is actually over — start counting from yesterday instead.
  let cursor = loggedToday ? today : addDays(today, -1);
  let currentStreak = 0;
  while (loggedDays.has(dateKey(cursor))) {
    currentStreak++;
    cursor = addDays(cursor, -1);
  }

  const sortedDays = [...loggedDays].sort();
  let longestStreak = 0;
  let run = 0;
  let prevDay = null;
  for (const dayStr of sortedDays) {
    const day = new Date(`${dayStr}T00:00:00.000Z`);
    run = prevDay && addDays(prevDay, 1).getTime() === day.getTime() ? run + 1 : 1;
    longestStreak = Math.max(longestStreak, run);
    prevDay = day;
  }

  res.json({ currentStreak, longestStreak, loggedToday });
});

// Per-day calorie/protein totals for the last N days (default 7), oldest
// first and zero-filled, so the client can render a fixed-width trend chart
// without gap handling.
router.get("/range", async (req, res) => {
  const days = Math.min(Math.max(Number(req.query.days) || 7, 1), 90);

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);
  const start = addDays(today, -(days - 1));
  const end = addDays(today, 1);

  const entries = await prisma.logEntry.findMany({
    where: { userId: req.userId, loggedAt: { gte: start, lt: end } },
    select: { loggedAt: true, calories: true, protein: true },
  });

  const totalsByDay = new Map();
  for (const entry of entries) {
    const key = dateKey(entry.loggedAt);
    const totals = totalsByDay.get(key) || { calories: 0, protein: 0 };
    totals.calories += entry.calories;
    totals.protein += entry.protein;
    totalsByDay.set(key, totals);
  }

  const result = [];
  for (let i = 0; i < days; i++) {
    const key = dateKey(addDays(start, i));
    const totals = totalsByDay.get(key) || { calories: 0, protein: 0 };
    result.push({ date: key, calories: totals.calories, protein: totals.protein });
  }

  res.json({ days: result });
});

// Past days that have entries for a given meal, newest first — the source
// list for "repeat a previous meal".
router.get("/recent-meals", async (req, res) => {
  const mealType = req.query.mealType;
  if (!mealType) {
    return res.status(400).json({ error: "mealType is required" });
  }
  const limit = Math.min(Math.max(Number(req.query.limit) || 5, 1), 20);

  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  // Look back far enough to fill `limit` days for someone who logs sparsely.
  const entries = await prisma.logEntry.findMany({
    where: {
      userId: req.userId,
      mealType,
      loggedAt: { gte: addDays(today, -60), lt: today },
    },
    orderBy: { loggedAt: "desc" },
    include: { foodItem: { select: { name: true } } },
  });

  const byDay = new Map();
  for (const entry of entries) {
    const key = dateKey(entry.loggedAt);
    if (!byDay.has(key)) {
      byDay.set(key, { date: key, calories: 0, protein: 0, entries: [] });
    }
    const day = byDay.get(key);
    day.calories += entry.calories;
    day.protein += entry.protein;
    day.entries.push({
      foodItemId: entry.foodItemId,
      name: entry.foodItem.name,
      servingGrams: entry.servingGrams,
    });
  }

  res.json({ meals: [...byDay.values()].slice(0, limit) });
});

// Copies a past day's meal onto today. Macros are recomputed from each food's
// current per-100g values rather than copied, so an edited food stays correct.
router.post("/repeat-meal", async (req, res) => {
  const { date, mealType } = req.body;

  if (!date || !mealType) {
    return res.status(400).json({ error: "date and mealType are required" });
  }

  const { start, end } = dayBounds(date);
  const source = await prisma.logEntry.findMany({
    where: { userId: req.userId, mealType, loggedAt: { gte: start, lt: end } },
  });

  if (source.length === 0) {
    return res.status(404).json({ error: "No entries found for that meal" });
  }

  const foodItems = await prisma.foodItem.findMany({
    where: { id: { in: [...new Set(source.map((e) => e.foodItemId))] } },
  });
  const foodById = new Map(foodItems.map((f) => [f.id, f]));

  const now = new Date();
  const created = await prisma.$transaction(
    source.flatMap((entry) => {
      const food = foodById.get(entry.foodItemId);
      // Skip anything whose food has since been deleted.
      if (!food) return [];
      const scale = entry.servingGrams / 100;
      return prisma.logEntry.create({
        data: {
          userId: req.userId,
          foodItemId: entry.foodItemId,
          servingGrams: entry.servingGrams,
          mealType,
          loggedAt: now,
          calories: food.caloriesPer100g * scale,
          protein: food.proteinPer100g * scale,
          carbs: food.carbsPer100g * scale,
          fat: food.fatPer100g * scale,
        },
      });
    }),
  );

  res.status(201).json({ created: created.length });
});

router.post("/", async (req, res) => {
  const { foodItemId, servingGrams, mealType, loggedAt } = req.body;

  if (!foodItemId || !servingGrams || !mealType) {
    return res.status(400).json({ error: "foodItemId, servingGrams, and mealType are required" });
  }

  const foodItem = await prisma.foodItem.findUnique({ where: { id: foodItemId } });
  if (!foodItem) {
    return res.status(404).json({ error: "Food item not found" });
  }

  const scale = servingGrams / 100;
  const entry = await prisma.logEntry.create({
    data: {
      userId: req.userId,
      foodItemId,
      servingGrams,
      mealType,
      loggedAt: loggedAt ? new Date(loggedAt) : new Date(),
      calories: foodItem.caloriesPer100g * scale,
      protein: foodItem.proteinPer100g * scale,
      carbs: foodItem.carbsPer100g * scale,
      fat: foodItem.fatPer100g * scale,
    },
    include: { foodItem: { select: { name: true } } },
  });

  res.status(201).json(entry);
});

router.patch("/:id", async (req, res) => {
  const entry = await prisma.logEntry.findUnique({ where: { id: req.params.id } });

  if (!entry || entry.userId !== req.userId) {
    return res.status(404).json({ error: "Log entry not found" });
  }

  const { servingGrams, mealType } = req.body;
  const data = {};

  if (mealType !== undefined) data.mealType = mealType;

  if (servingGrams !== undefined) {
    const foodItem = await prisma.foodItem.findUnique({ where: { id: entry.foodItemId } });
    const scale = servingGrams / 100;
    data.servingGrams = servingGrams;
    data.calories = foodItem.caloriesPer100g * scale;
    data.protein = foodItem.proteinPer100g * scale;
    data.carbs = foodItem.carbsPer100g * scale;
    data.fat = foodItem.fatPer100g * scale;
  }

  const updated = await prisma.logEntry.update({
    where: { id: req.params.id },
    data,
    include: { foodItem: { select: { name: true } } },
  });

  res.json(updated);
});

router.delete("/:id", async (req, res) => {
  const entry = await prisma.logEntry.findUnique({ where: { id: req.params.id } });

  if (!entry || entry.userId !== req.userId) {
    return res.status(404).json({ error: "Log entry not found" });
  }

  await prisma.logEntry.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;
