import { Router } from "express";

import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { validateBody } from "../middlewares/validate.middleware";
import { canAccessEvent, isEventOrganizer } from "../lib/event-access";
import {
  createDateOptionSchema,
  updateDateVoteSchema,
} from "../validators/date-vote.validator";

const router = Router();

/**
 * @swagger
 * /date-votes/event/{eventId}:
 *   get:
 *     summary: Pobiera propozycje terminów wydarzenia
 *     description: Zwraca listę propozycji terminów wraz z głosami uczestników.
 *     tags:
 *       - Date Votes
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID wydarzenia
 *     responses:
 *       200:
 *         description: Lista propozycji terminów
 *       400:
 *         description: Nieprawidłowe ID wydarzenia
 *       401:
 *         description: Brak autoryzacji
 *       403:
 *         description: Brak dostępu do głosowania tego wydarzenia
 *       500:
 *         description: Błąd pobierania propozycji terminów
 */
router.get("/event/:eventId", authMiddleware, async (req, res) => {
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
        message: "Brak dostępu do głosowania tego wydarzenia",
      });
      return;
    }

    const options = await prisma.dateOption.findMany({
      where: {
        eventId,
      },
      include: {
        votes: {
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
        },
      },
      orderBy: {
        proposedDate: "asc",
      },
    });

    res.json(options);
  } catch {
    res.status(500).json({
      message: "Błąd pobierania propozycji terminów",
    });
  }
});

/**
 * @swagger
 * /date-votes/options:
 *   post:
 *     summary: Dodaje propozycję terminu
 *     description: Dodaje nową propozycję terminu do wydarzenia. Dostępne tylko dla organizatora wydarzenia.
 *     tags:
 *       - Date Votes
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - eventId
 *               - proposedDate
 *             properties:
 *               eventId:
 *                 type: integer
 *                 example: 1
 *               proposedDate:
 *                 type: string
 *                 format: date-time
 *                 example: "2026-06-20T16:00:00.000Z"
 *     responses:
 *       201:
 *         description: Propozycja terminu została dodana
 *       400:
 *         description: Nieprawidłowe dane
 *       401:
 *         description: Brak autoryzacji
 *       403:
 *         description: Tylko organizator może dodawać propozycje terminów
 *       500:
 *         description: Błąd dodawania propozycji terminu
 */
router.post(
  "/options",
  authMiddleware,
  validateBody(createDateOptionSchema),
  async (req, res) => {
    try {
      const user = (req as any).user;
      const userId = Number(user?.userId);

      if (!userId) {
        res.status(401).json({
          message: "Brak autoryzacji",
        });
        return;
      }

      const { eventId, proposedDate } = req.body;

      const event = await isEventOrganizer(eventId, userId);

      if (!event) {
        res.status(403).json({
          message: "Tylko organizator może dodawać propozycje terminów",
        });
        return;
      }

      const option = await prisma.dateOption.create({
        data: {
          eventId,
          proposedDate: new Date(proposedDate),
        },
        include: {
          votes: true,
        },
      });

      res.status(201).json(option);
    } catch {
      res.status(500).json({
        message: "Błąd dodawania propozycji terminu",
      });
    }
  }
);

/**
 * @swagger
 * /date-votes/options/{optionId}/vote:
 *   patch:
 *     summary: Oddaje lub aktualizuje głos na termin
 *     description: Pozwala uczestnikowi wydarzenia zagłosować na propozycję terminu. Jeśli głos już istnieje, zostanie zaktualizowany.
 *     tags:
 *       - Date Votes
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: optionId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID propozycji terminu
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - status
 *             properties:
 *               status:
 *                 type: string
 *                 enum:
 *                   - YES
 *                   - MAYBE
 *                   - NO
 *                 example: "YES"
 *     responses:
 *       200:
 *         description: Głos został zapisany
 *       400:
 *         description: Nieprawidłowe ID propozycji terminu lub nieprawidłowy status
 *       401:
 *         description: Brak autoryzacji
 *       403:
 *         description: Brak dostępu do głosowania tego wydarzenia
 *       404:
 *         description: Nie znaleziono propozycji terminu
 *       500:
 *         description: Błąd zapisywania głosu
 */
