import { z } from "zod";

export const registerUserSchema = z.object({
  name: z
    .string()
    .min(2, "Imię musi mieć minimum 2 znaki")
    .max(50, "Imię może mieć maksymalnie 50 znaków"),

  email: z
    .string()
    .email("Nieprawidłowy adres email"),

  password: z
    .string()
    .min(6, "Hasło musi mieć minimum 6 znaków"),
});