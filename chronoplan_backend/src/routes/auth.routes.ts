import { Router } from "express";
import bcrypt from "bcrypt";
import { prisma } from "../lib/prisma";
import jwt from "jsonwebtoken";
import { validateBody } from "../middlewares/validate.middleware";
import { loginSchema } from "../validators/auth.validator";
import { authMiddleware } from "../middlewares/auth.middleware";


const router = Router();

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Logowanie użytkownika
 *     description: Loguje użytkownika i zwraca token JWT.
 *     tags:
 *       - Auth
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: "#/components/schemas/LoginRequest"
 *     responses:
 *       200:
 *         description: Użytkownik zalogowany poprawnie
 *         content:
 *           application/json:
 *             schema:
 *               $ref: "#/components/schemas/AuthResponse"
 *       401:
 *         description: Nieprawidłowy email lub hasło
 */
router.post("/login", validateBody(loginSchema), async (req, res) => {
    const { email, password } = req.body;

    const user = await prisma.user.findUnique({
        where: { email },
    });

    if (!user) {
        return res.status(401).json({
        message: "Nieprawidłowy email lub hasło",
        });
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);

    if (!isPasswordValid) {
        return res.status(401).json({
        message: "Nieprawidłowy email lub hasło",
        });
    }

    const token = jwt.sign(
      {
        userId: user.id,
        email: user.email,
      },
      process.env.JWT_SECRET!,
      {
        expiresIn: "7d",
      }
    );

    res.json({
        message: "Zalogowano poprawnie",
        token,
        user: {
        id: user.id,
        name: user.name,
        email: user.email,
        },
    });
});

/**
 * @swagger
 * /auth/me:
 *   get:
 *     summary: Pobiera dane aktualnie zalogowanego użytkownika
 *     description: Zwraca dane użytkownika na podstawie przesłanego tokenu JWT.
 *     tags:
 *       - Auth
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Dane aktualnie zalogowanego użytkownika
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/User'
 *       401:
 *         description: Brak tokenu lub nieprawidłowy token
 *       404:
 *         description: Nie znaleziono użytkownika
 *       500:
 *         description: Błąd pobierania danych użytkownika
 */
router.get("/me", authMiddleware, async (req, res) => {
  try {
    const user = (req as any).user;
    const userId = Number(user?.userId);

    if (!userId) {
      res.status(401).json({
        message: "Nieprawidłowy token",
      });
      return;
    }

    const loggedUser = await prisma.user.findUnique({
      where: {
        id: userId,
      },
      select: {
        id: true,
        name: true,
        email: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!loggedUser) {
      res.status(404).json({
        message: "Nie znaleziono użytkownika",
      });
      return;
    }

    res.json(loggedUser);
  } catch {
    res.status(500).json({
      message: "Błąd pobierania danych użytkownika",
    });
  }
});

export default router;