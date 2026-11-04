import { config as loadEnv } from "dotenv";

loadEnv()

export const config ={
//Server
  port: parseInt(process.env.PORT, 10) || 3005,
  env: process.env.NODE_ENV || 'development',

//Database
  database:{
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT,10) || 5432,
    name: process.env.DB_NAME || 'myapp',
    user: process.env.DB_USER || 'mysql',
    password: process.env.DB_PASSWORD,
  }
}