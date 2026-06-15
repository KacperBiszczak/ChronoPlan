import { z } from "zod";

export const inviteParticipantSchema = z.object({
  eventId: z
    .number("ID wydarzenia musi być liczbą")
    .int("ID wydarzenia musi być liczbą całkowitą")
    .positive("ID wydarzenia musi być dodatnie"),

  email: z
    .string()
    .email("Nieprawidłowy adres email"),
});

export const updateParticipantStatusSchema = z.object({
  status: z.enum(["INVITED", "ACCEPTED", "DECLINED"], {
    message: "Status musi być jednym z: INVITED, ACCEPTED, DECLINED",
  }),
});