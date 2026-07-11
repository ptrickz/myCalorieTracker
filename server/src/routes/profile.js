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
};

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
    });
  }

  return {
    ...user,
    latestWeightKg: latestWeight?.weightKg ?? null,
    profileComplete,
    tdee,
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
  } = req.body;

  const data = {};
  if (dateOfBirth !== undefined) data.dateOfBirth = new Date(dateOfBirth);
  if (sex !== undefined) data.sex = sex;
  if (heightCm !== undefined) data.heightCm = heightCm;
  if (activityLevel !== undefined) data.activityLevel = activityLevel;
  if (goalType !== undefined) data.goalType = goalType;
  if (goalWeightKg !== undefined) data.goalWeightKg = goalWeightKg;
  if (milestoneWeightKg !== undefined) data.milestoneWeightKg = milestoneWeightKg;

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
