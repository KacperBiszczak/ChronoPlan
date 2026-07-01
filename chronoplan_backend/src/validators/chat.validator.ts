import { z } from "zod";

export const createChatMessageSchema = z.object({
  eventId: z.number().int().positive("ID wydarzenia musi być poprawne"),
  content: z
    .string()
    .min(1, "Treść wiadomości jest wymagana")
    .max(1000, "Wiadomość może mieć maksymalnie 1000 znaków"),
});