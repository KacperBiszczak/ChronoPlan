import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { validateBody } from "../middlewares/validate.middleware";
import {
  inviteParticipantSchema,
  updateParticipantStatusSchema,
} from "../validators/participant.validator";

const router = Router();

/**
 * @swagger
 * /participants/invite:
 *   post:
 *     summary: Zaproszenie uczestnika do wydarzenia
 *     description: Zaprasza użytkownika do wydarzenia na podstawie adresu email. Wymaga uprawnień organizatora wydarzenia.
 *     tags:
 *       - Participants
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: "#/components/schemas/InviteParticipantRequest"
 *     responses:
 *       201:
 *         description: Uczestnik został zaproszony
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/EventParticipant"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       404:
 *         description: Nie znaleziono wydarzenia lub użytkownika
 *       409:
 *         description: Użytkownik jest już uczestnikiem wydarzenia
 *       500:
 *         description: Błąd zapraszania uczestnika
 */
router.post("/invite", authMiddleware, validateBody(inviteParticipantSchema), async (req, res) => {
  try {
    const user = (req as any).user;
    const { eventId, email } = req.body;

    const event = await prisma.event.findFirst({
      where: {
        id: Number(eventId),
        creatorId: user.userId,
      },
    });

    if (!event) {
      res.status(404).json({
        message: "Nie znaleziono wydarzenia albo nie masz uprawnień",
      });
      return;
    }

    const invitedUser = await prisma.user.findUnique({
      where: {
        email,
      },
    });

    if (!invitedUser) {
      res.status(404).json({
        message: "Nie znaleziono użytkownika z takim emailem",
      });
      return;
    }

    const existingParticipant = await prisma.eventParticipant.findUnique({
      where: {
        eventId_userId: {
          eventId: Number(eventId),
          userId: invitedUser.id,
        },
      },
    });

    if (existingParticipant) {
      res.status(409).json({
        message: "Ten użytkownik jest już uczestnikiem wydarzenia",
      });
      return;
    }

    const participant = await prisma.eventParticipant.create({
      data: {
        eventId: Number(eventId),
        userId: invitedUser.id,
        role: "PARTICIPANT",
        status: "INVITED",
      },
      include: {
        user: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
      },
    });

    res.status(201).json(participant);
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Błąd zapraszania uczestnika",
    });
  }
});

/**
 * @swagger
 * /participants/my-invitations:
 *   get:
 *     summary: Pobranie moich zaproszeń
 *     description: Zwraca zaproszenia oczekujące dla zalogowanego użytkownika.
 *     tags:
 *       - Participants
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Lista zaproszeń użytkownika
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: "#/components/schemas/EventParticipant"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       500:
 *         description: Błąd pobierania zaproszeń
 */
router.get("/my-invitations", authMiddleware, async (req, res) => {
  try {
    const user = (req as any).user;

    const invitations = await prisma.eventParticipant.findMany({
      where: {
        userId: user.userId,
        status: "INVITED",
      },
      include: {
        event: {
          select: {
            id: true,
            title: true,
            description: true,
            date: true,
            creator: {
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
        createdAt: "desc",
      },
    });

    res.json(invitations);
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Błąd pobierania zaproszeń",
    });
  }
});

/**
 * @swagger
 * /participants/event/{eventId}:
 *   get:
 *     summary: Pobranie uczestników wydarzenia
 *     description: Zwraca listę uczestników konkretnego wydarzenia. Wymaga bycia uczestnikiem wydarzenia.
 *     tags:
 *       - Participants
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
 *         description: Lista uczestników wydarzenia
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: "#/components/schemas/EventParticipant"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       403:
 *         description: Użytkownik nie jest uczestnikiem wydarzenia
 */
router.get("/event/:eventId", authMiddleware, async (req, res) => {
  const user = (req as any).user;
  const eventId = Number(req.params.eventId);

  const currentParticipant = await prisma.eventParticipant.findFirst({
    where: {
      eventId,
      userId: user.userId,
    },
  });

  if (!currentParticipant) {
    res.status(403).json({
      message: "Nie jesteś uczestnikiem tego wydarzenia",
    });
    return;
  }

  const participants = await prisma.eventParticipant.findMany({
    where: {
      eventId,
    },
    include: {
      user: {
        select: {
          id: true,
          name: true,
          email: true,
        },
      },
    },
    orderBy: {
      createdAt: "asc",
    },
  });

  res.json(participants);
});

/**
 * @swagger
 * /participants/{id}/status:
 *   patch:
 *     summary: Zmiana statusu zaproszenia
 *     description: Pozwala zaproszonemu użytkownikowi zaakceptować lub odrzucić zaproszenie.
 *     tags:
 *       - Participants
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: number
 *         description: ID zaproszenia / uczestnictwa
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: "#/components/schemas/ParticipantStatusRequest"
 *     responses:
 *       200:
 *         description: Status zaproszenia został zmieniony
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/EventParticipant"
 *       400:
 *         description: Nieprawidłowy status uczestnictwa
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       404:
 *         description: Nie znaleziono zaproszenia
 *       500:
 *         description: Błąd zmiany statusu zaproszenia
 */
router.patch("/:id/status", authMiddleware, validateBody(updateParticipantStatusSchema), async (req, res) => {
  try {
    const user = (req as any).user;
    const id = Number(req.params.id);

    const { status } = req.body ?? {};

    const allowedStatuses = ["INVITED", "ACCEPTED", "DECLINED"];

    if (!status) {
        res.status(400).json({
            message: "Status jest wymagany",
        });
        return;
    }

    if (!allowedStatuses.includes(status)) {
        res.status(400).json({
            message: "Nieprawidłowy status uczestnictwa",
        });
        return;
    }

    const participant = await prisma.eventParticipant.findFirst({
        where: {
            id,
            userId: user.userId,
        },
    });

    if (!participant) {
        res.status(404).json({
            message: "Nie znaleziono zaproszenia",
        });
        return;
    }

    const updatedParticipant = await prisma.eventParticipant.update({
        where: {
            id,
        },
        data: {
            status,
        },
    });

    res.json(updatedParticipant);
    } catch (error) {
        console.error(error);

        res.status(500).json({
            message: "Błąd zmiany statusu zaproszenia",
        });
    }
});

export default router;