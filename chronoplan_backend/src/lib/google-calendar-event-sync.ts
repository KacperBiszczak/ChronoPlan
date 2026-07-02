import { google } from "googleapis";

import { prisma } from "./prisma";

const getOAuthClient = () => {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
  const redirectUri = process.env.GOOGLE_REDIRECT_URI;

  if (!clientId || !clientSecret || !redirectUri) {
    return null;
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

const getGoogleErrorStatus = (error: unknown) => {
  if (!isObject(error)) return null;

  const code = error.code;

  if (typeof code === "number") {
    return code;
  }

  const response = error.response;

  if (isObject(response) && typeof response.status === "number") {
    return response.status;
  }

  return null;
};

const isGoogleCalendarEventNotFoundError = (error: unknown) => {
  const status = getGoogleErrorStatus(error);

  if (status === 404) {
    return true;
  }

  if (!isObject(error)) {
    return false;
  }

  const message =
    typeof error.message === "string"
      ? error.message
      : "";

  return (
    message.includes("Not Found") ||
    message.includes("notFound") ||
    message.includes("Resource has been deleted")
  );
};

export const updateExistingGoogleCalendarEventForEvent = async (
  eventId: number,
) => {
  const event = await prisma.event.findUnique({
    where: {
      id: eventId,
    },
    include: {
      googleCalendarSyncs: {
        include: {
          user: {
            include: {
              googleCalendarConnection: true,
            },
          },
        },
      },
    },
  });

  if (!event || event.googleCalendarSyncs.length === 0) {
    return 0;
  }

  const oauthClient = getOAuthClient();

  if (!oauthClient) {
    return 0;
  }

  const locationParts = [
    event.locationName,
    event.locationAddress,
  ].filter((value): value is string => Boolean(value && value.trim().length > 0));

  const googleEvent = {
    summary: event.title,
    description: event.description ?? 'Wydarzenie utworzone w ChronoPlan',
    location: locationParts.join(', '),
    start: {
      dateTime: event.date.toISOString(),
    },
    end: {
      dateTime: new Date(
        event.date.getTime() + 60 * 60 * 1000,
      ).toISOString(),
    },
  };

  let updatedCount = 0;

  for (const sync of event.googleCalendarSyncs) {
    const connection = sync.user.googleCalendarConnection;

    if (!connection?.refreshToken) {
      continue;
    }

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
      version: 'v3',
      auth: oauthClient,
    });

    let googleCalendarEventId = sync.googleCalendarEventId;

    try {
      await calendar.events.update({
        calendarId: 'primary',
        eventId: googleCalendarEventId,
        requestBody: googleEvent,
      });
    } catch (error) {
      if (!isGoogleCalendarEventNotFoundError(error)) {
        continue;
      }

      const createdEvent = await calendar.events.insert({
        calendarId: 'primary',
        requestBody: googleEvent,
      });

      const createdGoogleCalendarEventId = createdEvent.data.id;

      if (!createdGoogleCalendarEventId) {
        continue;
      }

      googleCalendarEventId = createdGoogleCalendarEventId;
    }

    await prisma.googleCalendarEventSync.update({
      where: {
        id: sync.id,
      },
      data: {
        googleCalendarEventId,
        syncedAt: new Date(),
      },
    });

    updatedCount += 1;
  }

  return updatedCount;
};

export const deleteExistingGoogleCalendarEventForEvent = async (
  eventId: number,
) => {
  const event = await prisma.event.findUnique({
    where: {
      id: eventId,
    },
    include: {
      googleCalendarSyncs: {
        include: {
          user: {
            include: {
              googleCalendarConnection: true,
            },
          },
        },
      },
    },
  });

  if (!event || event.googleCalendarSyncs.length === 0) {
    return 0;
  }

  const oauthClient = getOAuthClient();

  if (!oauthClient) {
    return 0;
  }

  let deletedCount = 0;

  for (const sync of event.googleCalendarSyncs) {
    const connection = sync.user.googleCalendarConnection;

    if (!connection?.refreshToken) {
      continue;
    }

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

      deletedCount += 1;
    } catch (error) {
      if (isGoogleCalendarEventNotFoundError(error)) {
        deletedCount += 1;
        continue;
      }

      // Nie blokujemy usuwania wydarzenia w ChronoPlan,
      // jeśli dla jednego użytkownika Google Calendar zwróci błąd.
      continue;
    }
  }

  return deletedCount;
};

export const deleteGoogleCalendarEventSyncForUser = async (
  eventId: number,
  userId: number,
) => {
  const sync = await prisma.googleCalendarEventSync.findUnique({
    where: {
      eventId_userId: {
        eventId,
        userId,
      },
    },
    include: {
      user: {
        include: {
          googleCalendarConnection: true,
        },
      },
    },
  });

  if (!sync) {
    return false;
  }

  const connection = sync.user.googleCalendarConnection;

  if (!connection?.refreshToken) {
    await prisma.googleCalendarEventSync.deleteMany({
      where: {
        eventId,
        userId,
      },
    });

    return false;
  }

  const oauthClient = getOAuthClient();

  if (!oauthClient) {
    return false;
  }

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
      // Nie blokujemy czyszczenia lokalnego powiązania.
    }
  }

  await prisma.googleCalendarEventSync.deleteMany({
    where: {
      eventId,
      userId,
    },
  });

  return true;
};