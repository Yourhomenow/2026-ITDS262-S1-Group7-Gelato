import * as userController from "../controllers/userControllers.js";
import type { Routes } from "./types.js";

export const userRoutes: Routes = {
  "/api/admins": { GET: userController.getUsers },
  "/api/admins/": { GET: userController.getUsers },
};
