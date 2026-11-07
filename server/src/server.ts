import { createApp } from "./app.js";
import { config } from "./config/index.js";
import { pendingSessionReader } from "./services/sessionReader.js";

try {
  const app = createApp({
    sessions: pendingSessionReader,
    config: {
      clientsOrigin: config.clientsOrigin,
      sessionCookieName: config.sessionCookieName,
    },
  });

  const server = Bun.serve({
    port: config.port,
    fetch: app.fetch,
  });

  console.log(`Listening on ${server.url}`);
} catch (err) {
  console.error("Failed to start server:", err);
  process.exit(1);
}
