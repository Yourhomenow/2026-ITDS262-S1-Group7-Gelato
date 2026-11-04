import express from 'express'
import { userRoutes } from './userRoutes.js';

export const router = express.Router();

router.get('/test', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
})

router.use('/admins',userRoutes);