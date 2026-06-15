import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { canAccessEvent } from "../lib/event-access";

const router = Router();

// Create task
router.post("/", authMiddleware, async (req, res) => {
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

// Get tasks assigned to event
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

// Update task status
router.patch("/:id/status", authMiddleware, async (req, res) => {
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

export default router;