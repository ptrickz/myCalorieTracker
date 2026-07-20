// Dependency-free mock of the myCalorieTracker API for visual testing the
// Flutter app without Postgres/Docker. Reuses the REAL tdee.js from the server
// so the calorie targets shown in the app come from the actual changed code.
const http = require("http");
const { calculateTdee } = require("./src/utils/tdee.js");

const user = {
  id: "mock-user",
  email: "pattrickpatt@gmail.com",
  dateOfBirth: "1999-04-15T00:00:00.000Z",
  sex: "MALE",
  heightCm: 167,
  activityLevel: "LIGHT",
  goalType: "LOSE",
  goalWeightKg: 75,
  milestoneWeightKg: 85,
  proteinTargetG: 150,
  weeklyLossGoalKg: 0.5,
  useCustomCalorieTargets: false,
  weekdayTargetCalories: null,
  weekendTargetCalories: null,
};

// ~3 weeks of weigh-ins trending 91 -> 88 kg
const weightLogs = [];
{
  let w = 91;
  for (let i = 20; i >= 0; i -= 2) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    weightLogs.push({ id: `w${i}`, weightKg: Math.round(w * 10) / 10, recordedAt: d.toISOString() });
    w -= 0.3;
  }
}

function buildProfileResponse() {
  const latest = weightLogs[weightLogs.length - 1];
  const tdee = calculateTdee({
    weightKg: latest.weightKg,
    heightCm: user.heightCm,
    dateOfBirth: new Date(user.dateOfBirth),
    sex: user.sex,
    activityLevel: user.activityLevel,
    goalType: user.goalType,
    weeklyLossGoalKg: user.weeklyLossGoalKg,
  });
  const auto = tdee.targetCalories;
  return {
    ...user,
    latestWeightKg: latest.weightKg,
    profileComplete: true,
    tdee,
    weekdayTargetCalories: user.useCustomCalorieTargets ? (user.weekdayTargetCalories ?? auto) : auto,
    weekendTargetCalories: user.useCustomCalorieTargets ? (user.weekendTargetCalories ?? auto) : auto,
  };
}

const sampleEntries = [
  { name: "Oatmeal with banana", mealType: "BREAKFAST", servingGrams: 320, calories: 410, protein: 12, carbs: 78, fat: 7 },
  { name: "Grilled chicken rice bowl", mealType: "LUNCH", servingGrams: 450, calories: 620, protein: 48, carbs: 70, fat: 14 },
  { name: "Greek yogurt", mealType: "SNACK", servingGrams: 170, calories: 150, protein: 17, carbs: 9, fat: 5 },
].map((e, i) => ({
  id: `e${i}`,
  foodItem: { name: e.name },
  mealType: e.mealType,
  servingGrams: e.servingGrams,
  calories: e.calories,
  protein: e.protein,
  carbs: e.carbs,
  fat: e.fat,
  loggedAt: new Date().toISOString(),
}));

function logsResponse() {
  const totals = sampleEntries.reduce(
    (t, e) => ({ calories: t.calories + e.calories, protein: t.protein + e.protein, carbs: t.carbs + e.carbs, fat: t.fat + e.fat }),
    { calories: 0, protein: 0, carbs: 0, fat: 0 }
  );
  return { totals, entries: sampleEntries };
}

function rangeResponse(days) {
  const out = [];
  for (let i = days - 1; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    out.push({
      date: d.toISOString().substring(0, 10),
      calories: 1500 + Math.round(600 * Math.abs(Math.sin(i * 1.7))),
      protein: 90 + Math.round(60 * Math.abs(Math.cos(i * 1.3))),
    });
  }
  return { days: out };
}

function send(res, status, body) {
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET,POST,PATCH,PUT,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
  });
  res.end(body === undefined ? "" : JSON.stringify(body));
}

const server = http.createServer((req, res) => {
  if (req.method === "OPTIONS") return send(res, 204);

  let raw = "";
  req.on("data", (c) => (raw += c));
  req.on("end", () => {
    let body = {};
    try { body = raw ? JSON.parse(raw) : {}; } catch (_) {}
    const url = new URL(req.url, "http://localhost");
    const p = url.pathname;
    console.log(`${req.method} ${req.url}`);

    if (req.method === "POST" && p === "/auth/login") return send(res, 200, { token: "mock-token" });
    if (req.method === "POST" && p === "/auth/signup") return send(res, 201, {});
    if (req.method === "GET" && p === "/me") return send(res, 200, { id: user.id, email: user.email });

    if (p === "/profile") {
      if (req.method === "PATCH") {
        for (const key of ["sex", "heightCm", "activityLevel", "goalType", "goalWeightKg",
          "milestoneWeightKg", "proteinTargetG", "weeklyLossGoalKg", "useCustomCalorieTargets",
          "weekdayTargetCalories", "weekendTargetCalories", "dateOfBirth"]) {
          if (body[key] !== undefined) user[key] = body[key];
        }
        if (body.weightKg !== undefined) {
          weightLogs.push({ id: `w-new-${Date.now()}`, weightKg: body.weightKg, recordedAt: new Date().toISOString() });
        }
      }
      return send(res, 200, buildProfileResponse());
    }

    if (req.method === "GET" && p === "/logs") return send(res, 200, logsResponse());
    if (req.method === "GET" && p === "/logs/range")
      return send(res, 200, rangeResponse(Number(url.searchParams.get("days") ?? 7)));
    if (req.method === "GET" && p === "/logs/streak")
      return send(res, 200, { currentStreak: 5, longestStreak: 9, loggedToday: true });

    if (p === "/weight-logs") {
      if (req.method === "POST") {
        weightLogs.push({ id: `w-new-${Date.now()}`, weightKg: body.weightKg, recordedAt: new Date().toISOString() });
        return send(res, 201, weightLogs[weightLogs.length - 1]);
      }
      return send(res, 200, weightLogs);
    }

    if (req.method === "GET" && (p === "/foods" || p === "/foods/mine")) return send(res, 200, []);
    if (req.method === "GET" && p === "/exercises") return send(res, 200, []);
    if (req.method === "GET" && p === "/workout-logs") {
      const monday = new Date();
      monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
      const at = (dayOffset, hour) => {
        const d = new Date(monday);
        d.setDate(d.getDate() + dayOffset);
        d.setHours(hour, 15, 0, 0);
        return d.toISOString();
      };
      return send(res, 200, [
        {
          id: "wl1", venue: "Home", loggedAt: at(0, 7),
          sets: [
            { exercise: { name: "Push-ups" } },
            { exercise: { name: "Goblet Squat" } },
          ],
        },
        {
          id: "wl2", venue: "Gym", loggedAt: at(2, 19),
          sets: [{ exercise: { name: "Bench Press" } }, { exercise: { name: "Lat Pulldown" } }],
        },
        {
          id: "wl3", venue: "Badminton Court", loggedAt: at(5, 10),
          sets: [],
        },
      ]);
    }

    send(res, 404, { error: `no mock for ${req.method} ${p}` });
  });
});

server.listen(3000, () => console.log("mock API on http://localhost:3000"));
