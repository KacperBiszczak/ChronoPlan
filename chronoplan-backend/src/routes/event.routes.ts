import { Router } from "express";
import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";

const router = Router();

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

router.get("/", authMiddleware, async (req, res) => {
    const user = (req as any).user;

    const events = await prisma.event.findMany({
        where: {
        creatorId: user.userId,
        },
        orderBy: {
        date: "asc",
        },
    });

    res.json(events);
});

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