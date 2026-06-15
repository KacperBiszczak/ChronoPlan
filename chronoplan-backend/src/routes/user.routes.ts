import { Router } from "express";
import { prisma } from "../lib/prisma";
import bcrypt from "bcrypt";
import { authMiddleware } from "../middlewares/auth.middleware";
import { validateBody } from "../middlewares/validate.middleware";
import { registerUserSchema } from "../validators/user.validator";

const router = Router();

/**
 * @swagger
 * /users:
 *   get:
 *     summary: Pobranie listy użytkowników
 *     description: Zwraca listę użytkowników. Endpoint wymaga tokenu JWT.
 *     tags:
 *       - Users
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Lista użytkowników
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: "#/components/schemas/User"
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 */
router.get("/", authMiddleware, async (req, res) => {
  const users = await prisma.user.findMany();

  res.json(users);
});

/**
 * @swagger
 * /users:
 *   post:
 *     summary: Rejestracja użytkownika
 *     description: Tworzy nowe konto użytkownika.
 *     tags:
 *       - Users
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: "#/components/schemas/RegisterRequest"
 *     responses:
 *       201:
 *         description: Użytkownik został utworzony
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/User"
 *       409:
 *         description: Użytkownik z takim emailem już istnieje
 *       500:
 *         description: Błąd tworzenia użytkownika
 */
router.post("/", validateBody(registerUserSchema), async (req, res) => {
  try {
    const { name, email, password } = req.body;

    const existingUser = await prisma.user.findUnique({
      where: { email },
    });

    if (existingUser) {
      return res.status(409).json({
        message: "Użytkownik z takim emailem już istnieje",
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: {
        name,
        email,
        password: hashedPassword,
      },
      select: {
        id: true,
        name: true,
        email: true,
        createdAt: true,
      },
    });

    res.status(201).json(user);
  } catch (error) {
    console.error(error);

    res.status(500).json({
      message: "Błąd tworzenia użytkownika",
    });
  }
});

export default router;