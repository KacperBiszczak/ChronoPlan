import { Router } from "express";
import { prisma } from "../lib/prisma";
import bcrypt from "bcrypt";
import { authMiddleware } from "../middlewares/auth.middleware";

const router = Router();

router.get("/", authMiddleware, async (req, res) => {
  const users = await prisma.user.findMany();

  res.json(users);
});

router.post("/", async (req, res) => {
  try {
    const { name, email, password } = req.body;

    const existingUser = await prisma.user.findUnique({
      where: { email },
    });

    if (existingUser) {
      return res.status(409).json({
        message: "Użytkownik z takim emailem już istnieje",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: {
        name,
        email,
        password: hashedPassword,
      },
      select: {
        id: true,
        name: true,
        email: true,
        createdAt: true,
      },
    });

    res.status(201).json(user);
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Błąd tworzenia użytkownika",
    });
  }
});

export default router;