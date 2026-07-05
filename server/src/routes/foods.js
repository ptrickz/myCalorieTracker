const express = require("express");
const prisma = require("../db");

const router = express.Router();

router.get("/", async (req, res) => {
  const { search } = req.query;

  const foods = await prisma.foodItem.findMany({
    where: search ? { name: { contains: search, mode: "insensitive" } } : undefined,
    orderBy: { name: "asc" },
    take: 50,
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
