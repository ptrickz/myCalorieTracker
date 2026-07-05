const express = require("express");
const prisma = require("../db");

const router = express.Router();

router.get("/", async (req, res) => {
  const logs = await prisma.weightLog.findMany({
    where: { userId: req.userId },
    orderBy: { recordedAt: "asc" },
  });
  res.json(logs);
});

router.post("/", async (req, res) => {
  const { weightKg, recordedAt } = req.body;

  if (!weightKg) {
    return res.status(400).json({ error: "weightKg is required" });
  }

  const log = await prisma.weightLog.create({
    data: {
      userId: req.userId,
      weightKg,
      recordedAt: recordedAt ? new Date(recordedAt) : new Date(),
    },
  });

  res.status(201).json(log);
});

module.exports = router;
