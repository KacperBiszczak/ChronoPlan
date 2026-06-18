import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { canAccessEvent, isEventOrganizer } from "../lib/event-access";
import { validateBody } from "../middlewares/validate.middleware";
import {
  createTaskSchema,
  updateTaskStatusSchema,
} from "../validators/task.validator";



const router = Router();

/**
 * @swagger
 * /tasks:
 *   post:
 *     summary: Utworzenie zadania
 *     description: Tworzy zadanie przypisane do wydarzenia. Wymaga dostępu do wydarzenia.
 *     tags:
 *       - Tasks
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: "#/components/schemas/TaskRequest"
 *     responses:
 *       201:
 *         description: Zadanie zostało utworzone
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/Task"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       404:
 *         description: Nie znaleziono wydarzenia
 *       500:
 *         description: Błąd tworzenia zadania
 */
router.post("/", authMiddleware, validateBody(createTaskSchema), async (req, res) => {
    try {
            const user = (req as any).user;
            const { title, description, eventId } = req.body;

            const event = await canAccessEvent(Number(eventId), user.userId);

            if (!event) {
                res.status(404).json({
                    message: "Nie znaleziono wydarzenia",
                });
                
                return;
            }

        const task = await prisma.task.create({
        data: {
            title,
            description,
            eventId: Number(eventId),
        },
        });

        res.status(201).json(task);
    } catch (error) {
        console.error(error);

        res.status(500).json({
            message: "Błąd tworzenia zadania",
        });
    }
});

/**
 * @swagger
 * /tasks/event/{eventId}:
 *   get:
 *     summary: Pobranie zadań wydarzenia
 *     description: Zwraca zadania przypisane do konkretnego wydarzenia. Wymaga dostępu do wydarzenia.
 *     tags:
 *       - Tasks
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
 *         description: Lista zadań wydarzenia
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: "#/components/schemas/Task"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       404:
 *         description: Nie znaleziono wydarzenia
 */
router.get("/event/:eventId", authMiddleware, async (req, res) => {
    const user = (req as any).user;
    const eventId = Number(req.params.eventId);

    const event = await canAccessEvent(Number(eventId), user.userId);

    if (!event) {
        res.status(404).json({
            message: "Nie znaleziono wydarzenia",
        });
        return;
    }

    const tasks = await prisma.task.findMany({
        where: {
            eventId,
        },
        orderBy: {
            createdAt: "asc",
        },
    });

    res.json(tasks);
});

/**
 * @swagger
 * /tasks/{id}/status:
 *   patch:
 *     summary: Zmiana statusu zadania
 *     description: Aktualizuje status zadania.
 *     tags:
 *       - Tasks
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: number
 *         description: ID zadania
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: "#/components/schemas/TaskStatusRequest"
 *     responses:
 *       200:
 *         description: Status zadania został zmieniony
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/Task"
 *       400:
 *         description: Nieprawidłowy status
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       404:
 *         description: Nie znaleziono zadania
 */
router.patch("/:id/status", authMiddleware, validateBody(updateTaskStatusSchema), async (req, res) => {
    try {
        const user = (req as any).user;
        const taskId = Number(req.params.id);
        const { status } = req.body;

        const allowedStatuses = ["TODO", "IN_PROGRESS", "DONE"];

        if (!allowedStatuses.includes(status)) {
        res.status(400).json({
            message: "Nieprawidłowy status",
        });
        return;
        }

        const task = await prisma.task.findFirst({
        where: {
            id: taskId,
            event: {
                creatorId: user.userId,
            },
        },
        });

        if (!task) {
        res.status(404).json({
            message: "Nie znaleziono zadania",
        });
        return;
        }

        const updatedTask = await prisma.task.update({
        where: {
            id: taskId,
        },
        data: {
            status,
        },
        });

        res.json(updatedTask);
    } catch (error) {
        console.error(error);

        res.status(500).json({
            message: "Błąd zmiany statusu zadania",
        });
    }
});

/**
 * @swagger
 * /tasks/{id}:
 *   delete:
 *     summary: Usuwa zadanie
 *     description: Usuwa zadanie z wydarzenia. Operacja dostępna tylko dla organizatora wydarzenia.
 *     tags:
 *       - Tasks
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID zadania
 *     responses:
 *       200:
 *         description: Zadanie zostało usunięte
 *       401:
 *         description: Brak autoryzacji
 *       403:
 *         description: Brak uprawnień do usunięcia zadania
 *       404:
 *         description: Nie znaleziono zadania
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
        message: "Nieprawidłowe ID zadania",
      });
      return;
    }

    const task = await prisma.task.findUnique({
      where: {
        id,
      },
      include: {
        event: true,
      },
    });

    if (!task) {
      res.status(404).json({
        message: "Nie znaleziono zadania",
      });
      return;
    }

    const organizerEvent = await isEventOrganizer(task.eventId, userId);

    if (!organizerEvent) {
      res.status(403).json({
        message: "Tylko organizator może usuwać zadania",
      });
      return;
    }

    await prisma.task.delete({
      where: {
        id,
      },
    });

    res.json({
      message: "Zadanie zostało usunięte",
    });
  } catch {
    res.status(500).json({
      message: "Błąd usuwania zadania",
    });
  }
});

export default router;