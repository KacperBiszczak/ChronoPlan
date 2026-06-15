import { z } from "zod";

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
});