import { Request, Response, NextFunction } from "express";

export const errorMiddleware = (
  error: unknown,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  console.error(error);

  res.status(500).json({
    message: "Wewnętrzny błąd serwera",
  });
};