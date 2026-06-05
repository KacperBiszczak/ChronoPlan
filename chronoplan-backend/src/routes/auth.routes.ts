import { Router } from "express";
import bcrypt from "bcrypt";
import { prisma } from "../lib/prisma";

const router = Router();

router.post("/login", async (req, res) => {
  const { email, password } = req.body;

  const user = await prisma.user.findUnique({
    where: { email },
  });

  if (!user) {
    return res.status(401).json({
      message: "Nieprawidłowy email lub hasło",
    });
  }

  const isPasswordValid = await bcrypt.compare(password, user.password);

  if (!isPasswordValid) {
    return res.status(401).json({
      message: "Nieprawidłowy email lub hasło",
    });
  }

  res.json({
    message: "Zalogowano poprawnie",
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
    },
  });
});

export default router;