const express = require("express");
const prisma = require("../db");

const router = express.Router();

router.get("/", async (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 20, 100);

  const logs = await prisma.workoutLog.findMany({
    where: { userId: req.userId },
    orderBy: { loggedAt: "desc" },
    take: limit,
    include: { sets: { include: { exercise: true }, orderBy: { completedAt: "asc" } } },
  });

  res.json(logs);
});

router.post("/", async (req, res) => {
  const { venue, notes, loggedAt } = req.body;

  if (!venue) {
    return res.status(400).json({ error: "venue is required" });
  }

  // Optional so a session missed on the day can be backfilled; omitted means
  // "now" via the schema default.
  let loggedAtDate;
  if (loggedAt !== undefined) {
    loggedAtDate = new Date(loggedAt);
    if (Number.isNaN(loggedAtDate.getTime())) {
      return res.status(400).json({ error: "loggedAt must be a valid date" });
    }
  }

  const log = await prisma.workoutLog.create({
    data: {
      userId: req.userId,
      venue,
      notes: notes || null,
      ...(loggedAtDate ? { loggedAt: loggedAtDate } : {}),
    },
  });

  res.status(201).json(log);
});

router.get("/:id", async (req, res) => {
  const log = await prisma.workoutLog.findUnique({
    where: { id: req.params.id },
    include: { sets: { include: { exercise: true }, orderBy: { completedAt: "asc" } } },
  });

  if (!log || log.userId !== req.userId) {
    return res.status(404).json({ error: "Workout log not found" });
  }

  res.json(log);
});

router.post("/:id/sets", async (req, res) => {
  const log = await prisma.workoutLog.findUnique({ where: { id: req.params.id } });

  if (!log || log.userId !== req.userId) {
    return res.status(404).json({ error: "Workout log not found" });
  }

  const { exerciseId, setNumber, reps, weightKg, durationSeconds } = req.body;

  if (!exerciseId || !setNumber) {
    return res.status(400).json({ error: "exerciseId and setNumber are required" });
  }

  const set = await prisma.workoutSetLog.create({
    data: {
      workoutLogId: log.id,
      exerciseId,
      setNumber,
      reps: reps ?? null,
      weightKg: weightKg ?? null,
      durationSeconds: durationSeconds ?? null,
    },
    include: { exercise: true },
  });

  res.status(201).json(set);
});

router.delete("/:id", async (req, res) => {
  const log = await prisma.workoutLog.findUnique({ where: { id: req.params.id } });

  if (!log || log.userId !== req.userId) {
    return res.status(404).json({ error: "Workout log not found" });
  }

  await prisma.workoutSetLog.deleteMany({ where: { workoutLogId: log.id } });
  await prisma.workoutLog.delete({ where: { id: log.id } });
  res.status(204).send();
});

router.delete("/:id/sets/:setId", async (req, res) => {
  const log = await prisma.workoutLog.findUnique({ where: { id: req.params.id } });

  if (!log || log.userId !== req.userId) {
    return res.status(404).json({ error: "Workout log not found" });
  }

  const set = await prisma.workoutSetLog.findUnique({ where: { id: req.params.setId } });
  if (!set || set.workoutLogId !== log.id) {
    return res.status(404).json({ error: "Set not found" });
  }

  await prisma.workoutSetLog.delete({ where: { id: set.id } });
  res.status(204).send();
});

module.exports = router;
