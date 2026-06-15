import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { canAccessEvent } from "../lib/event-access";

const router = Router();

router.post("/", authMiddleware, async (req, res) => {
  try {
    const user = (req as any).user;
    const { title, amount, eventId } = req.body;

    const event = await canAccessEvent(Number(eventId), user.userId);

    if (!event) {
      res.status(404).json({
        message: "Nie znaleziono wydarzenia",
      });
      return;
    }

    const expense = await prisma.expense.create({
      data: {
        title,
        amount: Number(amount),
        eventId: Number(eventId),
      },
    });

    res.status(201).json(expense);
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Błąd dodawania wydatku",
    });
  }
});

router.get("/event/:eventId", authMiddleware, async (req, res) => {
  const user = (req as any).user;
  const eventId = Number(req.params.eventId);

  const event = await canAccessEvent(eventId, user.userId);

  if (!event) {
    res.status(404).json({
      message: "Nie znaleziono wydarzenia",
    });
    return;
  }

  const expenses = await prisma.expense.findMany({
    where: {
      eventId,
    },
    orderBy: {
      createdAt: "asc",
    },
  });

  res.json(expenses);
});

router.get("/event/:eventId/summary", authMiddleware, async (req, res) => {
  const user = (req as any).user;
  const eventId = Number(req.params.eventId);

  const event = await canAccessEvent(eventId, user.userId);

  if (!event) {
    res.status(404).json({
      message: "Nie znaleziono wydarzenia",
    });
    return;
  }

  const result = await prisma.expense.aggregate({
    where: {
      eventId,
    },
    _sum: {
      amount: true,
    },
  });

  res.json({
    totalExpenses: result._sum.amount ?? 0,
  });
});

router.delete("/:id", authMiddleware, async (req, res) => {
  const user = (req as any).user;
  const id = Number(req.params.id);

  const expense = await prisma.expense.findFirst({
    where: {
      id,
      event: {
        creatorId: user.userId,
      },
    },
  });

  if (!expense) {
    res.status(404).json({
      message: "Nie znaleziono wydatku",
    });
    return;
  }

  await prisma.expense.delete({
    where: {
      id,
    },
  });

  res.json({
    message: "Wydatek usunięty",
  });
});

export default router;