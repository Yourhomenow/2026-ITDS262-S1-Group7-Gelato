import type { MiddlewareHandler } from "hono";
import { getCookie } from "hono/cookie";

import { sendError } from "./errors.js";

export type StaffRole = "STAFF" | "MANAGER";

export interface StaffPrincipal {
  staffId: string;
  role: StaffRole;
  branchId: string;
  sessionId: string;
}

/**
 * The seam between the HTTP layer and the session store.
 * The real adapter lands with the sign in feature; a missing, unknown,
 * expired or revoked session all read as `null`.
 */
export interface SessionReader {
  read(token: string): Promise<StaffPrincipal | null>;
}

export interface SessionDeps {
  sessions: SessionReader;
  cookieName: string;
}

export interface AppEnv {
  Variables: {
    principal: StaffPrincipal;
  };
}

/** Reads the session cookie and refuses the request when no principal is found. */
export function requireStaff(deps: SessionDeps): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    const token = getCookie(c, deps.cookieName);
    const principal = token ? await deps.sessions.read(token) : null;

    if (!principal) {
      return sendError(c, "UNAUTHENTICATED");
    }

    c.set("principal", principal);
    await next();
  };
}

/**
 * Checks the principal's role only. Branch scoping is decided by each
 * endpoint, because later reports compare several branches.
 */
export function requireRole(role: StaffRole): MiddlewareHandler<AppEnv> {
  return async (c, next) => {
    const principal = c.get("principal");

    if (!principal) {
      return sendError(c, "UNAUTHENTICATED");
    }

    if (principal.role !== role) {
      return sendError(c, "FORBIDDEN");
    }

    await next();
  };
}
