import { z } from "zod";

export const createTaskSchema = z.object({
  title: z
    .string()
    .min(1, "Tytuł zadania jest wymagany")
    .max(100, "Tytuł może mieć maksymalnie 100 znaków"),

  description: z
    .string()
    .max(500, "Opis może mieć maksymalnie 500 znaków")
    .optional(),

  eventId: z
    .number("ID wydarzenia musi być liczbą")
    .int("ID wydarzenia musi być liczbą całkowitą")
    .positive("ID wydarzenia musi być dodatnie"),
});

export const updateTaskStatusSchema = z.object({
  status: z.enum(["TODO", "IN_PROGRESS", "DONE"], {
    message: "Status musi być jednym z: TODO, IN_PROGRESS, DONE",
  }),
});