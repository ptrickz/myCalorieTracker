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

router.delete("/:id", async (req, res) => {
  const entry = await prisma.logEntry.findUnique({ where: { id: req.params.id } });

  if (!entry || entry.userId !== req.userId) {
    return res.status(404).json({ error: "Log entry not found" });
  }

  await prisma.logEntry.delete({ where: { id: req.params.id } });
  res.status(204).send();
});

module.exports = router;
