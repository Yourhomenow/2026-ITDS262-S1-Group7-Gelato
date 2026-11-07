import type { SessionReader } from "../http/session.js";

/**
 * No session store exists yet. Sign in will replace this adapter with one
 * that hashes the cookie token and reads `staff_session`.
 */
export const pendingSessionReader: SessionReader = {
  async read(): Promise<null> {
    return null;
  },
};
