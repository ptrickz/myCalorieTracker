const prisma = require("./db");

// Quick-add entries log a bare calorie/macro amount with no reusable food, but
// LogEntry requires a foodItem — so they all attach to this single global
// placeholder. It's created lazily, owned by no user, and deliberately kept
// out of every food picker (see routes/foods.js).
const QUICK_ADD_NAME = "Quick add";

async function ensureQuickAddFood() {
  const existing = await prisma.foodItem.findFirst({
    where: { name: QUICK_ADD_NAME, createdByUserId: null, source: "CUSTOM" },
  });
  if (existing) return existing;
  return prisma.foodItem.create({
    data: {
      name: QUICK_ADD_NAME,
      caloriesPer100g: 0,
      proteinPer100g: 0,
      carbsPer100g: 0,
      fatPer100g: 0,
      source: "CUSTOM",
      createdByUserId: null,
    },
  });
}

module.exports = { ensureQuickAddFood, QUICK_ADD_NAME };
