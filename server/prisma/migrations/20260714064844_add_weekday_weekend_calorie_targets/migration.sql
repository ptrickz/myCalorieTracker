-- AlterTable
ALTER TABLE "User" ADD COLUMN     "useCustomCalorieTargets" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "weekdayTargetCalories" DOUBLE PRECISION,
ADD COLUMN     "weekendTargetCalories" DOUBLE PRECISION;
