import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";

const router = Router();

router.post("/invite", authMiddleware, async (req, res) => {
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

router.patch("/:id/status", authMiddleware, async (req, res) => {
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