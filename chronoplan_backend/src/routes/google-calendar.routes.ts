import { Router } from "express";
import jwt, { type JwtPayload } from "jsonwebtoken";
import { google } from "googleapis";

import { prisma } from "../lib/prisma";
import { authMiddleware } from "../middlewares/auth.middleware";
import { canAccessEvent } from "../lib/event-access";

const router = Router();

const GOOGLE_CALENDAR_SCOPES = [
  "https://www.googleapis.com/auth/calendar.events",
];

const getOAuthClient = () => {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  const redirectUri = process.env.GOOGLE_REDIRECT_URI;

  if (!clientId || !clientSecret || !redirectUri) {
    throw new Error("Brak konfiguracji Google Calendar OAuth");
  }

  return new google.auth.OAuth2(
    clientId,
    clientSecret,
    redirectUri,
  );
};

type UnknownRecord = Record<string, unknown>;

const isObject = (value: unknown): value is UnknownRecord => {
  return typeof value === "object" && value !== null;
};

const getStringValue = (
  object: UnknownRecord | null,
  key: string,
) => {
  if (!object) return null;

  const value = object[key];

  return typeof value === "string" ? value : null;
};

const getNumberValue = (
  object: UnknownRecord | null,
  key: string,
) => {
  if (!object) return null;

  const value = object[key];

  return typeof value === "number" ? value : null;
};

const getGoogleErrorData = (error: unknown) => {
  if (!isObject(error)) return null;

  const response = isObject(error.response)
    ? error.response
    : null;

  const data = response && isObject(response.data)
    ? response.data
    : null;

  return {
    response,
    data,
  };
};

const getGoogleErrorStatus = (error: unknown) => {
  if (!isObject(error)) return 500;

  const { response } = getGoogleErrorData(error) ?? {};

  const responseStatus = response
    ? getNumberValue(response, "status")
    : null;

  const errorCode = getNumberValue(error, "code");

  return responseStatus ?? errorCode ?? 500;
};

const getGoogleErrorMessage = (
  error: unknown,
  fallback: string,
) => {
  if (!isObject(error)) return fallback;

  const { data } = getGoogleErrorData(error) ?? {};

  const mainMessage = getStringValue(error, "message");
  const dataMessage = data
    ? getStringValue(data, "message")
    : null;

  const errorDescription = data
    ? getStringValue(data, "error_description")
    : null;

  const rawError = data?.error;

  let googleError: string | null = null;

  if (typeof rawError === "string") {
    googleError = rawError;
  }

  if (isObject(rawError)) {
    googleError = getStringValue(rawError, "message");
  }

  const message =
    errorDescription ??
    googleError ??
    dataMessage ??
    mainMessage ??
    fallback;

  if (message.includes("redirect_uri_mismatch")) {
    return "Nieprawidłowy redirect URI Google Calendar. Sprawdź GOOGLE_REDIRECT_URI w .env oraz Authorized redirect URIs w Google Cloud.";
  }

  if (message.includes("invalid_grant")) {
    return "Połączenie Google Calendar wygasło albo zostało cofnięte. Odłącz konto Google Calendar i połącz je ponownie.";
  }

  if (
    message.includes("Not Found") ||
    message.includes("notFound") ||
    message.includes("Resource has been deleted")
  ) {
    return "Wydarzenie nie istnieje już w Google Calendar. Usuń powiązanie i zsynchronizuj wydarzenie ponownie.";
  }

  if (
    message.includes("insufficient") ||
    message.includes("forbidden") ||
    message.includes("Forbidden")
  ) {
    return "Brak uprawnień do Google Calendar. Połącz konto ponownie i zaakceptuj wymagane uprawnienia.";
  }

  return message;
};

const isGoogleCalendarEventNotFoundError = (error: unknown) => {
  const status = getGoogleErrorStatus(error);
  const message = getGoogleErrorMessage(error, "");

  return (
    status === 404 ||
    message.includes("Wydarzenie nie istnieje już w Google Calendar") ||
    message.includes("Not Found") ||
    message.includes("notFound") ||
    message.includes("Resource has been deleted")
  );
};

