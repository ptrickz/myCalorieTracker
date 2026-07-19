-- AlterTable
ALTER TABLE "User" ADD COLUMN     "visionLogCount" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "visionLogWindowStartedAt" TIMESTAMP(3);
