const express = require("express");
const Anthropic = require("@anthropic-ai/sdk");
const prisma = require("../db");

const router = express.Router();
const anthropic = new Anthropic();

const ALLOWED_MEDIA_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"];

// Rolling 24h cap on Claude vision calls per user — a real per-request cost,
// even for a single-user app.
const RATE_LIMIT_PER_WINDOW = 40;
const WINDOW_MS = 24 * 60 * 60 * 1000;

async function checkAndIncrementRateLimit(userId) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { visionLogCount: true, visionLogWindowStartedAt: true },
  });

  const now = new Date();
  const windowExpired =
    !user.visionLogWindowStartedAt || now - user.visionLogWindowStartedAt > WINDOW_MS;

  if (windowExpired) {
    await prisma.user.update({
      where: { id: userId },
      data: { visionLogCount: 1, visionLogWindowStartedAt: now },
    });
    return true;
  }

  if (user.visionLogCount >= RATE_LIMIT_PER_WINDOW) {
    return false;
  }

  await prisma.user.update({
    where: { id: userId },
    data: { visionLogCount: { increment: 1 } },
  });
  return true;
}

const LABEL_SCHEMA = {
  type: "object",
  properties: {
    name: { type: "string", description: "Product name from the packaging, if visible" },
    caloriesPer100g: { type: "number" },
    proteinPer100g: { type: "number" },
    carbsPer100g: { type: "number" },
    fatPer100g: { type: "number" },
    sodiumPer100gMg: { type: "number", description: "0 if not listed on the label" },
    confidence: { type: "string", enum: ["high", "medium", "low"] },
    notes: { type: "string", description: "Caveats, e.g. illegible values or assumptions made" },
  },
  required: [
    "name",
    "caloriesPer100g",
    "proteinPer100g",
    "carbsPer100g",
    "fatPer100g",
    "sodiumPer100gMg",
    "confidence",
    "notes",
  ],
  additionalProperties: false,
};

const LABEL_PROMPT = `This is a photo of a nutrition facts label. Read the printed values exactly as shown.
Scale them to per-100g (or per-100ml) even if the label's serving size is different — calculate from the printed serving size and per-serving values if a per-100g figure isn't printed directly.
Extract the product name from the packaging if visible, otherwise describe the food generically.
If sodium isn't listed, return 0 for it.
Set confidence based on how legible the label photo is, not on your certainty about the food itself.`;

const PLATE_SCHEMA = {
  type: "object",
  properties: {
    description: { type: "string", description: "Brief description of the meal identified" },
    ingredients: { type: "array", items: { type: "string" } },
    estimatedServingGrams: { type: "number" },
    caloriesMin: { type: "number" },
    caloriesMax: { type: "number" },
    proteinGramsMin: { type: "number" },
    proteinGramsMax: { type: "number" },
    carbsGramsMin: { type: "number" },
    carbsGramsMax: { type: "number" },
    fatGramsMin: { type: "number" },
    fatGramsMax: { type: "number" },
    confidence: { type: "string", enum: ["high", "medium", "low"] },
    notes: { type: "string", description: "Caveats, e.g. hidden oil/sauce or portion uncertainty" },
  },
  required: [
    "description",
    "ingredients",
    "estimatedServingGrams",
    "caloriesMin",
    "caloriesMax",
    "proteinGramsMin",
    "proteinGramsMax",
    "carbsGramsMin",
    "carbsGramsMax",
    "fatGramsMin",
    "fatGramsMax",
    "confidence",
    "notes",
  ],
  additionalProperties: false,
};

const PLATE_PROMPT = `This is a photo of a meal or plate of food, not a printed label. Identify the ingredients and estimate the portion size and macros.
Photo-based estimation of mixed dishes is inherently uncertain — hidden oil, sauce, and portion size are hard to judge from a photo — so return a realistic MIN and MAX range for calories and each macro rather than a single falsely-precise number. A spread of roughly 15-25% between min and max is typical for a mixed plate; don't collapse the range to look more confident than the estimate actually is.
List the ingredients you identified and your best estimate of the total serving weight in grams.
Note any hidden-calorie risks (oil, sauce, frying, sugary drinks) in your notes.`;

router.post("/", async (req, res) => {
  const { image, mediaType, mode } = req.body;

  if (!image || !mediaType || !mode) {
    return res.status(400).json({ error: "image, mediaType, and mode are required" });
  }
  if (!["label", "plate"].includes(mode)) {
    return res.status(400).json({ error: "mode must be 'label' or 'plate'" });
  }
  if (!ALLOWED_MEDIA_TYPES.includes(mediaType)) {
    return res.status(400).json({ error: `mediaType must be one of ${ALLOWED_MEDIA_TYPES.join(", ")}` });
  }

  const allowed = await checkAndIncrementRateLimit(req.userId);
  if (!allowed) {
    return res.status(429).json({ error: "Daily scan limit reached. Try again tomorrow." });
  }

  try {
    const schema = mode === "label" ? LABEL_SCHEMA : PLATE_SCHEMA;
    const prompt = mode === "label" ? LABEL_PROMPT : PLATE_PROMPT;

    const response = await anthropic.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 2048,
      output_config: { format: { type: "json_schema", schema } },
      messages: [
        {
          role: "user",
          content: [
            { type: "image", source: { type: "base64", media_type: mediaType, data: image } },
            { type: "text", text: prompt },
          ],
        },
      ],
    });

    if (response.stop_reason === "refusal") {
      return res.status(422).json({ error: "Could not analyze this image" });
    }

    const textBlock = response.content.find((block) => block.type === "text");
    const result = JSON.parse(textBlock.text);
    res.json({ mode, result });
  } catch (e) {
    console.error("vision-log error:", e);
    res.status(502).json({ error: "Vision analysis failed" });
  }
});

module.exports = router;
