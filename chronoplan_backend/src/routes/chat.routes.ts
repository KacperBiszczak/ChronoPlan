import { Router } from "express";

import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { validateBody } from "../middlewares/validate.middleware";
import { canAccessEvent } from "../lib/event-access";
import { createChatMessageSchema } from "../validators/chat.validator";

const router = Router();

const chatMessageInclude = {
  author: {
    select: {
      id: true,
      name: true,
      email: true,
      avatarUrl: true,
    },
  },
};

/**
 * @swagger
 * /chat/event/{eventId}:
 *   get:
 *     summary: Pobiera wiadomości czatu wydarzenia
 *     tags:
 *       - Chat
 *     security:
 *       - bearerAuth: []
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
        message: "Brak dostępu do czatu tego wydarzenia",
      });
      return;
    }

    const messages = await prisma.chatMessage.findMany({
      where: {
        eventId,
      },
      include: chatMessageInclude,
      orderBy: {
        createdAt: "asc",
      },
    });

    res.json(messages);
  } catch {
    res.status(500).json({
      message: "Błąd pobierania wiadomości",
    });
  }
});

/**
 * @swagger
 * /chat/messages:
 *   post:
 *     summary: Dodaje wiadomość do czatu wydarzenia
 *     tags:
 *       - Chat
 *     security:
 *       - bearerAuth: []
 */
router.post(
  "/messages",
  authMiddleware,
  validateBody(createChatMessageSchema),
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

      const { eventId, content } = req.body;

      const event = await canAccessEvent(eventId, userId);

      if (!event) {
        res.status(403).json({
          message: "Brak dostępu do czatu tego wydarzenia",
        });
        return;
      }

      const message = await prisma.chatMessage.create({
        data: {
          eventId,
          authorId: userId,
          content,
        },
        include: chatMessageInclude,
      });

      res.status(201).json(message);
    } catch {
      res.status(500).json({
        message: "Błąd wysyłania wiadomości",
      });
    }
  }
);

export default router;