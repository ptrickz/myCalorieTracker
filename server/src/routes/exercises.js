const express = require("express");
const prisma = require("../db");

const router = express.Router();

router.get("/", async (req, res) => {
  const dayTag = req.query.dayTag;

  const exercises = await prisma.exercise.findMany({
    where: dayTag ? { dayTag } : undefined,
    orderBy: { name: "asc" },
  });

  res.json(exercises);
});

router.post("/", async (req, res) => {
  const { name, formCue, defaultSets, defaultReps, videoUrl, imageUrl } = req.body;

  if (!name) {
    return res.status(400).json({ error: "name is required" });
  }

  const exercise = await prisma.exercise.create({
    data: {
      name,
      formCue: formCue || null,
      defaultSets: Number.isInteger(defaultSets) && defaultSets > 0 ? defaultSets : null,
      defaultReps: typeof defaultReps === "string" && defaultReps.trim() ? defaultReps.trim() : null,
      videoUrl: videoUrl || null,
      imageUrl: imageUrl || null,
      createdByUserId: req.userId,
    },
  });

  res.status(201).json(exercise);
});

// Simple rule-based progression suggestion from the user's own history for
// this exercise — no AI needed. +2.5kg if weighted, +1 rep if bodyweight,
// +5 sec if a timed hold.
router.get("/:id/progression", async (req, res) => {
  const lastSet = await prisma.workoutSetLog.findFirst({
    where: { exerciseId: req.params.id, workoutLog: { userId: req.userId } },
    orderBy: { completedAt: "desc" },
  });

  if (!lastSet) {
    return res.json({ hasHistory: false });
  }

  const suggestion = {};
  if (lastSet.weightKg != null) {
    suggestion.weightKg = lastSet.weightKg + 2.5;
    suggestion.reps = lastSet.reps;
  } else if (lastSet.durationSeconds != null) {
    suggestion.durationSeconds = lastSet.durationSeconds + 5;
  } else if (lastSet.reps != null) {
    suggestion.reps = lastSet.reps + 1;
  }

  res.json({ hasHistory: true, last: lastSet, suggestion });
});

module.exports = router;
