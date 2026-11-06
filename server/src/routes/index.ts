import type { Routes } from "./types.js";
import { userRoutes } from "./userRoutes.js";

export const routes: Routes = {
  "/api/test": {
    GET: () =>
      Response.json({ status: "ok", timestamp: new Date().toISOString() }),
  },
  ...userRoutes,
};
