import express from "express";
import userRoutes from "./routes/user.routes";
import authRoutes from "./routes/auth.routes";
import eventRoutes from "./routes/event.routes";
import taskRoutes from "./routes/task.routes";

const app = express();

app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    message: "ChronoPlan API działa",
  });
});

app.use("/users", userRoutes);
app.use("/auth", authRoutes);
app.use("/events", eventRoutes);
app.use("/tasks", taskRoutes);

app.listen(5000, () => {
  console.log("Server działa na porcie 5000");
});