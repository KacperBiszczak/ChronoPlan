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

export const updateExistingGoogleCalendarEventForEvent = async (
  eventId: number,
) => {
  const event = await prisma.event.findUnique({
    where: {
      id: eventId,
    },
    include: {
      creator: {
        include: {
          googleCalendarConnection: true,
        },
      },
    },
  });

  if (!event?.googleCalendarEventId) {
    return false;
  }

  const connection = event.creator.googleCalendarConnection;

  if (!connection?.refreshToken) {
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

  const locationParts = [
    event.locationName,
    event.locationAddress,
  ].filter((value): value is string => Boolean(value && value.trim().length > 0));

  await calendar.events.update({
    calendarId: "primary",
    eventId: event.googleCalendarEventId,
    requestBody: {
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
    },
  });

  await prisma.event.update({
    where: {
      id: event.id,
    },
    data: {
      googleCalendarSyncedAt: new Date(),
    },
  });

  return true;
};