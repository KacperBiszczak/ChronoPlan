import { z } from "zod";

export const createEventSchema = z.object({
  title: z
    .string()
    .min(1, "Tytuł wydarzenia jest wymagany")
    .max(100, "Tytuł może mieć maksymalnie 100 znaków"),

  description: z
    .string()
    .max(500, "Opis może mieć maksymalnie 500 znaków")
    .optional(),

  date: z
    .string()
    .datetime("Data musi być poprawnym formatem ISO, np. 2026-08-01T18:00:00.000Z"),
});

export const updateEventSchema = z.object({
  title: z
    .string()
    .min(1, "Tytuł wydarzenia nie może być pusty")
    .max(100, "Tytuł może mieć maksymalnie 100 znaków")
    .optional(),

  description: z
    .string()
    .max(500, "Opis może mieć maksymalnie 500 znaków")
    .optional(),

  date: z
    .string()
    .datetime("Data musi być poprawnym formatem ISO, np. 2026-08-01T18:00:00.000Z")
    .optional(),
});