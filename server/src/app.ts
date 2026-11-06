import { routes } from "./routes/index.js";
import type { Method } from "./routes/types.js";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

function withCors(res: Response): Response {
  for (const [key, value] of Object.entries(corsHeaders)) {
    res.headers.set(key, value);
  }
  return res;
}

export const app = {
  async fetch(req: Request): Promise<Response> {
    if (req.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: corsHeaders });
    }

    const { pathname } = new URL(req.url);
    const handler = routes[pathname]?.[req.method as Method];

    if (!handler) {
      return withCors(Response.json({ message: "Not found" }, { status: 404 }));
    }

    try {
      return withCors(await handler(req));
    } catch (err) {
      console.error("Unhandled request error", err);
      return withCors(
        Response.json({ message: "Internal server error" }, { status: 500 }),
      );
    }
  },
};
