import { Router } from "express";
import bcrypt from "bcrypt";
import { prisma } from "../lib/prisma";
import jwt from "jsonwebtoken";
import { validateBody } from "../middlewares/validate.middleware";
import { loginSchema } from "../validators/auth.validator";


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
        expiresIn: "7d" 
    });

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

export default router;