const express = require("express");
const prisma = require("../db");

const router = express.Router();

router.get("/", async (req, res) => {
  const search = req.query.search?.trim();

  if (search) {
    const foods = await prisma.foodItem.findMany({
      where: { name: { contains: search, mode: "insensitive" } },
      orderBy: { name: "asc" },
      take: 50,
    });
    return res.json(foods);
  }

  // No search query: this is the screen's default view, so surface the
  // user's recently-logged foods first (for one-tap re-logging), then fill
  // the rest of the list up to 20 with other available foods.
  const recentLogEntries = await prisma.logEntry.findMany({
    where: { userId: req.userId },
    orderBy: { loggedAt: "desc" },
    select: { foodItemId: true },
    distinct: ["foodItemId"],
    take: 20,
  });

  const recentFoodIds = recentLogEntries.map((entry) => entry.foodItemId);
  const recentFoods = recentFoodIds.length
    ? await prisma.foodItem.findMany({ where: { id: { in: recentFoodIds } } })
    : [];

  // Prisma's `in` filter doesn't preserve order, so re-sort to match recency.
  const foodById = new Map(recentFoods.map((food) => [food.id, food]));
  const orderedRecentFoods = recentFoodIds.map((id) => foodById.get(id)).filter(Boolean);

  const remainingSlots = 20 - orderedRecentFoods.length;
  const otherFoods = remainingSlots > 0
    ? await prisma.foodItem.findMany({
        where: recentFoodIds.length ? { id: { notIn: recentFoodIds } } : undefined,
        orderBy: { name: "asc" },
        take: remainingSlots,
      })
    : [];

  res.json([
    ...orderedRecentFoods.map((food) => ({ ...food, isRecent: true })),
    ...otherFoods.map((food) => ({ ...food, isRecent: false })),
  ]);
});

router.get("/barcode/:barcode", async (req, res) => {
  const food = await prisma.foodItem.findUnique({
    where: { barcode: req.params.barcode },
  });

  if (!food) {
    return res.status(404).json({ error: "No food found for this barcode" });
  }

  res.json(food);
});

router.post("/", async (req, res) => {
  const { name, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g, barcode } = req.body;

  if (!name || caloriesPer100g == null || proteinPer100g == null || carbsPer100g == null || fatPer100g == null) {
    return res.status(400).json({
      error: "name, caloriesPer100g, proteinPer100g, carbsPer100g, and fatPer100g are required",
    });
  }

  const food = await prisma.foodItem.create({
    data: {
      name,
      caloriesPer100g,
      proteinPer100g,
      carbsPer100g,
      fatPer100g,
      barcode: barcode || null,
      source: "CUSTOM",
      createdByUserId: req.userId,
    },
  });

  res.status(201).json(food);
});

module.exports = router;
