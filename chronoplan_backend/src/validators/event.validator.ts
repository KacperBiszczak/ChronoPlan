import { z } from "zod";

const budgetModeSchema = z.enum(["PRIVATE", "SHARED", "MIXED"], {
  message: "Tryb budżetu musi być jednym z: PRIVATE, SHARED, MIXED",
});

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

  budgetMode: budgetModeSchema.optional(),

  locationName: z.string().max(120).optional().nullable(),
  locationAddress: z.string().max(255).optional().nullable(),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),

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

  budgetMode: budgetModeSchema.optional(),

  locationName: z.string().max(120).optional().nullable(),
  locationAddress: z.string().max(255).optional().nullable(),
  latitude: z.number().min(-90).max(90).optional().nullable(),
  longitude: z.number().min(-180).max(180).optional().nullable(),
  
});
