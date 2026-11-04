import express from 'express'
import * as userController from "../controllers/userControllers.js"

export const userRoutes = express.Router()


userRoutes.get(`/`, userController.getUsers)
