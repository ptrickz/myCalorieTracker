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

router.get("/mine", async (req, res) => {
  const foods = await prisma.foodItem.findMany({
    where: { createdByUserId: req.userId },
    orderBy: { name: "asc" },
  });

  res.json(foods);
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
  const { name, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g, barcode, photoBase64 } = req.body;

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
      photoBase64: photoBase64 || null,
      source: "CUSTOM",
      createdByUserId: req.userId,
    },
  });

  res.status(201).json(food);
});

router.patch("/:id", async (req, res) => {
  const food = await prisma.foodItem.findUnique({ where: { id: req.params.id } });

  if (!food || food.createdByUserId !== req.userId) {
    return res.status(404).json({ error: "Custom food not found" });
  }

  const { name, caloriesPer100g, proteinPer100g, carbsPer100g, fatPer100g, photoBase64 } = req.body;
  const data = {};

  if (name !== undefined) data.name = name;
  if (caloriesPer100g !== undefined) data.caloriesPer100g = caloriesPer100g;
  if (proteinPer100g !== undefined) data.proteinPer100g = proteinPer100g;
  if (carbsPer100g !== undefined) data.carbsPer100g = carbsPer100g;
  if (fatPer100g !== undefined) data.fatPer100g = fatPer100g;
  if (photoBase64 !== undefined) data.photoBase64 = photoBase64;

  const macrosChanged = ["caloriesPer100g", "proteinPer100g", "carbsPer100g", "fatPer100g"].some(
    (key) => data[key] !== undefined,
  );

  const updated = await prisma.foodItem.update({ where: { id: food.id }, data });

  if (macrosChanged) {
    const entries = await prisma.logEntry.findMany({ where: { foodItemId: food.id } });
    await prisma.$transaction(
      entries.map((entry) => {
        const scale = entry.servingGrams / 100;
        return prisma.logEntry.update({
          where: { id: entry.id },
          data: {
            calories: updated.caloriesPer100g * scale,
            protein: updated.proteinPer100g * scale,
            carbs: updated.carbsPer100g * scale,
            fat: updated.fatPer100g * scale,
          },
        });
      }),
    );
  }

  res.json(updated);
});

router.delete("/:id", async (req, res) => {
  const food = await prisma.foodItem.findUnique({ where: { id: req.params.id } });

  if (!food || food.createdByUserId !== req.userId) {
    return res.status(404).json({ error: "Custom food not found" });
  }

  // LogEntry.foodItemId is a required relation, so deleting a food that has
  // been logged would violate the foreign key. Block it with a clear error
  // instead of letting Postgres throw.
  const logCount = await prisma.logEntry.count({ where: { foodItemId: food.id } });
  if (logCount > 0) {
    return res.status(409).json({ error: "This food has logged entries and can't be deleted" });
  }

  await prisma.foodItem.delete({ where: { id: food.id } });
  res.status(204).send();
});

module.exports = router;
