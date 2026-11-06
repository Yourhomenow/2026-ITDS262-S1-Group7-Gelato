import { app } from "./app.js";
import { config } from "./config/index.js";

try {
  console.log("DB status: not set");

  const server = Bun.serve({
    port: config.port,
    fetch: app.fetch,
  });

  console.log(`Listening on ${server.url}`);
} catch (err) {
  console.error("Failed to start server:", err);
  process.exit(1);
}
