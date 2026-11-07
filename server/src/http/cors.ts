import type { MiddlewareHandler } from "hono";

const ALLOW_METHODS = "GET,POST,PUT,PATCH,DELETE,OPTIONS";
const ALLOW_HEADERS = "Content-Type,Authorization";
const PREFLIGHT_MAX_AGE = "600";

/**
 * Credentialed CORS for one browser origin. A request from any other
 * origin gets no CORS headers at all, and a preflight is answered with
 * 204 before the body limit and auth stages run.
 */
export function corsForOrigin(clientsOrigin: string): MiddlewareHandler {
  return async (c, next) => {
    const origin = c.req.header("origin");
    const allowed = origin === clientsOrigin;

    if (allowed) {
      c.header("Access-Control-Allow-Origin", origin);
      c.header("Access-Control-Allow-Credentials", "true");
      c.header("Vary", "Origin", { append: true });
    }

    if (c.req.method === "OPTIONS") {
      if (allowed) {
        c.header("Access-Control-Allow-Methods", ALLOW_METHODS);
        c.header("Access-Control-Allow-Headers", ALLOW_HEADERS);
        c.header("Access-Control-Max-Age", PREFLIGHT_MAX_AGE);
      }

      return c.body(null, 204);
    }

    await next();
  };
}
