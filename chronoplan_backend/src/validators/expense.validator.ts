import { z } from "zod";

const expenseVisibilitySchema = z.enum(["ORGANIZER_ONLY", "PARTICIPANTS"], {
  message: "Widoczność wydatku musi być jednym z: ORGANIZER_ONLY, PARTICIPANTS",
});

const expenseSettlementTypeSchema = z.enum(["NONE", "SPLIT_EQUALLY"], {
  message: "Typ rozliczenia musi być jednym z: NONE, SPLIT_EQUALLY",
});

export const createExpenseSchema = z.object({
  title: z
    .string()
    .min(1, "Nazwa wydatku jest wymagana")
    .max(100, "Nazwa wydatku może mieć maksymalnie 100 znaków"),

  amount: z
    .number("Kwota musi być liczbą")
    .positive("Kwota musi być większa od 0"),

  eventId: z
    .number("ID wydarzenia musi być liczbą")
    .int("ID wydarzenia musi być liczbą całkowitą")
    .positive("ID wydarzenia musi być dodatnie"),

  paidById: z.number().int().positive().optional().nullable(),
  category: z
    .string()
    .max(80, "Kategoria może mieć maksymalnie 80 znaków")
    .optional()
    .nullable(),
  visibility: expenseVisibilitySchema.optional(),
  settlementType: expenseSettlementTypeSchema.optional(),
});

export const updateExpenseSchema = z.object({
  title: z.string().min(1, "Nazwa wydatku jest wymagana").optional(),
  amount: z.number().positive("Kwota musi być większa od 0").optional(),
  paidById: z.number().int().positive().optional().nullable(),
  category: z
    .string()
    .max(80, "Kategoria może mieć maksymalnie 80 znaków")
    .optional()
    .nullable(),
  visibility: expenseVisibilitySchema.optional(),
  settlementType: expenseSettlementTypeSchema.optional(),
});
