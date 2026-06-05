import express from "express";
import userRoutes from "./routes/user.routes";

const app = express();

app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    message: "ChronoPlan API działa",
  });
});

app.use("/users", userRoutes);

app.listen(5000, () => {
  console.log("Server działa na porcie 5000");
});