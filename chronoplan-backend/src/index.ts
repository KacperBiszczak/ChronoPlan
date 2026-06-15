import express from "express";
import swaggerUi from "swagger-ui-express";
import { swaggerSpec } from "./swagger";
import userRoutes from "./routes/user.routes";
import authRoutes from "./routes/auth.routes";
import eventRoutes from "./routes/event.routes";
import taskRoutes from "./routes/task.routes";
import expenseRoutes from "./routes/expense.routes";
import participantRoutes from "./routes/participant.routes";
import { errorMiddleware } from "./middlewares/error.middleware";

const app = express();

app.use(express.json());

app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));

app.get("/", (req, res) => {
  res.json({
    message: "ChronoPlan API działa",
  });
});

app.use("/users", userRoutes);
app.use("/auth", authRoutes);
app.use("/events", eventRoutes);
app.use("/tasks", taskRoutes);
app.use("/expenses", expenseRoutes);
app.use("/participants", participantRoutes)

app.use(errorMiddleware);

app.listen(5000, () => {
  console.log("Server działa na porcie 5000");
});