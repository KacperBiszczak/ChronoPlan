import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { canAccessEvent, isEventOrganizer } from "../lib/event-access";
import { validateBody } from "../middlewares/validate.middleware";
import { createExpenseSchema, updateExpenseSchema } from "../validators/expense.validator";

const expenseInclude = {
  paidBy: {
    select: {
      id: true,
      name: true,
      email: true,
      avatarUrl: true,
    },
  },
};

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
    const userId = Number(user?.userId);
    const { title, amount, eventId, paidById } = req.body;

    if (!userId) {
      res.status(401).json({
        message: "Brak autoryzacji",
      });
      return;
    }

    const payerId = paidById ?? userId;

    const payerParticipant = await prisma.eventParticipant.findFirst({
      where: {
        eventId,
        userId: payerId,
        status: "ACCEPTED",
      },
    });

    if (!payerParticipant) {
      res.status(400).json({
        message: "Osoba płacąca musi być uczestnikiem wydarzenia",
      });
      return;
    }

    const organizerEvent = await isEventOrganizer(eventId, userId);

    if (!organizerEvent) {
      res.status(403).json({
        message: "Tylko organizator może dodawać wydatki",
      });
      return;
    }

    const expense = await prisma.expense.create({
      data: {
        title,
        amount,
        eventId,
        paidById: payerId,
      },
      include: expenseInclude,
    });

    res.status(201).json(expense);
  } catch {
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
    include: expenseInclude,
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
  try {
    const user = (req as any).user;
    const userId = Number(user?.userId);
    const eventId = Number(req.params.eventId);

    if (!userId) {
      res.status(401).json({
        message: "Brak autoryzacji",
      });
      return;
    }

    if (!eventId) {
      res.status(400).json({
        message: "Nieprawidłowe ID wydarzenia",
      });
      return;
    }

    const event = await canAccessEvent(eventId, userId);

    if (!event) {
      res.status(403).json({
        message: "Brak dostępu do budżetu tego wydarzenia",
      });
      return;
    }

    const participants = await prisma.eventParticipant.findMany({
      where: {
        eventId,
        status: "ACCEPTED",
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: {
        createdAt: "asc",
      },
    });

    const expenses = await prisma.expense.findMany({
      where: {
        eventId,
      },
      include: expenseInclude,
    });

    const totalExpenses = expenses.reduce((sum, expense) => {
      return sum + expense.amount;
    }, 0);

    const paidExpenses = expenses.filter((expense) => expense.paidById !== null);

    const settledExpensesTotal = paidExpenses.reduce((sum, expense) => {
      return sum + expense.amount;
    }, 0);

    const unassignedExpensesTotal = expenses
      .filter((expense) => expense.paidById === null)
      .reduce((sum, expense) => {
        return sum + expense.amount;
      }, 0);

    if (participants.length === 0) {
      res.json({
        totalExpenses,
        settledExpensesTotal,
        unassignedExpensesTotal,
        participantCount: 0,
        perPersonShare: 0,
        balances: [],
        settlements: [],
      });
      return;
    }

    const perPersonShare = settledExpensesTotal / participants.length;

    const balances = participants.map((participant) => {
      const paid = paidExpenses
        .filter((expense) => expense.paidById === participant.userId)
        .reduce((sum, expense) => {
          return sum + expense.amount;
        }, 0);

      const balance = paid - perPersonShare;

      return {
        user: participant.user,
        paid,
        share: perPersonShare,
        balance,
      };
    });

    const creditors = balances
      .filter((item) => item.balance > 0.01)
      .map((item) => ({
        user: item.user,
        amount: item.balance,
      }));

    const debtors = balances
      .filter((item) => item.balance < -0.01)
      .map((item) => ({
        user: item.user,
        amount: Math.abs(item.balance),
      }));

    const settlements: {
      from: {
        id: number;
        name: string;
        email: string;
        avatarUrl: string | null;
      };
      to: {
        id: number;
        name: string;
        email: string;
        avatarUrl: string | null;
      };
      amount: number;
    }[] = [];

    let debtorIndex = 0;
    let creditorIndex = 0;

    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      const debtor = debtors[debtorIndex];
      const creditor = creditors[creditorIndex];

      if (!debtor || !creditor) {
        break;
      }

      const amount = Math.min(debtor.amount, creditor.amount);

      settlements.push({
        from: debtor.user,
        to: creditor.user,
        amount,
      });

      debtor.amount -= amount;
      creditor.amount -= amount;

      if (debtor.amount <= 0.01) {
        debtorIndex += 1;
      }

      if (creditor.amount <= 0.01) {
        creditorIndex += 1;
      }
    }

    res.json({
      totalExpenses,
      settledExpensesTotal,
      unassignedExpensesTotal,
      participantCount: participants.length,
      perPersonShare,
      balances,
      settlements,
    });
  } catch {
    res.status(500).json({
      message: "Błąd podsumowania wydatków",
    });
  }
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

  const organizerEvent = await isEventOrganizer(expense.eventId, user.userId);

  if (!organizerEvent) {
    res.status(403).json({
      message: "Tylko organizator może usuwać wydatki",
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

/**
 * @swagger
 * /expenses/{id}:
 *   patch:
 *     summary: Edytuje wydatek
 *     description: Pozwala organizatorowi wydarzenia edytować nazwę i kwotę wydatku.
 *     tags:
 *       - Expenses
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID wydatku
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               title:
 *                 type: string
 *                 example: Pizza
 *               amount:
 *                 type: number
 *                 example: 120.50
 *     responses:
 *       200:
 *         description: Wydatek został zaktualizowany
 *       400:
 *         description: Nieprawidłowe dane
 *       401:
 *         description: Brak autoryzacji
 *       403:
 *         description: Brak uprawnień
 *       404:
 *         description: Nie znaleziono wydatku
 */
router.patch(
  "/:id",
  authMiddleware,
  validateBody(updateExpenseSchema),
  async (req, res) => {
    try {
      const user = (req as any).user;
      const userId = Number(user?.userId);
      const id = Number(req.params.id);

      if (!userId) {
        res.status(401).json({
          message: "Brak autoryzacji",
        });
        return;
      }

      if (!id) {
        res.status(400).json({
          message: "Nieprawidłowe ID wydatku",
        });
        return;
      }

      const expense = await prisma.expense.findUnique({
        where: {
          id,
        },
      });

      if (!expense) {
        res.status(404).json({
          message: "Nie znaleziono wydatku",
        });
        return;
      }

      const organizerEvent = await isEventOrganizer(expense.eventId, userId);

      if (!organizerEvent) {
        res.status(403).json({
          message: "Tylko organizator może edytować wydatki",
        });
        return;
      }

      const { title, amount, paidById  } = req.body;

      if (paidById !== undefined && paidById !== null) {
        const payerParticipant = await prisma.eventParticipant.findFirst({
          where: {
            eventId: expense.eventId,
            userId: paidById,
            status: "ACCEPTED",
          },
        });

        if (!payerParticipant) {
          res.status(400).json({
            message: "Osoba płacąca musi być uczestnikiem wydarzenia",
          });
          return;
        }
      }

      const updatedExpense = await prisma.expense.update({
        where: {
          id,
        },
        data: {
          ...(title !== undefined ? { title } : {}),
          ...(amount !== undefined ? { amount } : {}),
          paidById,
        },
        include: expenseInclude,
      });

      res.json(updatedExpense);
    } catch {
      res.status(500).json({
        message: "Błąd edycji wydatku",
      });
    }
  }
);

export default router;