/// Client-side mirror of the server's TDEE math (server/src/utils/tdee.js),
/// used only for the live daily-target preview while editing the profile.
/// The server remains the source of truth for the saved target.
library;

const kcalPerKg = 7700;

const activityMultipliers = {
  "SEDENTARY": 1.2,
  "LIGHT": 1.375,
  "MODERATE": 1.55,
  "ACTIVE": 1.725,
  "VERY_ACTIVE": 1.9,
};

int ageFromDateOfBirth(DateTime dateOfBirth) {
  final now = DateTime.now();
  var age = now.year - dateOfBirth.year;
  final hasHadBirthdayThisYear = now.month > dateOfBirth.month ||
      (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);
  if (!hasHadBirthdayThisYear) age -= 1;
  return age;
}

/// Mifflin-St Jeor daily target for the given inputs, or null when any
/// input needed for the estimate is missing.
double? estimateDailyTargetCalories({
  required double? weightKg,
  required double? heightCm,
  required DateTime? dateOfBirth,
  required String? sex,
  required String? activityLevel,
  required String? goalType,
  required double weeklyLossGoalKg,
}) {
  if (weightKg == null ||
      heightCm == null ||
      dateOfBirth == null ||
      sex == null ||
      activityLevel == null ||
      goalType == null) {
    return null;
  }
  final multiplier = activityMultipliers[activityLevel];
  if (multiplier == null) return null;

  final age = ageFromDateOfBirth(dateOfBirth);
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  final bmr = sex == "MALE" ? base + 5 : base - 161;
  final maintenance = bmr * multiplier;

  final perDay = weeklyLossGoalKg * kcalPerKg / 7;
  switch (goalType) {
    case "LOSE":
      return maintenance - perDay;
    case "GAIN":
      return maintenance + perDay;
    default:
      return maintenance;
  }
}
