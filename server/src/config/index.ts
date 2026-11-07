// Bun loads .env files automatically, so no dotenv setup is needed.

export interface DbConfig {
  host: string;
  port: number;
  name: string;
  user: string;
  password: string | undefined;
}

export interface Config {
  port: number;
  env: string;

  // Browser origin allowed by credentialed CORS.
  clientsOrigin: string;

  // Session cookie name, set by the sign in feature.
  sessionCookieName: string;

  database: DbConfig;
}

export const config: Config = {
  // Server
  port: parseInt(process.env.PORT ?? "", 10) || 3005,
  env: process.env.NODE_ENV || "development",

  // HTTP seam
  clientsOrigin: process.env.CLIENTS_ORIGIN || "http://localhost:3000",
  sessionCookieName: process.env.SESSION_COOKIE_NAME || "gelato_session",

  // Database
  database: {
    host: process.env.DB_HOST || "localhost",
    port: parseInt(process.env.DB_PORT ?? "", 10) || 5432,
    name: process.env.DB_NAME || "gelato",
    user: process.env.DB_USER || "postgres",
    password: process.env.DB_PASSWORD || undefined,
  },
};
