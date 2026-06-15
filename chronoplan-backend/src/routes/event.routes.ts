import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";

const router = Router();

// Create event
router.post("/", authMiddleware, async (req, res) => {
    try {
        const { title, description, date } = req.body;
        const user = (req as any).user;

        const event = await prisma.event.create({
            data: {
                title,
                description,
                date: new Date(date),
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

// Get events
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

// Get event details
router.get("/:id", authMiddleware, async (req, res) => {
    const user = (req as any).user;
    const id = Number(req.params.id);

    const event = await prisma.event.findFirst({
        where: {
            id,
            creatorId: user.userId,
        },
    });

    if (!event) {
            res.status(404).json({ message: "Nie znaleziono wydarzenia" });
        return;
    }

    res.json(event);
});

// Update event
router.put("/:id", authMiddleware, async (req, res) => {
    const user = (req as any).user;
    const id = Number(req.params.id);
    const { title, description, date } = req.body;

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

    const data: {
        title?: string;
        description?: string;
        date?: Date;
    } = {};

    if (title !== undefined) data.title = title;
    if (description !== undefined) data.description = description;
    if (date !== undefined) data.date = new Date(date);

    const updatedEvent = await prisma.event.update({
        where: { id },
        data,
    });

    res.json(updatedEvent);
});

// Delete event
router.delete("/:id", authMiddleware, async (req, res) => {
    const user = (req as any).user;
    const id = Number(req.params.id);

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

    await prisma.event.delete({
        where: { id },
    });

    res.json({
        message: "Wydarzenie usunięte",
    });
});

export default router;