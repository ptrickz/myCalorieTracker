require("dotenv").config();
const express = require("express");
const cors = require("cors");
const prisma = require("./db");
const authRoutes = require("./routes/auth");
const { requireAuth } = require("./middleware/auth");

const app = express();

app.use(cors());
app.use(express.json());

app.get("/health", async (req, res) => {
  const userCount = await prisma.user.count();
  res.json({ status: "ok", userCount });
});

app.use("/auth", authRoutes);

app.get("/me", requireAuth, async (req, res) => {
  const user = await prisma.user.findUnique({
    where: { id: req.userId },
    select: { id: true, email: true, createdAt: true },
  });
  res.json(user);
});

const port = process.env.PORT || 3000;
app.listen(port, "0.0.0.0", () => {
  console.log(`Server listening on http://0.0.0.0:${port}`);
});