const getSafeReturnPath = (returnPath?: string) => {
  if (!returnPath) return "/home";

  if (!returnPath.startsWith("/") || returnPath.startsWith("//")) {
    return "/home";
  }

  return returnPath;
};

const createStateToken = (userId: number, returnPath?: string) => {
  const secret = process.env.JWT_SECRET;

  if (!secret) {
    throw new Error("Brak JWT_SECRET");
  }

  return jwt.sign(
    {
      userId,
      type: "google-calendar-oauth",
      returnPath: getSafeReturnPath(returnPath),
    },
    secret,
    {
      expiresIn: "10m",
    },
  );
};

const verifyStateToken = (state: string) => {
  const secret = process.env.JWT_SECRET;

  if (!secret) {
    throw new Error("Brak JWT_SECRET");
  }

  const decoded = jwt.verify(state, secret);

  if (typeof decoded === "string") {
    throw new Error("Nieprawidłowy state OAuth");
  }

  const payload = decoded as JwtPayload & {
    userId?: number;
    type?: string;
    returnPath?: string;
  };

  if (
    payload.type !== "google-calendar-oauth" ||
    !payload.userId
  ) {
    throw new Error("Nieprawidłowy state OAuth");
  }

  return {
    userId: Number(payload.userId),
    returnPath: getSafeReturnPath(payload.returnPath),
  };
};

/**
 * @swagger
 * /google-calendar/auth-url:
 *   get:
 *     summary: Zwraca URL do połączenia konta Google Calendar
 *     tags:
 *       - Google Calendar
 *     security:
 *       - bearerAuth: []
 */
router.get("/auth-url", authMiddleware, async (req, res) => {
  try {
    const user = (req as any).user;
    const userId = Number(user?.userId);

    if (!userId) {
      res.status(401).json({
        message: "Brak autoryzacji",
      });
      return;
    }

    const oauthClient = getOAuthClient();
    const returnPath = typeof req.query.returnPath === "string"
      ? req.query.returnPath
      : "/home";

    const state = createStateToken(userId, returnPath);

    const url = oauthClient.generateAuthUrl({
      access_type: "offline",
      prompt: "consent",
      scope: GOOGLE_CALENDAR_SCOPES,
      state,
    });

    res.json({
      url,
    });
  } catch (error) {
    res.status(500).json({
      message: getGoogleErrorMessage(
        error,
        "Błąd generowania linku Google Calendar",
      ),
    });
  }
});

/**
 * @swagger
 * /google-calendar/callback:
 *   get:
 *     summary: Callback OAuth Google Calendar
 *     tags:
 *       - Google Calendar
 */
router.get("/callback", async (req, res) => {
  try {
    const code = String(req.query.code ?? "");
    const state = String(req.query.state ?? "");

    if (!code || !state) {
      res.status(400).send("Brak kodu OAuth lub state");
      return;
    }

    const { userId, returnPath } = verifyStateToken(state);

    const oauthClient = getOAuthClient();
    const { tokens } = await oauthClient.getToken(code);

    await prisma.googleCalendarConnection.upsert({
    where: {
        userId,
    },
    update: {
        accessToken: tokens.access_token ?? null,
        ...(tokens.refresh_token
        ? {
            refreshToken: tokens.refresh_token,
            }
        : {}),
        scope: tokens.scope ?? null,
        tokenType: tokens.token_type ?? null,
        expiryDate: tokens.expiry_date
        ? new Date(tokens.expiry_date)
        : null,
    },
    create: {
        userId,
        accessToken: tokens.access_token ?? null,
        refreshToken: tokens.refresh_token ?? null,
        scope: tokens.scope ?? null,
        tokenType: tokens.token_type ?? null,
        expiryDate: tokens.expiry_date
        ? new Date(tokens.expiry_date)
        : null,
    },
    });

    const frontendUrl = process.env.FRONTEND_URL ?? "http://localhost:54321";
    const normalizedFrontendUrl = frontendUrl.endsWith("/")
      ? frontendUrl.slice(0, -1)
      : frontendUrl;

    res.redirect(`${normalizedFrontendUrl}${returnPath}`);
    
  } catch (error) {
    res
      .status(500)
      .send(
        getGoogleErrorMessage(
          error,
          "Błąd łączenia z Google Calendar",
        ),
      );
  }
});

