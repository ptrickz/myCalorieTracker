// One-off/idempotent seed for the Exercise catalog, sourced from the user's
// actual Mon/Wed/Fri routine (docs/2-workouts.md). Safe to re-run — upserts
// by name so it won't create duplicates.
require("dotenv").config();
const prisma = require("../src/db");

const EXERCISES = [
  {
    name: "Goblet Squat",
    dayTag: "Monday",
    defaultSets: 3,
    defaultReps: "12",
    formCue:
      "Hold dumbbell vertically at chest. Feet shoulder-width, toes slightly out. Sit back and down until thighs parallel, chest up, push through heels.",
    videoUrl: "https://www.youtube.com/watch?v=JO7D6GJ98wY",
  },
  {
    name: "Incline Push-up",
    dayTag: "Monday",
    defaultSets: 3,
    defaultReps: "8-10",
    formCue:
      "Hands on raised surface, body one straight line. Chest to the edge, elbows ~45° from body, press up.",
    videoUrl: "https://www.youtube.com/watch?v=0JUrOH--Kdk",
  },
  {
    name: "Glute Bridge",
    dayTag: "Monday",
    defaultSets: 3,
    defaultReps: "12",
    formCue:
      "On back, knees bent, feet flat. Squeeze glutes, lift hips to a straight line knees-to-shoulders, 1 sec pause at top.",
    videoUrl: "https://www.youtube.com/watch?v=nbjJjSa0cKo",
  },
  {
    name: "Plank",
    dayTag: "Monday",
    defaultSets: 3,
    defaultReps: "20-30 sec",
    formCue: "Forearms down, straight head-to-heels. Brace abs and glutes; no sagging or piking.",
    videoUrl: "https://www.youtube.com/watch?v=mwlp75MS6Rg",
  },
  {
    name: "Reverse Lunge",
    dayTag: "Wednesday",
    defaultSets: 3,
    defaultReps: "8 per leg",
    formCue: "Step back, both knees to ~90°, front knee over ankle, drive up through front heel.",
    videoUrl: "https://www.youtube.com/watch?v=94AXT7D3bKY",
  },
  {
    name: "Push-up (knees ok)",
    dayTag: "Wednesday",
    defaultSets: 3,
    defaultReps: "6-8",
    formCue: "Same as incline push-up but on the floor; drop to knees if needed to keep good form.",
    videoUrl: "https://www.youtube.com/watch?v=z8nUnCdZXQI",
  },
  {
    name: "Dumbbell Row",
    dayTag: "Wednesday",
    defaultSets: 3,
    defaultReps: "10 per side",
    formCue: "One hand and knee braced on a chair, back flat. Pull dumbbell to hip, squeeze shoulder blade, lower slow.",
    videoUrl: "https://www.youtube.com/watch?v=PgpQ4-jHiq4",
  },
  {
    name: "Superman Hold",
    dayTag: "Wednesday",
    defaultSets: 3,
    defaultReps: "20 sec",
    formCue: "Face down, lift arms/chest/legs together, hold, lower slowly.",
    videoUrl: "https://www.youtube.com/watch?v=g0Kr9Wd3CeQ",
  },
  {
    name: "Bodyweight Squat",
    dayTag: "Friday",
    defaultSets: 4,
    defaultReps: "10",
    formCue: "Same cues as the goblet squat, no weight — part of the Friday circuit (4 rounds, 60 sec rest between).",
    videoUrl: "https://www.youtube.com/watch?v=P-yaD24bUE8",
  },
  {
    name: "Jumping Jacks",
    dayTag: "Friday",
    defaultSets: 4,
    defaultReps: "30 sec",
    formCue: "Steady pace, light bounce, arms overhead — part of the Friday circuit.",
    videoUrl: "https://www.youtube.com/watch?v=uLVt6u15L98",
  },
  {
    name: "Mountain Climbers",
    dayTag: null,
    defaultSets: null,
    defaultReps: null,
    formCue: "Steady pace, hips level, arms overhead — an available substitute/extra, not in the fixed 3-day plan.",
    videoUrl: "https://www.youtube.com/watch?v=ixxk9Qfn61o",
  },
];

// YouTube's standard thumbnail CDN — always available for any valid video ID,
// so this is a real, working image rather than a guessed URL.
function thumbnailFor(videoUrl) {
  const match = videoUrl.match(/[?&]v=([^&]+)/);
  return match ? `https://img.youtube.com/vi/${match[1]}/hqdefault.jpg` : null;
}

async function main() {
  for (const base of EXERCISES) {
    const exercise = { ...base, imageUrl: thumbnailFor(base.videoUrl) };
    const existing = await prisma.exercise.findFirst({
      where: { name: exercise.name, createdByUserId: null },
    });

    if (existing) {
      await prisma.exercise.update({ where: { id: existing.id }, data: exercise });
    } else {
      await prisma.exercise.create({ data: exercise });
    }
  }

  console.log(`Seeded ${EXERCISES.length} exercises.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
