import { randomUUID } from "crypto";
import fs from "fs";
import path from "path";
import { Router, type Request, type Response } from "express";
import bcrypt from "bcrypt";
import multer from "multer";
import { prisma } from "../lib/prisma";
import jwt from "jsonwebtoken";
import { validateBody } from "../middlewares/validate.middleware";
import { loginSchema } from "../validators/auth.validator";
import { authMiddleware } from "../middlewares/auth.middleware";
import { updateProfileSchema } from "../validators/user.validator";


const router = Router();
const avatarUploadDir = path.join(process.cwd(), "uploads", "avatars");
const maxAvatarSizeInBytes = 3 * 1024 * 1024;
const avatarMimeExtensions: Record<string, string> = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp",
};

const userProfileSelect = {
  id: true,
  name: true,
  email: true,
  avatarUrl: true,
  profileColor: true,
  phone: true,
  bio: true,
  createdAt: true,
  updatedAt: true,
} as const;
const userProfileBaseSelect = {
  id: true,
  name: true,
  email: true,
  avatarUrl: true,
  phone: true,
  bio: true,
  createdAt: true,
  updatedAt: true,
} as const;

fs.mkdirSync(avatarUploadDir, { recursive: true });

const avatarUpload = multer({
  storage: multer.diskStorage({
    destination: (_req, _file, callback) => {
      callback(null, avatarUploadDir);
    },
    filename: (req, file, callback) => {
      const userId = Number((req as any).user?.userId) || "user";
      const extension =
        avatarMimeExtensions[file.mimetype] ||
        path.extname(file.originalname).toLowerCase();

      callback(null, `${userId}-${Date.now()}-${randomUUID()}${extension}`);
    },
  }),
  limits: {
    fileSize: maxAvatarSizeInBytes,
  },
  fileFilter: (_req, file, callback) => {
    if (!avatarMimeExtensions[file.mimetype]) {
      callback(new Error("INVALID_AVATAR_TYPE"));
      return;
    }

    callback(null, true);
  },
});

function runAvatarUpload(req: Request, res: Response) {
  return new Promise<void>((resolve, reject) => {
    avatarUpload.single("avatar")(req, res, (error) => {
      if (error) {
        reject(error);
        return;
      }

      resolve();
    });
  });
}

function getPublicAvatarUrl(req: Request, filename: string) {
  const host = req.get("host") || `localhost:${process.env.PORT || 5000}`;

  return `${req.protocol}://${host}/uploads/avatars/${filename}`;
}

function getStoredAvatarFileName(avatarUrl?: string | null) {
  if (!avatarUrl) {
    return null;
  }

  let pathname = avatarUrl;

  try {
    pathname = new URL(avatarUrl).pathname;
  } catch {
    // Local public paths are accepted as-is.
  }

  if (!pathname.startsWith("/uploads/avatars/")) {
    return null;
  }

  return path.basename(pathname);
}

async function deleteStoredAvatar(avatarUrl?: string | null) {
  const fileName = getStoredAvatarFileName(avatarUrl);

  if (!fileName || fileName === "." || fileName === "..") {
    return;
  }

  const resolvedUploadDir = path.resolve(avatarUploadDir);
  const filePath = path.resolve(resolvedUploadDir, fileName);

  if (!filePath.startsWith(`${resolvedUploadDir}${path.sep}`)) {
    return;
  }

  try {
    await fs.promises.unlink(filePath);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
      console.warn("Nie udało się usunąć avatara", error);
    }
  }
}

function getAvatarUploadErrorMessage(error: unknown) {
  if (error instanceof multer.MulterError && error.code === "LIMIT_FILE_SIZE") {
    return "Avatar może mieć maksymalnie 3 MB";
  }

  if (error instanceof Error && error.message === "INVALID_AVATAR_TYPE") {
    return "Avatar musi być obrazem JPG, PNG albo WebP";
  }

  return "Nie udało się przesłać avatara";
}

function isMissingProfileColorColumn(error: unknown) {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code?: string }).code === "P2022" &&
    String((error as { message?: string }).message || "").includes(
      "profileColor",
    )
  );
}

async function findUserProfileById(userId: number) {
  try {
    return await prisma.user.findUnique({
      where: {
        id: userId,
      },
      select: userProfileSelect,
    });
  } catch (error) {
    if (!isMissingProfileColorColumn(error)) {
      throw error;
    }

    const user = await prisma.user.findUnique({
      where: {
        id: userId,
      },
      select: userProfileBaseSelect,
    });

    return user ? { ...user, profileColor: null } : null;
  }
}

