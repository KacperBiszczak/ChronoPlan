import { nullable, z } from "zod";

export const createTaskSchema = z.object({
  title: z
    .string()
    .min(1, "Tytuł zadania jest wymagany")
    .max(100, "Tytuł może mieć maksymalnie 100 znaków"),

  description: z
    .string()
    .max(500, "Opis może mieć maksymalnie 500 znaków")
    .optional()
    .nullable(),

  eventId: z
    .number("ID wydarzenia musi być liczbą")
    .int("ID wydarzenia musi być liczbą całkowitą")
    .positive("ID wydarzenia musi być dodatnie"),
    
  assigneeId: z
    .number("ID przypisania musi być liczbą")
    .int("ID przypisania musi być liczbą całkowitą")
    .positive("ID przypisania musi być dodatnie")
    .optional()
    .nullable(),
});

export const updateTaskSchema = z.object({
  title: z.string().min(1, "Tytuł zadania jest wymagany").optional(),
  description: z.string().max(500).optional().nullable(),
  assigneeId: z.number().int().positive().optional().nullable(),
});

export const updateTaskStatusSchema = z.object({
  status: z.enum(["TODO", "IN_PROGRESS", "DONE"], {
    message: "Status musi być jednym z: TODO, IN_PROGRESS, DONE",
  }),
});