/**
 * @swagger
 * /google-calendar/status:
 *   get:
 *     summary: Sprawdza, czy zalogowany użytkownik ma połączony Google Calendar
 *     tags:
 *       - Google Calendar
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Status połączenia Google Calendar
 */
router.get("/status", authMiddleware, async (req, res) => {
  try {
    const user = (req as any).user;
    const userId = Number(user?.userId);

    if (!userId) {
      res.status(401).json({
        message: "Brak autoryzacji",
      });
      return;
    }

    const connection = await prisma.googleCalendarConnection.findUnique({
      where: {
        userId,
      },
    });

    res.json({
      connected: Boolean(connection?.refreshToken),
    });
  } catch {
    res.status(500).json({
      message: "Błąd sprawdzania połączenia Google Calendar",
    });
  }
});

/**
 * @swagger
 * /google-calendar/status/event/{eventId}:
 *   get:
 *     summary: Sprawdza status synchronizacji wydarzenia dla zalogowanego użytkownika
 *     description: Zwraca informację, czy użytkownik ma połączone konto Google Calendar oraz czy konkretne wydarzenie jest dodane do jego kalendarza.
 *     tags:
 *       - Google Calendar
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID wydarzenia ChronoPlan
 *     responses:
 *       200:
 *         description: Status połączenia i synchronizacji
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 connected:
 *                   type: boolean
 *                   example: true
 *                 synced:
 *                   type: boolean
 *                   example: true
 *                 syncedAt:
 *                   type: string
 *                   nullable: true
 *                   example: "2026-07-02T12:30:00.000Z"
 *       403:
 *         description: Brak dostępu do wydarzenia
 */
router.get("/status/event/:eventId", authMiddleware, async (req, res) => {
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
        message: "Nie masz dostępu do tego wydarzenia",
      });
      return;
    }

    const connection = await prisma.googleCalendarConnection.findUnique({
      where: {
        userId,
      },
    });

    const sync = await prisma.googleCalendarEventSync.findUnique({
      where: {
        eventId_userId: {
          eventId,
          userId,
        },
      },
    });

    res.json({
      connected: Boolean(connection?.refreshToken),
      synced: Boolean(sync),
      syncedAt: sync?.syncedAt ?? null,
    });
  } catch {
    res.status(500).json({
      message: "Błąd sprawdzania statusu synchronizacji Google Calendar",
    });
  }
});

/**
 * @swagger
 * /google-calendar/sync-event/{eventId}:
 *   post:
 *     summary: Synchronizuje wydarzenie z Google Calendar zalogowanego użytkownika
 *     description: Dodaje lub aktualizuje wydarzenie w prywatnym Google Calendar aktualnie zalogowanego użytkownika. Każdy użytkownik ma osobne powiązanie z wydarzeniem.
 *     tags:
 *       - Google Calendar
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID wydarzenia ChronoPlan
 *     responses:
 *       200:
 *         description: Wydarzenie zsynchronizowane z Google Calendar użytkownika
 *       400:
 *         description: Brak połączenia z Google Calendar lub nieprawidłowe ID
 *       403:
 *         description: Brak dostępu do wydarzenia
 */
