import { zValidator } from "@hono/zod-validator";
import type { z } from "zod";

import { sendError, type ErrorDetail } from "./errors.js";

interface ZodIssueLike {
  path: PropertyKey[];
  message: string;
}

export function toErrorDetails(error: {
  issues: readonly ZodIssueLike[];
}): ErrorDetail[] {
  return error.issues.map((issue) => ({
    field: issue.path.join(".") || "body",
    message: issue.message,
  }));
}

/** A path parameter schema whose failures use the shared error envelope. */
export function validateParams<T extends z.ZodType>(schema: T) {
  return zValidator("param", schema, (result, c) => {
    if (!result.success) {
      return sendError(c, "VALIDATION_ERROR", toErrorDetails(result.error));
    }
  });
}

/** A JSON body schema whose failures use the shared error envelope. */
export function validateJson<T extends z.ZodType>(schema: T) {
  return zValidator("json", schema, (result, c) => {
    if (!result.success) {
      return sendError(c, "VALIDATION_ERROR", toErrorDetails(result.error));
    }
  });
}
