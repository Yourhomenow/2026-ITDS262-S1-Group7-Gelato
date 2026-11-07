import type { Hono } from "hono";

import type { AppEnv } from "../http/session.js";
import { sendData } from "../http/errors.js";

export function registerHealthRoute(app: Hono<AppEnv>): void {
  app.get("/api/health", (c) =>
    sendData(c, {
      status: "ok",
      timestamp: new Date().toISOString(),
    }),
  );
}
