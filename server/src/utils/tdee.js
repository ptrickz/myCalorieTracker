const ACTIVITY_MULTIPLIERS = {
  SEDENTARY: 1.2,
  LIGHT: 1.375,
  MODERATE: 1.55,
  ACTIVE: 1.725,
  VERY_ACTIVE: 1.9,
};

// ~7700 kcal per kg of body fat. The user's weekly pace (kg/week) converts
// to a daily calorie adjustment: subtracted for LOSE, added for GAIN.
const KCAL_PER_KG = 7700;
const DEFAULT_WEEKLY_CHANGE_KG = 0.5;

function dailyAdjustmentKcal(goalType, weeklyLossGoalKg) {
  if (goalType === "MAINTAIN") return 0;
  const weeklyKg = weeklyLossGoalKg ?? DEFAULT_WEEKLY_CHANGE_KG;
  const perDay = (weeklyKg * KCAL_PER_KG) / 7;
  return goalType === "LOSE" ? -perDay : perDay;
}

function ageFromDateOfBirth(dateOfBirth) {
  const now = new Date();
  let age = now.getFullYear() - dateOfBirth.getFullYear();
  const hasHadBirthdayThisYear =
    now.getMonth() > dateOfBirth.getMonth() ||
    (now.getMonth() === dateOfBirth.getMonth() && now.getDate() >= dateOfBirth.getDate());
  if (!hasHadBirthdayThisYear) age -= 1;
  return age;
}

// Mifflin-St Jeor equation
function calculateBmr({ weightKg, heightCm, age, sex }) {
  const base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return sex === "MALE" ? base + 5 : base - 161;
}

function calculateTdee({ weightKg, heightCm, dateOfBirth, sex, activityLevel, goalType, weeklyLossGoalKg }) {
  const age = ageFromDateOfBirth(dateOfBirth);
  const bmr = calculateBmr({ weightKg, heightCm, age, sex });
  const maintenanceTdee = bmr * ACTIVITY_MULTIPLIERS[activityLevel];
  const targetCalories = maintenanceTdee + dailyAdjustmentKcal(goalType, weeklyLossGoalKg);
  return { maintenanceTdee, targetCalories };
}

module.exports = { calculateTdee, ageFromDateOfBirth };
