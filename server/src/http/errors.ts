import type { Context } from "hono";
import type { ContentfulStatusCode } from "hono/utils/http-status";

export interface ErrorDetail {
  field: string;
  message: string;
}

export const ERROR_CATALOG = {
  VALIDATION_ERROR: {
    status: 400,
    message: "Request validation failed",
  },
  UNAUTHENTICATED: {
    status: 401,
    message: "Sign in required",
  },
  FORBIDDEN: {
    status: 403,
    message: "You do not have access",
  },
  NOT_FOUND: {
    status: 404,
    message: "Not found",
  },
  PAYLOAD_TOO_LARGE: {
    status: 413,
    message: "Request body is too large",
  },
  UNSUPPORTED_MEDIA_TYPE: {
    status: 415,
    message: "Expected application/json",
  },
  INTERNAL_ERROR: {
    status: 500,
    message: "Internal server error",
  },
} as const satisfies Record<
  string,
  { status: ContentfulStatusCode; message: string }
>;

export type ErrorCode = keyof typeof ERROR_CATALOG;

export interface ApiErrorBody {
  error: {
    code: ErrorCode;
    message: string;
    details?: ErrorDetail[];
  };
}

/** Every error leaves the API in this one envelope. */
export function sendError(
  c: Context,
  code: ErrorCode,
  details?: ErrorDetail[],
): Response {
  const { status, message } = ERROR_CATALOG[code];
  const body: ApiErrorBody = {
    error: {
      code,
      message,
      ...(details && details.length > 0 ? { details } : {}),
    },
  };

  return c.json(body, status);
}

/** Every success leaves the API in this one envelope. */
export function sendData<T>(
  c: Context,
  data: T,
  status: ContentfulStatusCode = 200,
): Response {
  return c.json({ data }, status);
}
