import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { canAccessEvent, isEventOrganizer } from "../lib/event-access";
import { validateBody } from "../middlewares/validate.middleware";
import { createExpenseSchema, updateExpenseSchema } from "../validators/expense.validator";
import {
  buildBudgetSummaryForEvent,
  serializeSettlement,
  settlementInclude,
} from "../lib/budget-summary";
import {
  BudgetMode,
  ExpenseSettlementType,
  ExpenseVisibility,
} from "@prisma/client";

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
    const {
      title,
      amount,
      eventId,
      paidById,
      category,
      visibility,
      settlementType,
    } = req.body;

    if (!userId) {
      res.status(401).json({
        message: "Brak autoryzacji",
      });
      return;
    }

    const event = await prisma.event.findUnique({
      where: {
        id: Number(eventId),
      },
    });

    if (!event) {
      res.status(404).json({
        message: "Nie znaleziono wydarzenia",
      });
      return;
    }

    const parsedVisibility = parseExpenseVisibility(visibility);

    if (parsedVisibility === null) {
      res.status(400).json({
        message: "Nieprawidłowa widoczność wydatku",
      });
      return;
    }

    const parsedSettlementType = parseExpenseSettlementType(settlementType);

    if (parsedSettlementType === null) {
      res.status(400).json({
        message: "Nieprawidłowy typ rozliczenia wydatku",
      });
      return;
    }

    const defaults = getExpenseDefaultsForBudgetMode(event.budgetMode);

    const finalVisibility =
      event.budgetMode === "MIXED"
        ? parsedVisibility ?? defaults.visibility
        : defaults.visibility;

    const finalSettlementType =
      event.budgetMode === "MIXED"
        ? parsedSettlementType ?? defaults.settlementType
        : defaults.settlementType;

    if (
      finalVisibility === "ORGANIZER_ONLY" &&
      finalSettlementType === "SPLIT_EQUALLY"
    ) {
      res.status(400).json({
        message:
          "Wydatek rozliczany między uczestnikami musi być widoczny dla uczestników",
      });
      return;
    }

    const payerId = paidById ?? userId;

    const payerIsOrganizer = payerId === event.creatorId;

    const payerParticipant = payerIsOrganizer
      ? null
      : await prisma.eventParticipant.findFirst({
          where: {
            eventId: Number(eventId),
            userId: payerId,
            status: "ACCEPTED",
          },
        });

    if (!payerIsOrganizer && !payerParticipant) {
      res.status(400).json({
        message: "Osoba płacąca musi być organizatorem albo uczestnikiem wydarzenia",
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
        category: category?.trim() || null,
        visibility: finalVisibility,
        settlementType: finalSettlementType,
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
      message: "Nie masz dostępu do tego wydarzenia",
    });
    return;
  }

  const isOrganizer = event.creatorId === userId;

  if (!isOrganizer && event.budgetMode === "PRIVATE") {
    res.json([]);
    return;
  }

  const expenseWhere =
    isOrganizer || event.budgetMode === "SHARED"
      ? {
          eventId,
        }
      : {
          eventId,
          visibility: "PARTICIPANTS" as const,
        };

  const expenses = await prisma.expense.findMany({
    where: expenseWhere,
    include: expenseInclude,
    orderBy: {
      createdAt: "desc",
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

    const summary = await buildBudgetSummaryForEvent(event, userId);

    res.json(summary);

  } catch {
    res.status(500).json({
      message: "Błąd podsumowania wydatków",
    });
  }
});

router.get("/event/:eventId/settlements", authMiddleware, async (req, res) => {
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
        message: "Brak dostępu do rozliczeń tego wydarzenia",
      });
      return;
    }

    const summary = await buildBudgetSummaryForEvent(event, userId);

    res.json(summary.settlements);
  } catch {
    res.status(500).json({
      message: "Błąd pobierania rozliczeń",
    });
  }
});

router.patch(
  "/settlements/:id/mark-paid",
  authMiddleware,
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
          message: "Nieprawidłowe ID rozliczenia",
        });
        return;
      }

      const settlement = await prisma.settlement.findUnique({
        where: {
          id,
        },
      });

      if (!settlement) {
        res.status(404).json({
          message: "Nie znaleziono rozliczenia",
        });
        return;
      }

      const event = await canAccessEvent(settlement.eventId, userId);

      if (!event || settlement.fromUserId !== userId) {
        res.status(403).json({
          message: "Tylko osoba, która ma zapłacić, może oznaczyć rozliczenie jako zapłacone",
        });
        return;
      }

      if (settlement.status !== "PENDING") {
        res.status(400).json({
          message: "Tylko rozliczenie do zapłaty można oznaczyć jako zapłacone",
        });
        return;
      }

      const updatedSettlement = await prisma.settlement.update({
        where: {
          id,
        },
        data: {
          status: "MARKED_AS_PAID",
          paidAt: new Date(),
          confirmedAt: null,
        },
        include: settlementInclude,
      });

      res.json(serializeSettlement(updatedSettlement));
    } catch {
      res.status(500).json({
        message: "Błąd oznaczania rozliczenia jako zapłacone",
      });
    }
  },
);