router.post("/sync-event/:eventId", authMiddleware, async (req, res) => {
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
        message: "Nie masz dostępu do tego wydarzenia",
      });
      return;
    }

    const connection = await prisma.googleCalendarConnection.findUnique({
      where: {
        userId,
      },
    });

    if (!connection?.refreshToken) {
      res.status(400).json({
        message: "Najpierw połącz konto Google Calendar",
      });
      return;
    }

    const existingSync = await prisma.googleCalendarEventSync.findUnique({
      where: {
        eventId_userId: {
          eventId,
          userId,
        },
      },
    });

    const oauthClient = getOAuthClient();

    oauthClient.setCredentials({
      refresh_token: connection.refreshToken,

      ...(connection.accessToken
        ? {
            access_token: connection.accessToken,
          }
        : {}),

      ...(connection.scope
        ? {
            scope: connection.scope,
          }
        : {}),

      ...(connection.tokenType
        ? {
            token_type: connection.tokenType,
          }
        : {}),

      ...(connection.expiryDate
        ? {
            expiry_date: connection.expiryDate.getTime(),
          }
        : {}),
    });

    const calendar = google.calendar({
      version: "v3",
      auth: oauthClient,
    });

    const locationParts = [
      event.locationName,
      event.locationAddress,
    ].filter((value): value is string => Boolean(value && value.trim().length > 0));

    const googleEvent = {
      summary: event.title,
      description: event.description ?? "Wydarzenie utworzone w ChronoPlan",
      location: locationParts.join(", "),
      start: {
        dateTime: event.date.toISOString(),
      },
      end: {
        dateTime: new Date(
          event.date.getTime() + 60 * 60 * 1000,
        ).toISOString(),
      },
    };

    let googleCalendarEventId = existingSync?.googleCalendarEventId ?? null;

    if (googleCalendarEventId) {
      try {
        await calendar.events.update({
          calendarId: "primary",
          eventId: googleCalendarEventId,
          requestBody: googleEvent,
        });
      } catch (error) {
        if (!isGoogleCalendarEventNotFoundError(error)) {
          throw error;
        }

        googleCalendarEventId = null;
      }
    }

    if (!googleCalendarEventId) {
      const createdEvent = await calendar.events.insert({
        calendarId: "primary",
        requestBody: googleEvent,
      });

      const createdGoogleCalendarEventId = createdEvent.data.id;

      if (!createdGoogleCalendarEventId) {
        res.status(500).json({
          message: "Google Calendar nie zwrócił ID wydarzenia",
        });
        return;
      }

      googleCalendarEventId = createdGoogleCalendarEventId;
    }

    const sync = await prisma.googleCalendarEventSync.upsert({
      where: {
        eventId_userId: {
          eventId,
          userId,
        },
      },
      update: {
        googleCalendarEventId,
        syncedAt: new Date(),
      },
      create: {
        eventId,
        userId,
        googleCalendarEventId,
        syncedAt: new Date(),
      },
    });

    res.json({
      message: "Wydarzenie zostało zsynchronizowane z Google Calendar",
      sync,
    });
  } catch (error) {
    res.status(getGoogleErrorStatus(error)).json({
      message: getGoogleErrorMessage(
        error,
        "Błąd synchronizacji z Google Calendar",
      ),
    });
  }
});

/**
 * @swagger
 * /google-calendar/disconnect:
 *   delete:
 *     summary: Odłącza Google Calendar zalogowanego użytkownika
 *     description: Usuwa tokeny Google Calendar użytkownika, usuwa jego prywatne synchronizacje wydarzeń i próbuje cofnąć token po stronie Google.
 *     tags:
 *       - Google Calendar
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Google Calendar został odłączony
 *       401:
 *         description: Brak autoryzacji
 */
router.delete("/disconnect", authMiddleware, async (req, res) => {
  try {
    const user = (req as any).user;
    const userId = Number(user?.userId);

    if (!userId) {
      res.status(401).json({
        message: "Brak autoryzacji",
      });
      return;
    }

    const connection = await prisma.googleCalendarConnection.findUnique({
      where: {
        userId,
      },
    });

    if (connection?.refreshToken) {
      try {
        const oauthClient = getOAuthClient();

        await oauthClient.revokeToken(connection.refreshToken);
      } catch {
        // Nie blokujemy odłączenia konta w ChronoPlan,
        // jeśli Google nie pozwoli cofnąć tokenu.
      }
    }

    await prisma.$transaction([
      prisma.googleCalendarConnection.deleteMany({
        where: {
          userId,
        },
      }),

      prisma.googleCalendarEventSync.deleteMany({
        where: {
          userId,
        },
      }),
    ]);

    res.json({
      message: "Google Calendar został odłączony",
    });
  } catch {
    res.status(500).json({
      message: "Błąd odłączania Google Calendar",
    });
  }
});

