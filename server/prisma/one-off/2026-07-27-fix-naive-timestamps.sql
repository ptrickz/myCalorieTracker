-- One-off repair for timestamps written before the UTC fix.
--
-- NOT a Prisma migration on purpose: it lives outside prisma/migrations/ so
-- `prisma migrate deploy` (run by `npm start`) never applies it unattended.
-- Part of it is a judgement call, so it wants a human. Run it by hand.
--
-- BACKGROUND
-- The app used to send `DateTime.toIso8601String()` on a *local* DateTime,
-- which has no zone suffix ("2026-07-27T19:30:00.000"). The server's
-- `new Date(...)` reads such a string as its own local time (UTC), so the
-- wall clock got stored verbatim: 7:30 PM was saved as 19:30Z instead of the
-- true instant 11:30Z. Those rows are 8 hours ahead of reality for a UTC+8
-- user, and the app now renders them 8 hours late.
--
-- Rows created *without* an explicit timestamp were stamped server-side with
-- `new Date()` and are already correct instants. They must NOT be touched.
--
-- SET THIS to the UTC offset in effect when the affected rows were written.
-- '8 hours' = UTC+8. Everything below subtracts it.

-- =====================================================================
-- STEP 1 - DIAGNOSTIC (read-only). Run this first and read the counts.
-- =====================================================================

-- Naive rows carry a fingerprint: they came from DateTime(y,m,d,h,min), which
-- has exactly zero seconds and zero milliseconds. A server-side `new Date()`
-- essentially never does (odds ~1 in 60,000).
SELECT
  'LogEntry: naive (time was picked) - WILL SHIFT' AS bucket,
  count(*)
FROM "LogEntry"
WHERE date_part('second', "loggedAt") = 0

UNION ALL SELECT
  'LogEntry: quick-add, picker untouched - AMBIGUOUS, review',
  count(*)
FROM "LogEntry"
WHERE date_part('second', "loggedAt") <> 0
  AND "servingGrams" = 0

UNION ALL SELECT
  'LogEntry: logged now - correct, leave alone',
  count(*)
FROM "LogEntry"
WHERE date_part('second', "loggedAt") <> 0
  AND "servingGrams" > 0

UNION ALL SELECT
  'WorkoutLog: all naive - WILL SHIFT',
  count(*)
FROM "WorkoutLog"

UNION ALL SELECT
  'WeightLog: never sent a timestamp - correct, leave alone',
  count(*)
FROM "WeightLog";

-- Eyeball the rows about to move before moving them:
-- SELECT id, "loggedAt", "loggedAt" - interval '8 hours' AS becomes, "servingGrams"
-- FROM "LogEntry" WHERE date_part('second', "loggedAt") = 0
-- ORDER BY "loggedAt" DESC LIMIT 50;


-- =====================================================================
-- STEP 2 - THE FIX. Wrapped in a transaction: inspect, then COMMIT.
-- =====================================================================

BEGIN;

-- Every workout log was written from the picker, so all of them are naive.
-- (workout_screen.dart always sent loggedAt; there is no other write path.)
UPDATE "WorkoutLog"
SET "loggedAt" = "loggedAt" - interval '8 hours';

-- Food entries whose time was picked. The zero-seconds fingerprint keeps this
-- off the "logged now" rows, which are already correct.
UPDATE "LogEntry"
SET "loggedAt" = "loggedAt" - interval '8 hours'
WHERE date_part('second', "loggedAt") = 0;

-- Verify here, then COMMIT (or ROLLBACK if the numbers look wrong).
-- SELECT id, "loggedAt" FROM "WorkoutLog" ORDER BY "loggedAt" DESC LIMIT 20;

COMMIT;


-- =====================================================================
-- STEP 3 - THE AMBIGUOUS REMAINDER (manual)
-- =====================================================================
-- Quick-adds where the picker was never opened sent DateTime.now() naively, so
-- they are 8 hours ahead but carry real seconds - indistinguishable from a
-- correct row by value alone. A repeat-meal copy of a quick-add lands in the
-- same bucket but is already correct.
--
-- If STEP 1 shows this count is 0, there is nothing to do.
-- Otherwise list them and judge by whether the time reads plausibly:
--
-- SELECT id, "loggedAt", "loggedAt" - interval '8 hours' AS becomes, calories
-- FROM "LogEntry"
-- WHERE date_part('second', "loggedAt") <> 0 AND "servingGrams" = 0
-- ORDER BY "loggedAt" DESC;
--
-- Then shift only the ones that are genuinely wrong:
-- UPDATE "LogEntry" SET "loggedAt" = "loggedAt" - interval '8 hours'
-- WHERE id IN ('...', '...');
