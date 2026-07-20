const express = require("express");
const prisma = require("../db");
const { calculateTdee } = require("../utils/tdee");

const router = express.Router();

const PROFILE_SELECT = {
  id: true,
  email: true,
  dateOfBirth: true,
  sex: true,
  heightCm: true,
  activityLevel: true,
  goalType: true,
  goalWeightKg: true,
  milestoneWeightKg: true,
  proteinTargetG: true,
  weeklyLossGoalKg: true,
  useCustomCalorieTargets: true,
  weekdayTargetCalories: true,
  weekendTargetCalories: true,
};

// A common rule-of-thumb protein target (g per kg bodyweight) used when the
// user hasn't set an explicit override.
const DEFAULT_PROTEIN_G_PER_KG = 1.7;

async function buildProfileResponse(user) {
  const latestWeight = await prisma.weightLog.findFirst({
    where: { userId: user.id },
    orderBy: { recordedAt: "desc" },
  });

  const profileComplete = Boolean(
    user.dateOfBirth && user.sex && user.heightCm && user.activityLevel && user.goalType && latestWeight
  );

  let tdee = null;
  if (profileComplete) {
    tdee = calculateTdee({
      weightKg: latestWeight.weightKg,
      heightCm: user.heightCm,
      dateOfBirth: user.dateOfBirth,
      sex: user.sex,
      activityLevel: user.activityLevel,
      goalType: user.goalType,
      weeklyLossGoalKg: user.weeklyLossGoalKg,
    });
  }

  const proteinTargetG =
    user.proteinTargetG ?? (latestWeight ? latestWeight.weightKg * DEFAULT_PROTEIN_G_PER_KG : null);

  // Weekday/weekend targets both default to the auto-calculated TDEE target
  // unless the user has opted into custom overrides.
  const autoTargetCalories = tdee?.targetCalories ?? null;
  const weekdayTargetCalories = user.useCustomCalorieTargets
    ? (user.weekdayTargetCalories ?? autoTargetCalories)
    : autoTargetCalories;
  const weekendTargetCalories = user.useCustomCalorieTargets
    ? (user.weekendTargetCalories ?? autoTargetCalories)
    : autoTargetCalories;

  return {
    ...user,
    latestWeightKg: latestWeight?.weightKg ?? null,
    profileComplete,
    tdee,
    proteinTargetG,
    weekdayTargetCalories,
    weekendTargetCalories,
  };
}

router.get("/", async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.userId },
    select: PROFILE_SELECT,
  });
  res.json(await buildProfileResponse(user));
});

router.patch("/", async (req, res) => {
  const {
    dateOfBirth,
    sex,
    heightCm,
    activityLevel,
    goalType,
    weightKg,
    goalWeightKg,
    milestoneWeightKg,
    proteinTargetG,
    weeklyLossGoalKg,
    useCustomCalorieTargets,
    weekdayTargetCalories,
    weekendTargetCalories,
  } = req.body;

  const data = {};
  if (dateOfBirth !== undefined) data.dateOfBirth = new Date(dateOfBirth);
  if (sex !== undefined) data.sex = sex;
  if (heightCm !== undefined) data.heightCm = heightCm;
  if (activityLevel !== undefined) data.activityLevel = activityLevel;
  if (goalType !== undefined) data.goalType = goalType;
  if (goalWeightKg !== undefined) data.goalWeightKg = goalWeightKg;
  if (milestoneWeightKg !== undefined) data.milestoneWeightKg = milestoneWeightKg;
  if (proteinTargetG !== undefined) data.proteinTargetG = proteinTargetG;
  if (weeklyLossGoalKg !== undefined) {
    if (typeof weeklyLossGoalKg !== "number" || weeklyLossGoalKg < 0.25 || weeklyLossGoalKg > 1.0) {
      return res.status(400).json({ error: "weeklyLossGoalKg must be between 0.25 and 1.0" });
    }
    data.weeklyLossGoalKg = weeklyLossGoalKg;
  }
  if (useCustomCalorieTargets !== undefined) data.useCustomCalorieTargets = useCustomCalorieTargets;
  if (weekdayTargetCalories !== undefined) data.weekdayTargetCalories = weekdayTargetCalories;
  if (weekendTargetCalories !== undefined) data.weekendTargetCalories = weekendTargetCalories;

  const user = await prisma.user.update({
    where: { id: req.userId },
    data,
    select: PROFILE_SELECT,
  });

  if (weightKg !== undefined) {
    await prisma.weightLog.create({
      data: { userId: req.userId, weightKg },
    });
  }

  res.json(await buildProfileResponse(user));
});

module.exports = router;
