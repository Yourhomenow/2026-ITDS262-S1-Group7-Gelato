import { z } from "zod";
import type { Hono } from "hono";

import { requireJsonContentType } from "../http/body.js";
import { sendData } from "../http/errors.js";
import {
  requireStaff,
  type AppEnv,
  type SessionDeps,
} from "../http/session.js";
import { validateJson, validateParams } from "../http/validation.js";

const echoParams = z.object({
  id: z.string().min(1).max(64),
});

const echoBody = z.object({
  message: z.string().trim().min(1).max(200),
});

/**
 * Temporary proof route for the HTTP seam. Remove it when the first real
 * domain endpoint lands.
 */
export function registerFoundationRoute(
  app: Hono<AppEnv>,
  sessions: SessionDeps,
): void {
  app.post(
    "/api/foundation/echo/:id",
    requireStaff(sessions),
    requireJsonContentType,
    validateParams(echoParams),
    validateJson(echoBody),
    (c) => {
      const { id } = c.req.valid("param");
      const { message } = c.req.valid("json");
      const principal = c.get("principal");

      return sendData(c, {
        id,
        message,
        staffId: principal.staffId,
        role: principal.role,
        branchId: principal.branchId,
        sessionId: principal.sessionId,
      });
    },
  );
}
