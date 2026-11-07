import type { MiddlewareHandler } from "hono";

import { sendError } from "./errors.js";

export const MAX_BODY_BYTES = 1024 * 1024;

const JSON_CONTENT_TYPE = /^application\/([a-z0-9.+-]+\+)?json(;.*)?$/i;

/**
 * A JSON route accepts `application/json` bodies only.
 * Runs after authentication, before validation.
 */
export const requireJsonContentType: MiddlewareHandler = async (c, next) => {
  const contentType = c.req.header("content-type");

  if (!contentType || !JSON_CONTENT_TYPE.test(contentType)) {
    return sendError(c, "UNSUPPORTED_MEDIA_TYPE");
  }

  await next();
};
