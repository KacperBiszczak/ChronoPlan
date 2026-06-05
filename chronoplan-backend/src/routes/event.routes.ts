import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";

const router = Router();

router.post("/", authMiddleware, async (req, res) => {
  try {
    const { title, description, date } = req.body;
    const user = (req as any).user;

    const event = await prisma.event.create({
      data: {
        title,
        description,
        date: new Date(date),
        creatorId: user.userId,
      },
    });

    res.status(201).json(event);
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Błąd tworzenia wydarzenia",
    });
  }
});

router.get("/", authMiddleware, async (req, res) => {
  const user = (req as any).user;

  const events = await prisma.event.findMany({
    where: {
      creatorId: user.userId,
    },
    orderBy: {
      date: "asc",
    },
  });

  res.json(events);
});

export default router;