router.patch(
  "/options/:optionId/vote",
  authMiddleware,
  validateBody(updateDateVoteSchema),
  async (req, res) => {
    try {
      const user = (req as any).user;
      const userId = Number(user?.userId);
      const optionId = Number(req.params.optionId);

      if (!userId) {
        res.status(401).json({
          message: "Brak autoryzacji",
        });
        return;
      }

      if (!optionId) {
        res.status(400).json({
          message: "Nieprawidłowe ID propozycji terminu",
        });
        return;
      }

      const option = await prisma.dateOption.findUnique({
        where: {
          id: optionId,
        },
      });

      if (!option) {
        res.status(404).json({
          message: "Nie znaleziono propozycji terminu",
        });
        return;
      }

      const event = await canAccessEvent(option.eventId, userId);

      if (!event) {
        res.status(403).json({
          message: "Brak dostępu do głosowania tego wydarzenia",
        });
        return;
      }

      const { status } = req.body;

      const vote = await prisma.dateVote.upsert({
        where: {
          optionId_userId: {
            optionId,
            userId,
          },
        },
        update: {
          status,
        },
        create: {
          optionId,
          userId,
          status,
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
      });

      res.json(vote);
    } catch {
      res.status(500).json({
        message: "Błąd zapisywania głosu",
      });
    }
  }
);

/**
 * @swagger
 * /date-votes/options/{optionId}/apply:
 *   patch:
 *     summary: Ustawia propozycję jako termin wydarzenia
 *     description: Aktualizuje datę wydarzenia na podstawie wybranej propozycji terminu. Dostępne tylko dla organizatora.
 *     tags:
 *       - Date Votes
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: optionId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID propozycji terminu
 *     responses:
 *       200:
 *         description: Termin wydarzenia został zaktualizowany
 *       400:
 *         description: Nieprawidłowe ID propozycji terminu
 *       401:
 *         description: Brak autoryzacji
 *       403:
 *         description: Tylko organizator może ustawić termin wydarzenia
 *       404:
 *         description: Nie znaleziono propozycji terminu
 *       500:
 *         description: Błąd ustawiania terminu wydarzenia
 */
router.patch("/options/:optionId/apply", authMiddleware, async (req, res) => {
  try {
    const user = (req as any).user;
    const userId = Number(user?.userId);
    const optionId = Number(req.params.optionId);

    if (!userId) {
      res.status(401).json({
        message: "Brak autoryzacji",
      });
      return;
    }

    if (!optionId) {
      res.status(400).json({
        message: "Nieprawidłowe ID propozycji terminu",
      });
      return;
    }

    const option = await prisma.dateOption.findUnique({
      where: {
        id: optionId,
      },
    });

    if (!option) {
      res.status(404).json({
        message: "Nie znaleziono propozycji terminu",
      });
      return;
    }

    const event = await isEventOrganizer(option.eventId, userId);

    if (!event) {
      res.status(403).json({
        message: "Tylko organizator może ustawić termin wydarzenia",
      });
      return;
    }

    const updatedEvent = await prisma.event.update({
      where: {
        id: option.eventId,
      },
      data: {
        date: option.proposedDate,
      },
    });

    res.json(updatedEvent);
  } catch {
    res.status(500).json({
      message: "Błąd ustawiania terminu wydarzenia",
    });
  }
});

/**
 * @swagger
 * /date-votes/options/{optionId}:
 *   delete:
 *     summary: Usuwa propozycję terminu
 *     description: Usuwa propozycję terminu wraz z oddanymi głosami. Dostępne tylko dla organizatora wydarzenia.
 *     tags:
 *       - Date Votes
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: optionId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID propozycji terminu
 *     responses:
 *       200:
 *         description: Propozycja terminu została usunięta
 *       400:
 *         description: Nieprawidłowe ID propozycji terminu
 *       401:
 *         description: Brak autoryzacji
 *       403:
 *         description: Tylko organizator może usuwać propozycje terminów
 *       404:
 *         description: Nie znaleziono propozycji terminu
 *       500:
 *         description: Błąd usuwania propozycji terminu
 */
router.delete("/options/:optionId", authMiddleware, async (req, res) => {
  try {
    const user = (req as any).user;
    const userId = Number(user?.userId);
    const optionId = Number(req.params.optionId);

    if (!userId) {
      res.status(401).json({
        message: "Brak autoryzacji",
      });
      return;
    }

    if (!optionId) {
      res.status(400).json({
        message: "Nieprawidłowe ID propozycji terminu",
      });
      return;
    }

    const option = await prisma.dateOption.findUnique({
      where: {
        id: optionId,
      },
    });

    if (!option) {
      res.status(404).json({
        message: "Nie znaleziono propozycji terminu",
      });
      return;
    }

    const event = await isEventOrganizer(option.eventId, userId);

    if (!event) {
      res.status(403).json({
        message: "Tylko organizator może usuwać propozycje terminów",
      });
      return;
    }

    await prisma.dateOption.delete({
      where: {
        id: optionId,
      },
    });

    res.json({
      message: "Propozycja terminu została usunięta",
    });
  } catch {
    res.status(500).json({
      message: "Błąd usuwania propozycji terminu",
    });
  }
});

export default router;