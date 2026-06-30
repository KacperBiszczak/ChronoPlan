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