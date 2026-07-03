import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { validateBody } from "../middlewares/validate.middleware";
import {
  createEventSchema,
  updateEventSchema,
} from "../validators/event.validator";
import { canAccessEvent } from "../lib/event-access";
import { updateExistingGoogleCalendarEventForEvent, deleteExistingGoogleCalendarEventForEvent } from "../lib/google-calendar-event-sync";
import { BudgetMode } from "@prisma/client";

const router = Router();

/**
 * @swagger
 * /events:
 *   post:
 *     summary: Utworzenie wydarzenia
 *     description: Tworzy nowe wydarzenie i automatycznie dodaje twórcę jako organizatora.
 *     tags:
 *       - Events
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: "#/components/schemas/EventRequest"
 *     responses:
 *       201:
 *         description: Wydarzenie zostało utworzone
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/Event"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       500:
 *         description: Błąd tworzenia wydarzenia
 */
router.post("/", authMiddleware, validateBody(createEventSchema), async (req, res) => {
    try {
        const {
          title,
          description,
          date,
          budgetMode,
          locationName,
          locationAddress,
          latitude,
          longitude,
        } = req.body;

        const parsedBudgetMode = parseBudgetMode(budgetMode);

        if (parsedBudgetMode === null) {
          res.status(400).json({
            message: "Nieprawidłowy tryb budżetu",
          });
          return;
        }

        const user = (req as any).user;

        const event = await prisma.event.create({
            data: {
                title,
                description,
                date: new Date(date),
                budgetMode: parsedBudgetMode ?? "SHARED",
                locationName,
                locationAddress,
                latitude,
                longitude,
                creatorId: user.userId,
                participants: {
                create: {
                    userId: user.userId,
                    role: "ORGANIZER",
                    status: "ACCEPTED",
                },
                },
            },
            include: {
                participants: true,
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

/**
 * @swagger
 * /events:
 *   get:
 *     summary: Pobranie wydarzeń użytkownika
 *     description: Zwraca wydarzenia utworzone przez użytkownika oraz wydarzenia, w których jest zaakceptowanym uczestnikiem.
 *     tags:
 *       - Events
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Lista wydarzeń
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: "#/components/schemas/Event"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 */
router.get("/", authMiddleware, async (req, res) => {

    const user = (req as any).user;
    const userId = Number(user?.userId);

    if (!userId) {
        res.status(401).json({
            message: "Nieprawidłowy token użytkownika",
        });
        return;
    }

    const events = await prisma.event.findMany({
        where: {
            OR: [
                {
                    creatorId: userId,
                },
                {
                    participants: {
                        some: {
                            userId: userId,
                            status: "ACCEPTED",
                        },
                    }
                }
            ]
        },
        include: {
            creator: {
                select: {
                    id: true,
                    name: true,
                    email: true,
                },
            },
            participants: {
                include: {
                    user: {
                        select: {
                            id: true,
                            name: true,
                            email: true,
                        },
                    },
                },
            },
        },
        orderBy: {
            date: "asc",
        },
    });

    res.json(events);
});

/**
 * @swagger
 * /events/{id}:
 *   get:
 *     summary: Pobranie szczegółów wydarzenia
 *     description: Zwraca pojedyncze wydarzenie po ID.
 *     tags:
 *       - Events
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: number
 *         description: ID wydarzenia
 *     responses:
 *       200:
 *         description: Szczegóły wydarzenia
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/Event"
 *       404:
 *         description: Nie znaleziono wydarzenia
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 */
router.get("/:id", authMiddleware, async (req, res) => {
    const user = (req as any).user;
    const id = Number(req.params.id);

    const event = await canAccessEvent(id, user.userId);
    
    if (!event) {
        res.status(404).json({ 
            message: "Nie znaleziono wydarzenia"
        });
        return;
    }

    res.json(event);
});

/**
 * @swagger
 * /events/{id}:
 *   put:
 *     summary: Edycja wydarzenia
 *     description: Aktualizuje dane wydarzenia. Dostępne dla organizatora wydarzenia.
 *     tags:
 *       - Events
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: number
 *         description: ID wydarzenia
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: "#/components/schemas/EventRequest"
 *     responses:
 *       200:
 *         description: Wydarzenie zostało zaktualizowane
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/Event"
 *       404:
 *         description: Nie znaleziono wydarzenia
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 */
router.put("/:id", authMiddleware, validateBody(updateEventSchema), async (req, res) => {
    const user = (req as any).user;
    const id = Number(req.params.id);
    const {
      title,
      description,
      date,
      budgetMode,
      locationName,
      locationAddress,
      latitude,
      longitude,
    } = req.body;

    const parsedBudgetMode = parseBudgetMode(budgetMode);

    if (parsedBudgetMode === null) {
      res.status(400).json({
        message: "Nieprawidłowy tryb budżetu",
      });
      return;
    }

    const existingEvent = await prisma.event.findFirst({
        where: {
            id,
            creatorId: user.userId,
        },
    });

    if (!existingEvent) {
        res.status(404).json({ message: "Nie znaleziono wydarzenia" });
        return;
    }

    const updatedEvent = await prisma.event.update({
      where: {
        id,
      },
      data: {
        title,
        description,
        ...(date !== undefined
          ? {
              date: new Date(date),
            }
          : {}),
        ...(parsedBudgetMode
          ? {
              budgetMode: parsedBudgetMode,
            }
          : {}),
        locationName,
        locationAddress,
        latitude,
        longitude,
      },
    });

    try {
      await updateExistingGoogleCalendarEventForEvent(updatedEvent.id);
    } catch {
      // Nie blokujemy edycji wydarzenia, jeśli Google Calendar nie odpowie.
    }

    res.json(updatedEvent);
});

/**
 * @swagger
 * /events/{id}:
 *   delete:
 *     summary: Usunięcie wydarzenia
 *     description: Usuwa wydarzenie. Dostępne tylko dla organizatora.
 *     tags:
 *       - Events
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: number
 *         description: ID wydarzenia
 *     responses:
 *       200:
 *         description: Wydarzenie zostało usunięte
 *       404:
 *         description: Nie znaleziono wydarzenia
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 */
/**
 * @swagger
 * /events/{id}:
 *   delete:
 *     summary: Usuwa wydarzenie
 *     description: Usuwa wydarzenie razem z zadaniami, wydatkami i uczestnikami. Operacja dostępna tylko dla organizatora wydarzenia.
 *     tags:
 *       - Events
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID wydarzenia
 *     responses:
 *       200:
 *         description: Wydarzenie zostało usunięte
 *       400:
 *         description: Nieprawidłowe ID wydarzenia
 *       401:
 *         description: Brak autoryzacji
 *       403:
 *         description: Brak uprawnień do usunięcia wydarzenia
 *       404:
 *         description: Nie znaleziono wydarzenia
 */
router.delete("/:id", authMiddleware, async (req, res) => {
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
        message: "Nieprawidłowe ID wydarzenia",
      });
      return;
    }

    const event = await prisma.event.findUnique({
      where: {
        id,
      },
    });

    if (!event) {
      res.status(404).json({
        message: "Nie znaleziono wydarzenia",
      });
      return;
    }

    if (event.creatorId !== userId) {
      res.status(403).json({
        message: "Tylko organizator może usunąć wydarzenie",
      });
      return;
    }

    try {
      await deleteExistingGoogleCalendarEventForEvent(id);
    } catch {
      // Nie blokujemy usunięcia wydarzenia w ChronoPlan,
      // jeśli Google Calendar nie odpowie.
    }

    await prisma.$transaction([
      prisma.task.deleteMany({
        where: {
          eventId: id,
        },
      }),
      prisma.expense.deleteMany({
        where: {
          eventId: id,
        },
      }),
      prisma.eventParticipant.deleteMany({
        where: {
          eventId: id,
        },
      }),
      prisma.event.delete({
        where: {
          id,
        },
      }),
    ]);

    res.json({
      message: "Wydarzenie zostało usunięte",
    });
  } catch {
    res.status(500).json({
      message: "Błąd usuwania wydarzenia",
    });
  }
});

const isBudgetMode = (value: unknown): value is BudgetMode => {
  return Object.values(BudgetMode).includes(value as BudgetMode);
};

const parseBudgetMode = (value: unknown) => {
  if (value === undefined || value === null || value === "") {
    return undefined;
  }

  if (!isBudgetMode(value)) {
    return null;
  }

  return value;
};

export default router;
