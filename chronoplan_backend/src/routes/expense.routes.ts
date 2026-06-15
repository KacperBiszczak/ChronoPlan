import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { canAccessEvent } from "../lib/event-access";
import { validateBody } from "../middlewares/validate.middleware";
import { createExpenseSchema } from "../validators/expense.validator";

const router = Router();

/**
 * @swagger
 * /expenses:
 *   post:
 *     summary: Dodanie wydatku
 *     description: Dodaje wydatek do wydarzenia. Wymaga dostępu do wydarzenia.
 *     tags:
 *       - Expenses
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: "#/components/schemas/ExpenseRequest"
 *     responses:
 *       201:
 *         description: Wydatek został dodany
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/Expense"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       404:
 *         description: Nie znaleziono wydarzenia
 *       500:
 *         description: Błąd dodawania wydatku
 */
router.post("/", authMiddleware, validateBody(createExpenseSchema), async (req, res) => {
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

/**
 * @swagger
 * /expenses/event/{eventId}:
 *   get:
 *     summary: Pobranie wydatków wydarzenia
 *     description: Zwraca listę wydatków przypisanych do wydarzenia. Wymaga dostępu do wydarzenia.
 *     tags:
 *       - Expenses
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: number
 *         description: ID wydarzenia
 *     responses:
 *       200:
 *         description: Lista wydatków wydarzenia
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: "#/components/schemas/Expense"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       404:
 *         description: Nie znaleziono wydarzenia
 */
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

/**
 * @swagger
 * /expenses/event/{eventId}/summary:
 *   get:
 *     summary: Podsumowanie wydatków wydarzenia
 *     description: Zwraca sumę wszystkich wydatków przypisanych do wydarzenia.
 *     tags:
 *       - Expenses
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: number
 *         description: ID wydarzenia
 *     responses:
 *       200:
 *         description: Suma wydatków wydarzenia
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/ExpenseSummary"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       404:
 *         description: Nie znaleziono wydarzenia
 */
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

/**
 * @swagger
 * /expenses/{id}:
 *   delete:
 *     summary: Usunięcie wydatku
 *     description: Usuwa wydatek przypisany do wydarzenia.
 *     tags:
 *       - Expenses
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: number
 *         description: ID wydatku
 *     responses:
 *       200:
 *         description: Wydatek został usunięty
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       404:
 *         description: Nie znaleziono wydatku
 */
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