async function updateUserProfileById(
  userId: number,
  data: {
    name?: string;
    email?: string;
    avatarUrl?: string | null;
    profileColor?: string | null;
    phone?: string | null;
    bio?: string | null;
  },
) {
  try {
    return await prisma.user.update({
      where: {
        id: userId,
      },
      data,
      select: userProfileSelect,
    });
  } catch (error) {
    if (!isMissingProfileColorColumn(error)) {
      throw error;
    }

    const { profileColor: _profileColor, ...baseData } = data;
    const user = await prisma.user.update({
      where: {
        id: userId,
      },
      data: baseData,
      select: userProfileBaseSelect,
    });

    return { ...user, profileColor: null };
  }
}

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
        select: {
          id: true,
          name: true,
          email: true,
          password: true,
          avatarUrl: true,
        },
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

    const profile = await findUserProfileById(user.id);

    res.json({
        message: "Zalogowano poprawnie",
        token,
        user: {
        id: user.id,
        name: user.name,
        email: user.email,
        avatarUrl: user.avatarUrl,
        profileColor: profile?.profileColor ?? null,
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

    const loggedUser = await findUserProfileById(userId);

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

/**
 * @swagger
 * /auth/me:
 *   patch:
 *     summary: Aktualizuje profil aktualnie zalogowanego użytkownika
 *     tags:
 *       - Auth
 *     security:
 *       - bearerAuth: []
 */
router.patch(
  "/me",
  authMiddleware,
  validateBody(updateProfileSchema),
  async (req, res) => {
    try {
      const user = (req as any).user;
      const userId = Number(user?.userId);

      if (!userId) {
        res.status(401).json({
          message: "Nieprawidłowy token",
        });
        return;
      }

      const { name, email, avatarUrl, profileColor, phone, bio } = req.body;

      if (email) {
        const existingUser = await prisma.user.findFirst({
          where: {
            email,
            NOT: {
              id: userId,
            },
          },
        });

        if (existingUser) {
          res.status(409).json({
            message: "Użytkownik z takim emailem już istnieje",
          });
          return;
        }
      }

      const currentUser = await prisma.user.findUnique({
        where: {
          id: userId,
        },
        select: {
          avatarUrl: true,
        },
      });

      const updatedUser = await updateUserProfileById(userId, {
        name,
        email,
        avatarUrl,
        profileColor,
        phone,
        bio,
      });

      if (avatarUrl !== undefined && avatarUrl !== currentUser?.avatarUrl) {
        await deleteStoredAvatar(currentUser?.avatarUrl);
      }

      res.json(updatedUser);
    } catch {
      res.status(500).json({
        message: "Błąd aktualizacji profilu",
      });
    }
  }
);

router.post("/me/avatar", authMiddleware, async (req, res) => {
  try {
    const user = (req as any).user;
    const userId = Number(user?.userId);

    if (!userId) {
      res.status(401).json({
        message: "Nieprawidłowy token",
      });
      return;
    }

    await runAvatarUpload(req, res);

    const file = (req as Request & { file?: Express.Multer.File }).file;

    if (!file) {
      res.status(400).json({
        message: "Nie wybrano pliku avatara",
      });
      return;
    }

    const currentUser = await prisma.user.findUnique({
      where: {
        id: userId,
      },
      select: {
        avatarUrl: true,
      },
    });

    if (!currentUser) {
      await fs.promises.unlink(file.path).catch(() => undefined);
      res.status(404).json({
        message: "Nie znaleziono użytkownika",
      });
      return;
    }

    const avatarUrl = getPublicAvatarUrl(req, file.filename);

    const updatedUser = await updateUserProfileById(userId, {
      avatarUrl,
    });

    await deleteStoredAvatar(currentUser.avatarUrl);

    res.json(updatedUser);
  } catch (error) {
    const file = (req as Request & { file?: Express.Multer.File }).file;

    if (file) {
      await fs.promises.unlink(file.path).catch(() => undefined);
    }

    res.status(400).json({
      message: getAvatarUploadErrorMessage(error),
    });
  }
});

router.delete("/me/avatar", authMiddleware, async (req, res) => {
  try {
    const user = (req as any).user;
    const userId = Number(user?.userId);

    if (!userId) {
      res.status(401).json({
        message: "Nieprawidłowy token",
      });
      return;
    }

    const currentUser = await prisma.user.findUnique({
      where: {
        id: userId,
      },
      select: {
        avatarUrl: true,
      },
    });

    if (!currentUser) {
      res.status(404).json({
        message: "Nie znaleziono użytkownika",
      });
      return;
    }

    const updatedUser = await updateUserProfileById(userId, {
      avatarUrl: null,
    });

    await deleteStoredAvatar(currentUser.avatarUrl);

    res.json(updatedUser);
  } catch {
    res.status(500).json({
      message: "Nie udało się usunąć avatara",
    });
  }
});

export default router;
