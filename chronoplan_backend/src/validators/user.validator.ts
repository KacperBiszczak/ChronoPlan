import { z } from "zod";

export const profileColorOptions = [
  "#2563EB",
  "#1E3A8A",
  "#16A34A",
  "#7C3AED",
  "#F97316",
  "#DC2626",
  "#64748B",
] as const;

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

export const updateProfileSchema = z.object({
  name: z
    .string()
    .min(2, "Imię musi mieć minimum 2 znaki")
    .max(50, "Imię może mieć maksymalnie 50 znaków")
    .optional(),

  email: z
    .string()
    .email("Nieprawidłowy adres email")
    .optional(),

  avatarUrl: z
    .string()
    .url("Nieprawidłowy adres URL avatara")
    .optional()
    .nullable(),

  profileColor: z
    .string()
    .refine(
      (value) =>
        profileColorOptions.includes(
          value as (typeof profileColorOptions)[number],
        ),
      "Nieprawidlowy kolor profilu",
    )
    .optional()
    .nullable(),

  phone: z
    .string()
    .max(30, "Telefon może mieć maksymalnie 30 znaków")
    .optional()
    .nullable(),

  bio: z
    .string()
    .max(300, "Opis może mieć maksymalnie 300 znaków")
    .optional()
    .nullable(),
});