/**
 * @swagger
 * /google-calendar/delete-event/{eventId}:
 *   delete:
 *     summary: Usuwa wydarzenie z Google Calendar zalogowanego użytkownika
 *     description: Usuwa prywatną kopię wydarzenia z Google Calendar aktualnie zalogowanego użytkownika. Nie usuwa wydarzenia z ChronoPlan ani z kalendarzy innych uczestników.
 *     tags:
 *       - Google Calendar
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID wydarzenia ChronoPlan
 *     responses:
 *       200:
 *         description: Wydarzenie usunięte z Google Calendar użytkownika
 *       400:
 *         description: Wydarzenie nie jest zsynchronizowane z kalendarzem użytkownika
 *       403:
 *         description: Brak dostępu do wydarzenia
 */
router.delete("/delete-event/:eventId", authMiddleware, async (req, res) => {
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
        message: "Nie masz dostępu do tego wydarzenia",
      });
      return;
    }

    const sync = await prisma.googleCalendarEventSync.findUnique({
      where: {
        eventId_userId: {
          eventId,
          userId,
        },
      },
    });

    if (!sync) {
      res.status(400).json({
        message: "To wydarzenie nie jest zsynchronizowane z Twoim Google Calendar",
      });
      return;
    }

    const connection = await prisma.googleCalendarConnection.findUnique({
      where: {
        userId,
      },
    });

    if (!connection?.refreshToken) {
      res.status(400).json({
        message: "Najpierw połącz konto Google Calendar",
      });
      return;
    }

    const oauthClient = getOAuthClient();

    oauthClient.setCredentials({
      refresh_token: connection.refreshToken,

      ...(connection.accessToken
        ? {
            access_token: connection.accessToken,
          }
        : {}),

      ...(connection.scope
        ? {
            scope: connection.scope,
          }
        : {}),

      ...(connection.tokenType
        ? {
            token_type: connection.tokenType,
          }
        : {}),

      ...(connection.expiryDate
        ? {
            expiry_date: connection.expiryDate.getTime(),
          }
        : {}),
    });

    const calendar = google.calendar({
      version: "v3",
      auth: oauthClient,
    });

    try {
      await calendar.events.delete({
        calendarId: "primary",
        eventId: sync.googleCalendarEventId,
      });
    } catch (error) {
      if (!isGoogleCalendarEventNotFoundError(error)) {
        throw error;
      }

      // Jeśli wydarzenia już nie ma w Google Calendar,
      // czyścimy tylko lokalne powiązanie użytkownika.
    }

    await prisma.googleCalendarEventSync.deleteMany({
      where: {
        eventId,
        userId,
      },
    });

    res.json({
      message: "Wydarzenie zostało usunięte z Twojego Google Calendar",
    });
  } catch (error) {
    res.status(getGoogleErrorStatus(error)).json({
      message: getGoogleErrorMessage(
        error,
        "Błąd usuwania wydarzenia z Google Calendar",
      ),
    });
  }
});

/**
 * @swagger
 * /google-calendar/clear-event-link/{eventId}:
 *   patch:
 *     summary: Czyści powiązanie wydarzenia z Google Calendar użytkownika
 *     description: Usuwa lokalne powiązanie między wydarzeniem ChronoPlan a Google Calendar aktualnie zalogowanego użytkownika. Nie usuwa wydarzenia z Google Calendar.
 *     tags:
 *       - Google Calendar
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: eventId
 *         required: true
 *         schema:
 *           type: integer
 *         description: ID wydarzenia ChronoPlan
 *     responses:
 *       200:
 *         description: Powiązanie zostało usunięte
 *       403:
 *         description: Brak dostępu do wydarzenia
 */
router.patch("/clear-event-link/:eventId", authMiddleware, async (req, res) => {
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
        message: "Nie masz dostępu do tego wydarzenia",
      });
      return;
    }

    await prisma.googleCalendarEventSync.deleteMany({
      where: {
        eventId,
        userId,
      },
    });

    res.json({
      message: "Powiązanie z Google Calendar zostało usunięte",
    });
  } catch {
    res.status(500).json({
      message: "Błąd usuwania powiązania Google Calendar",
    });
  }
});

export default router;