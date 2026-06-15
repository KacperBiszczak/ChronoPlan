import { prisma } from "./prisma";

export const canAccessEvent = async (eventId: number, userId: number) => {
  const event = await prisma.event.findFirst({
    where: {
      id: eventId,
      OR: [
        {
          creatorId: userId,
        },
        {
          participants: {
            some: {
              userId,
              status: "ACCEPTED",
            },
          },
        },
      ],
    },
  });

  return event;
};

export const isEventOrganizer = async (eventId: number, userId: number) => {
  const event = await prisma.event.findFirst({
    where: {
      id: eventId,
      creatorId: userId,
    },
  });

  return event;
};