require("dotenv").config();
const path = require("path");
const fs = require("fs");
const express = require("express");
const cors = require("cors");
const swaggerUi = require("swagger-ui-express");
const YAML = require("yaml");
const prisma = require("./db");
const authRoutes = require("./routes/auth");
const profileRoutes = require("./routes/profile");
const foodRoutes = require("./routes/foods");
const logRoutes = require("./routes/logs");
const weightLogRoutes = require("./routes/weightLogs");
const visionLogRoutes = require("./routes/visionLog");
const { requireAuth } = require("./middleware/auth");

const app = express();

app.use(cors());
app.use(express.json({ limit: "8mb" }));

app.get("/health", async (req, res) => {
  const userCount = await prisma.user.count();
  res.json({ status: "ok", userCount });
});

const openapiDocument = YAML.parse(fs.readFileSync(path.join(__dirname, "../openapi.yaml"), "utf8"));
app.use("/docs", swaggerUi.serve, swaggerUi.setup(openapiDocument));

app.use("/auth", authRoutes);

app.get("/me", requireAuth, async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.userId },
    select: { id: true, email: true, createdAt: true },
  });
  res.json(user);
});

app.use("/profile", requireAuth, profileRoutes);
app.use("/foods", requireAuth, foodRoutes);
app.use("/logs", requireAuth, logRoutes);
app.use("/weight-logs", requireAuth, weightLogRoutes);
app.use("/vision-log", requireAuth, visionLogRoutes);

const port = process.env.PORT || 3000;
app.listen(port, "0.0.0.0", () => {
  console.log(`Server listening on http://0.0.0.0:${port}`);
});