router.patch("/settlements/:id/confirm", authMiddleware, async (req, res) => {
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
        message: "Nieprawidłowe ID rozliczenia",
      });
      return;
    }

    const settlement = await prisma.settlement.findUnique({
      where: {
        id,
      },
    });

    if (!settlement) {
      res.status(404).json({
        message: "Nie znaleziono rozliczenia",
      });
      return;
    }

    const event = await canAccessEvent(settlement.eventId, userId);

    if (!event || settlement.toUserId !== userId) {
      res.status(403).json({
        message: "Tylko odbiorca może potwierdzić otrzymanie pieniędzy",
      });
      return;
    }

    if (settlement.status !== "MARKED_AS_PAID") {
      res.status(400).json({
        message: "Potwierdzić można tylko rozliczenie oczekujące na potwierdzenie",
      });
      return;
    }

    const updatedSettlement = await prisma.settlement.update({
      where: {
        id,
      },
      data: {
        status: "CONFIRMED",
        confirmedAt: new Date(),
      },
      include: settlementInclude,
    });

    res.json(serializeSettlement(updatedSettlement));
  } catch {
    res.status(500).json({
      message: "Błąd potwierdzania rozliczenia",
    });
  }
});

router.patch("/settlements/:id/cancel", authMiddleware, async (req, res) => {
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
        message: "Nieprawidłowe ID rozliczenia",
      });
      return;
    }

    const settlement = await prisma.settlement.findUnique({
      where: {
        id,
      },
    });

    if (!settlement) {
      res.status(404).json({
        message: "Nie znaleziono rozliczenia",
      });
      return;
    }

    const organizerEvent = await isEventOrganizer(settlement.eventId, userId);

    if (!organizerEvent) {
      res.status(403).json({
        message: "Tylko organizator może anulować rozliczenie",
      });
      return;
    }

    if (settlement.status === "CONFIRMED") {
      res.status(400).json({
        message: "Nie można anulować potwierdzonego rozliczenia",
      });
      return;
    }

    const updatedSettlement = await prisma.settlement.update({
      where: {
        id,
      },
      data: {
        status: "CANCELLED",
      },
      include: settlementInclude,
    });

    res.json(serializeSettlement(updatedSettlement));
  } catch {
    res.status(500).json({
      message: "Błąd anulowania rozliczenia",
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

      const event = await prisma.event.findUnique({
        where: {
          id: expense.eventId,
        },
      });

      if (!event) {
        res.status(404).json({
          message: "Nie znaleziono wydarzenia",
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

      const {
        title,
        amount,
        paidById,
        category,
        visibility,
        settlementType,
      } = req.body;

      const parsedVisibility = parseExpenseVisibility(visibility);

      if (parsedVisibility === null) {
        res.status(400).json({
          message: "Nieprawidłowa widoczność wydatku",
        });
        return;
      }

      const parsedSettlementType = parseExpenseSettlementType(settlementType);

      if (parsedSettlementType === null) {
        res.status(400).json({
          message: "Nieprawidłowy typ rozliczenia wydatku",
        });
        return;
      }

      const defaults = getExpenseDefaultsForBudgetMode(event.budgetMode);

      const finalVisibility =
        event.budgetMode === "MIXED"
          ? parsedVisibility
          : defaults.visibility;

      const finalSettlementType =
        event.budgetMode === "MIXED"
          ? parsedSettlementType
          : defaults.settlementType;

      const nextVisibility = finalVisibility ?? expense.visibility;
      const nextSettlementType = finalSettlementType ?? expense.settlementType;

      if (
        nextVisibility === "ORGANIZER_ONLY" &&
        nextSettlementType === "SPLIT_EQUALLY"
      ) {
        res.status(400).json({
          message:
            "Wydatek rozliczany między uczestnikami musi być widoczny dla uczestników",
        });
        return;
      }

      if (paidById !== undefined && paidById !== null) {
        const payerIsOrganizer = paidById === event.creatorId;

        const payerParticipant = payerIsOrganizer
          ? null
          : await prisma.eventParticipant.findFirst({
              where: {
                eventId: expense.eventId,
                userId: paidById,
                status: "ACCEPTED",
              },
            });

        if (!payerIsOrganizer && !payerParticipant) {
          res.status(400).json({
            message: "Osoba płacąca musi być organizatorem albo uczestnikiem wydarzenia",
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
          ...(amount !== undefined ? { amount: Number(amount) } : {}),
          ...(category !== undefined
            ? {
                category: category?.trim() || null,
              }
            : {}),

          ...(finalVisibility
            ? {
                visibility: finalVisibility,
              }
            : {}),

          ...(finalSettlementType
            ? {
                settlementType: finalSettlementType,
              }
            : {}),
          ...(paidById !== undefined
            ? {
                paidById,
              }
            : {}),
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

const isExpenseVisibility = (
  value: unknown,
): value is ExpenseVisibility => {
  return Object.values(ExpenseVisibility).includes(
    value as ExpenseVisibility,
  );
};

const isExpenseSettlementType = (
  value: unknown,
): value is ExpenseSettlementType => {
  return Object.values(ExpenseSettlementType).includes(
    value as ExpenseSettlementType,
  );
};

const parseExpenseVisibility = (value: unknown) => {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }

  if (!isExpenseVisibility(value)) {
    return null;
  }

  return value;
};

const parseExpenseSettlementType = (value: unknown) => {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }

  if (!isExpenseSettlementType(value)) {
    return null;
  }

  return value;
};

const getExpenseDefaultsForBudgetMode = (budgetMode: BudgetMode) => {
  if (budgetMode === "PRIVATE") {
    return {
      visibility: "ORGANIZER_ONLY" as ExpenseVisibility,
      settlementType: "NONE" as ExpenseSettlementType,
    };
  }

  if (budgetMode === "SHARED") {
    return {
      visibility: "PARTICIPANTS" as ExpenseVisibility,
      settlementType: "SPLIT_EQUALLY" as ExpenseSettlementType,
    };
  }

  return {
    visibility: "ORGANIZER_ONLY" as ExpenseVisibility,
    settlementType: "NONE" as ExpenseSettlementType,
  };
};

export default router;
