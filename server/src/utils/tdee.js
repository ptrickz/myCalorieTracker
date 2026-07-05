const ACTIVITY_MULTIPLIERS = {
  SEDENTARY: 1.2,
  LIGHT: 1.375,
  MODERATE: 1.55,
  ACTIVE: 1.725,
  VERY_ACTIVE: 1.9,
};

const GOAL_ADJUSTMENT_KCAL = {
  LOSE: -500,
  MAINTAIN: 0,
  GAIN: 500,
};

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

function calculateTdee({ weightKg, heightCm, dateOfBirth, sex, activityLevel, goalType }) {
  const age = ageFromDateOfBirth(dateOfBirth);
  const bmr = calculateBmr({ weightKg, heightCm, age, sex });
  const maintenanceTdee = bmr * ACTIVITY_MULTIPLIERS[activityLevel];
  const targetCalories = maintenanceTdee + GOAL_ADJUSTMENT_KCAL[goalType];
  return { maintenanceTdee, targetCalories };
}

module.exports = { calculateTdee, ageFromDateOfBirth };
