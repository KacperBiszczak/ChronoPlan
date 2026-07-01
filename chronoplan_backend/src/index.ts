import express from "express";
import swaggerUi from "swagger-ui-express";
import { swaggerSpec } from "./swagger";
import userRoutes from "./routes/user.routes";
import authRoutes from "./routes/auth.routes";
import eventRoutes from "./routes/event.routes";
import taskRoutes from "./routes/task.routes";
import expenseRoutes from "./routes/expense.routes";
import participantRoutes from "./routes/participant.routes";
import dateVoteRoutes from "./routes/date-vote.routes";
import chatRoutes from "./routes/chat.routes";
import { errorMiddleware } from "./middlewares/error.middleware";
import cors from "cors";

const app = express();

app.use(cors());
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
app.use("/participants", participantRoutes);
app.use("/date-votes", dateVoteRoutes);
app.use("/chat", chatRoutes);

app.use(errorMiddleware);

const PORT = process.env.PORT || 5000

app.listen(PORT, () => {
  console.log(`Server działa na porcie ${PORT}`);
});