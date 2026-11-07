import { Hono } from "hono";
import { bodyLimit } from "hono/body-limit";
import { HTTPException } from "hono/http-exception";

import { MAX_BODY_BYTES } from "./http/body.js";
import { corsForOrigin } from "./http/cors.js";
import { sendError } from "./http/errors.js";
import type { AppEnv, SessionReader } from "./http/session.js";
import { registerFoundationRoute } from "./routes/foundation.js";
import { registerHealthRoute } from "./routes/health.js";

export interface AppConfig {
  clientsOrigin: string;
  sessionCookieName: string;
}

export interface AppDeps {
  sessions: SessionReader;
  config: AppConfig;
}

/**
 * Builds the whole HTTP seam: CORS, body limit, auth, validation, handler,
 * plus the one success envelope, one error envelope and one error catalog.
 */
export function createApp({ sessions, config }: AppDeps): Hono<AppEnv> {
  const app = new Hono<AppEnv>();
  const sessionDeps = {
    sessions,
    cookieName: config.sessionCookieName,
  };

  // Pipeline order: CORS, body limit, then per route auth, content type,
  // validation and the handler.
  app.use("*", corsForOrigin(config.clientsOrigin));
  app.use(
    "*",
    bodyLimit({
      maxSize: MAX_BODY_BYTES,
      onError: (c) => sendError(c, "PAYLOAD_TOO_LARGE"),
    }),
  );

  registerHealthRoute(app);
  registerFoundationRoute(app, sessionDeps);

  app.notFound((c) => sendError(c, "NOT_FOUND"));

  app.onError((err, c) => {
    // zValidator turns malformed JSON into an HTTPException with status 400.
    if (err instanceof HTTPException && err.status === 400) {
      return sendError(c, "VALIDATION_ERROR", [
        { field: "body", message: "Invalid JSON body" },
      ]);
    }

    console.error("Unhandled request error", err);
    return sendError(c, "INTERNAL_ERROR");
  });

  return app;
}
