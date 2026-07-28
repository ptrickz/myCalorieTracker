-- AlterEnum
ALTER TYPE "FoodSource" ADD VALUE 'RECIPE';

-- AlterTable
ALTER TABLE "FoodItem" ADD COLUMN     "recipeId" TEXT;

-- CreateTable
CREATE TABLE "Recipe" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "servings" INTEGER NOT NULL DEFAULT 1,
    "ingredients" TEXT[],
    "steps" TEXT[],
    "caloriesPerServing" DOUBLE PRECISION NOT NULL,
    "proteinPerServing" DOUBLE PRECISION NOT NULL,
    "carbsPerServing" DOUBLE PRECISION NOT NULL,
    "fatPerServing" DOUBLE PRECISION NOT NULL,
    "sourceName" TEXT,
    "createdByUserId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Recipe_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Recipe_name_idx" ON "Recipe"("name");

-- CreateIndex
CREATE UNIQUE INDEX "FoodItem_recipeId_key" ON "FoodItem"("recipeId");

-- AddForeignKey
ALTER TABLE "FoodItem" ADD CONSTRAINT "FoodItem_recipeId_fkey" FOREIGN KEY ("recipeId") REFERENCES "Recipe"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Recipe" ADD CONSTRAINT "Recipe_createdByUserId_fkey" FOREIGN KEY ("createdByUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

