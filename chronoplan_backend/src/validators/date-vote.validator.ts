import { z } from "zod";

export const createDateOptionSchema = z.object({
  eventId: z.number().int().positive("ID wydarzenia musi być poprawne"),
  proposedDate: z.string().datetime("Nieprawidłowy format daty"),
});

export const updateDateVoteSchema = z.object({
  status: z.enum(["YES", "MAYBE", "NO"]),
});