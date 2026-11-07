import { describe, expect, spyOn, test } from "bun:test";
import type { Hono } from "hono";

import { createApp } from "./app.js";
import type { AppEnv, SessionReader, StaffPrincipal } from "./http/session.js";
import { requireRole, requireStaff } from "./http/session.js";

const TEST_CONFIG = {
  clientsOrigin: "http://localhost:3000",
  sessionCookieName: "gelato_session",
};

const STAFF: StaffPrincipal = {
  staffId: "staff-1",
  role: "STAFF",
  branchId: "branch-1",
  sessionId: "session-staff",
};

const MANAGER: StaffPrincipal = {
  staffId: "manager-1",
  role: "MANAGER",
  branchId: "branch-2",
  sessionId: "session-manager",
};

const sessions: SessionReader = {
  async read(token) {
    if (token === "staff-token") return STAFF;
    if (token === "manager-token") return MANAGER;
    // Unknown, expired and revoked sessions all read as no principal.
    return null;
  },
};

const cookieName = TEST_CONFIG.sessionCookieName;

function buildApp(): Hono<AppEnv> {
  const app = createApp({ sessions, config: TEST_CONFIG });

  // Test only routes: one manager only route and one that throws.
  app.get(
    "/api/test/manager",
    requireStaff({ sessions, cookieName }),
    requireRole("MANAGER"),
    (c) => c.json({ data: { ok: true } }),
  );
  // Test only route: a role guard with no authentication in front of it.
  app.get("/api/test/role-guard", requireRole("MANAGER"), (c) =>
    c.json({ data: { ok: true } }),
  );
  app.get("/api/test/boom", () => {
    throw new Error("boom: internal detail that must stay in the log");
  });

  return app;
}

function cookie(token: string): Record<string, string> {
  return { Cookie: `${cookieName}=${token}` };
}

function jsonRequest(
  path: string,
  body: unknown,
  options: {
    token?: string;
    contentType?: string;
    origin?: string;
  } = {},
): Request {
  const headers: Record<string, string> = {
    "Content-Type": options.contentType ?? "application/json",
    ...(options.token ? cookie(options.token) : {}),
    ...(options.origin ? { Origin: options.origin } : {}),
  };

  return new Request(`http://localhost${path}`, {
    method: "POST",
    headers,
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

async function readJson(response: Response): Promise<Record<string, unknown>> {
  return (await response.json()) as Record<string, unknown>;
}

describe("success envelope and health", () => {
  // covers: AC-4
  test("health returns the data envelope with an ISO timestamp", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/health"),
    );
    const body = await readJson(response);

    expect(response.status).toBe(200);
    expect(Object.keys(body)).toEqual(["data"]);
    expect(body.data).toMatchObject({ status: "ok" });
    const timestamp = (body.data as { timestamp: string }).timestamp;
    expect(new Date(timestamp).toISOString()).toBe(timestamp);
  });

  // covers: AC-1, AC-4, AC-5
  test("echo returns the decoded path parameter, trimmed message and full principal", async () => {
    const response = await buildApp().fetch(
      jsonRequest(
        "/api/foundation/echo/hello%20world",
        { message: "  hi  " },
        {
          token: "staff-token",
        },
      ),
    );
    const body = await readJson(response);

    expect(response.status).toBe(200);
    expect(body).toEqual({
      data: {
        id: "hello world",
        message: "hi",
        staffId: STAFF.staffId,
        role: STAFF.role,
        branchId: STAFF.branchId,
        sessionId: STAFF.sessionId,
      },
    });
  });
  // covers: AC-4, AC-5
  test("health stays public even with a bogus session cookie", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/health", {
        headers: { Cookie: `${cookieName}=bogus-token` },
      }),
    );

    expect(response.status).toBe(200);
    expect((await readJson(response)).data).toMatchObject({ status: "ok" });
  });

  // covers: AC-1
  test("a UTF-8 path parameter arrives decoded", async () => {
    const response = await buildApp().fetch(
      jsonRequest(
        "/api/foundation/echo/%E4%B8%96%E7%95%8C",
        { message: "hi" },
        { token: "staff-token" },
      ),
    );

    expect(response.status).toBe(200);
    expect((await readJson(response)).data).toMatchObject({ id: "世界" });
  });
});

describe("validation", () => {
  // covers: AC-2
  test("a missing message returns VALIDATION_ERROR naming the field", async () => {
    const response = await buildApp().fetch(
      jsonRequest("/api/foundation/echo/abc", {}, { token: "staff-token" }),
    );
    const body = await readJson(response);

    expect(response.status).toBe(400);
    expect(body).toMatchObject({
      error: { code: "VALIDATION_ERROR", message: "Request validation failed" },
    });
    expect((body.error as { details: unknown[] }).details).toContainEqual({
      field: "message",
      message: expect.any(String),
    });
    expect(body.data).toBeUndefined();
  });

  // covers: AC-2
  test("a message of only spaces fails after trimming", async () => {
    const response = await buildApp().fetch(
      jsonRequest(
        "/api/foundation/echo/abc",
        { message: "    " },
        { token: "staff-token" },
      ),
    );

    expect(response.status).toBe(400);
    expect((await readJson(response)).error).toMatchObject({
      code: "VALIDATION_ERROR",
    });
  });

  // covers: AC-1, AC-2
  test("a path id longer than 64 characters fails on id", async () => {
    const response = await buildApp().fetch(
      jsonRequest(
        `/api/foundation/echo/${"a".repeat(65)}`,
        { message: "hi" },
        { token: "staff-token" },
      ),
    );
    const body = await readJson(response);

    expect(response.status).toBe(400);
    expect((body.error as { details: unknown[] }).details).toContainEqual({
      field: "id",
      message: expect.any(String),
    });
  });

  // covers: AC-3
  test("malformed JSON returns the pinned body detail and never runs the handler", async () => {
    const response = await buildApp().fetch(
      jsonRequest("/api/foundation/echo/abc", "{", { token: "staff-token" }),
    );
    const body = await readJson(response);

    expect(response.status).toBe(400);
    expect(body).toEqual({
      error: {
        code: "VALIDATION_ERROR",
        message: "Request validation failed",
        details: [{ field: "body", message: "Invalid JSON body" }],
      },
    });
  });

  // covers: AC-12
  test("unknown body keys are stripped before the handler runs", async () => {
    const response = await buildApp().fetch(
      jsonRequest(
        "/api/foundation/echo/abc",
        { message: "hi", extra: "nope", role: "MANAGER" },
        { token: "staff-token" },
      ),
    );
    const body = await readJson(response);

    expect(response.status).toBe(200);
    expect(JSON.stringify(body)).not.toContain("nope");
    expect(body).toMatchObject({ data: { message: "hi", role: "STAFF" } });
  });
  // covers: AC-1, AC-2
  test("an id of exactly 64 characters is accepted", async () => {
    const id = "a".repeat(64);
    const response = await buildApp().fetch(
      jsonRequest(
        `/api/foundation/echo/${id}`,
        { message: "hi" },
        { token: "staff-token" },
      ),
    );

    expect(response.status).toBe(200);
    expect((await readJson(response)).data).toMatchObject({ id });
  });

  // covers: AC-2
  test("a message of exactly 200 characters is accepted", async () => {
    const message = "m".repeat(200);
    const response = await buildApp().fetch(
      jsonRequest(
        "/api/foundation/echo/abc",
        { message },
        { token: "staff-token" },
      ),
    );

    expect(response.status).toBe(200);
    expect((await readJson(response)).data).toMatchObject({ message });
  });

  // covers: AC-2
  test("a message over 200 characters is rejected by field", async () => {
    const response = await buildApp().fetch(
      jsonRequest(
        "/api/foundation/echo/abc",
        { message: "m".repeat(201) },
        { token: "staff-token" },
      ),
    );
    const body = await readJson(response);

    expect(response.status).toBe(400);
    expect((body.error as { details: unknown[] }).details).toContainEqual({
      field: "message",
      message: expect.any(String),
    });
  });
});

describe("authentication", () => {
  // covers: AC-5
  test("no cookie returns 401", async () => {
    const response = await buildApp().fetch(
      jsonRequest("/api/foundation/echo/abc", { message: "hi" }),
    );

    expect(response.status).toBe(401);
    expect((await readJson(response)).error).toMatchObject({
      code: "UNAUTHENTICATED",
      message: "Sign in required",
    });
  });

  // covers: AC-5
  test("unknown, expired and revoked tokens all return 401", async () => {
    for (const token of ["unknown-token", "expired-token", "revoked-token"]) {
      const response = await buildApp().fetch(
        jsonRequest("/api/foundation/echo/abc", { message: "hi" }, { token }),
      );

      expect(response.status).toBe(401);
      expect((await readJson(response)).error).toMatchObject({
        code: "UNAUTHENTICATED",
      });
    }
  });

  // covers: AC-5
  test("the session cookie name comes from config", async () => {
    const app = createApp({
      sessions,
      config: { ...TEST_CONFIG, sessionCookieName: "custom_session" },
    });

    const wrongName = await app.fetch(
      jsonRequest(
        "/api/foundation/echo/abc",
        { message: "hi" },
        { token: "staff-token" },
      ),
    );
    expect(wrongName.status).toBe(401);

    const rightName = await app.fetch(
      new Request("http://localhost/api/foundation/echo/abc", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Cookie: "custom_session=staff-token",
        },
        body: JSON.stringify({ message: "hi" }),
      }),
    );
    expect(rightName.status).toBe(200);
  });
  // covers: AC-5
  test("the session token is never echoed back in the response", async () => {
    const response = await buildApp().fetch(
      jsonRequest(
        "/api/foundation/echo/abc",
        { message: "hi" },
        { token: "staff-token" },
      ),
    );

    expect(response.status).toBe(200);
    expect(JSON.stringify(await readJson(response))).not.toContain(
      "staff-token",
    );
  });
});

describe("authorization", () => {
  // covers: AC-6
  test("a staff principal gets 403 from requireRole MANAGER", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/test/manager", {
        headers: cookie("staff-token"),
      }),
    );

    expect(response.status).toBe(403);
    expect((await readJson(response)).error).toMatchObject({
      code: "FORBIDDEN",
      message: "You do not have access",
    });
  });

  // covers: AC-6
  test("a manager passes and branch is not part of the check", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/test/manager", {
        headers: cookie("manager-token"),
      }),
    );

    expect(response.status).toBe(200);
    expect(await readJson(response)).toEqual({ data: { ok: true } });
  });
  // covers: AC-6, AC-13
  test("requireRole without a principal returns 401, never 403", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/test/role-guard"),
    );

    expect(response.status).toBe(401);
    expect((await readJson(response)).error).toMatchObject({
      code: "UNAUTHENTICATED",
    });
  });
});

describe("pipeline order", () => {
  // covers: AC-13
  test("an unsigned request with a bad body returns 401, not 400", async () => {
    const response = await buildApp().fetch(
      jsonRequest("/api/foundation/echo/abc", {}),
    );

    expect(response.status).toBe(401);
  });

  // covers: AC-13
  test("an unsigned request with the wrong content type returns 401, not 415", async () => {
    const response = await buildApp().fetch(
      jsonRequest("/api/foundation/echo/abc", "plain", {
        contentType: "text/plain",
      }),
    );

    expect(response.status).toBe(401);
  });

  // covers: AC-11
  test("a signed request with the wrong content type returns 415", async () => {
    const response = await buildApp().fetch(
      jsonRequest("/api/foundation/echo/abc", "plain", {
        token: "staff-token",
        contentType: "text/plain",
      }),
    );

    expect(response.status).toBe(415);
    expect((await readJson(response)).error).toMatchObject({
      code: "UNSUPPORTED_MEDIA_TYPE",
      message: "Expected application/json",
    });
  });

  // covers: AC-9
  test("a signed request with a body over 1 MB returns 413", async () => {
    const body = JSON.stringify({ message: "x".repeat(1024 * 1024) });
    const response = await buildApp().fetch(
      jsonRequest("/api/foundation/echo/abc", body, { token: "staff-token" }),
    );

    expect(response.status).toBe(413);
    expect((await readJson(response)).error).toMatchObject({
      code: "PAYLOAD_TOO_LARGE",
      message: "Request body is too large",
    });
  });
  // covers: AC-11
  test("a request with no content type returns 415", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/foundation/echo/abc", {
        method: "POST",
        headers: cookie("staff-token"),
        body: new Uint8Array([123, 125]),
      }),
    );

    expect(response.status).toBe(415);
    expect((await readJson(response)).error).toMatchObject({
      code: "UNSUPPORTED_MEDIA_TYPE",
    });
  });

  // covers: AC-11
  test("a JSON content type with a charset parameter is accepted", async () => {
    const response = await buildApp().fetch(
      jsonRequest(
        "/api/foundation/echo/abc",
        { message: "hi" },
        {
          token: "staff-token",
          contentType: "application/json; charset=utf-8",
        },
      ),
    );

    expect(response.status).toBe(200);
  });

  // covers: AC-9, AC-13
  test("the body limit runs before auth, so an unsigned oversized body returns 413", async () => {
    const body = JSON.stringify({ message: "x".repeat(1024 * 1024) });
    const response = await buildApp().fetch(
      jsonRequest("/api/foundation/echo/abc", body),
    );

    expect(response.status).toBe(413);
    expect((await readJson(response)).error).toMatchObject({
      code: "PAYLOAD_TOO_LARGE",
    });
  });

  // covers: AC-9, AC-12
  test("a body at exactly the 1 MB limit is accepted", async () => {
    const limit = 1024 * 1024;
    const empty = JSON.stringify({ message: "hi", pad: "" });
    const body = JSON.stringify({
      message: "hi",
      pad: "x".repeat(limit - empty.length),
    });
    expect(body.length).toBe(limit);

    const response = await buildApp().fetch(
      jsonRequest("/api/foundation/echo/abc", body, { token: "staff-token" }),
    );
    const payload = await readJson(response);

    expect(response.status).toBe(200);
    expect(
      (payload.data as Record<string, unknown> | undefined)?.pad,
    ).toBeUndefined();
  });
});

describe("routing and errors", () => {
  // covers: AC-7
  test("an unknown path returns the 404 envelope", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/nope"),
    );

    expect(response.status).toBe(404);
    expect(await readJson(response)).toEqual({
      error: { code: "NOT_FOUND", message: "Not found" },
    });
  });

  // covers: AC-7
  test("a known path with the wrong method returns 404", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/foundation/echo/abc", {
        headers: cookie("staff-token"),
      }),
    );

    expect(response.status).toBe(404);
  });

  // covers: AC-7
  test("an unhandled error returns a generic 500 and logs once", async () => {
    const errorSpy = spyOn(console, "error").mockImplementation(() => {});

    try {
      const response = await buildApp().fetch(
        new Request("http://localhost/api/test/boom"),
      );
      const body = await readJson(response);

      expect(response.status).toBe(500);
      expect(body).toEqual({
        error: { code: "INTERNAL_ERROR", message: "Internal server error" },
      });
      expect(JSON.stringify(body)).not.toContain("boom");
      expect(errorSpy).toHaveBeenCalledTimes(1);
    } finally {
      errorSpy.mockRestore();
    }
  });
});

describe("CORS", () => {
  // covers: AC-8
  test("the allowed origin gets credentialed CORS headers", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/health", {
        headers: { Origin: TEST_CONFIG.clientsOrigin },
      }),
    );

    expect(response.headers.get("access-control-allow-origin")).toBe(
      TEST_CONFIG.clientsOrigin,
    );
    expect(response.headers.get("access-control-allow-credentials")).toBe(
      "true",
    );
    expect(response.headers.get("vary")).toContain("Origin");
  });

  // covers: AC-8
  test("another origin gets no CORS headers", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/health", {
        headers: { Origin: "http://evil.example" },
      }),
    );

    expect(response.headers.get("access-control-allow-origin")).toBeNull();
    expect(response.headers.get("access-control-allow-credentials")).toBeNull();
  });

  // covers: AC-8
  test("a preflight from the allowed origin returns 204 with the pinned settings", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/foundation/echo/abc", {
        method: "OPTIONS",
        headers: {
          Origin: TEST_CONFIG.clientsOrigin,
          "Access-Control-Request-Method": "POST",
          "Access-Control-Request-Headers": "Content-Type",
        },
      }),
    );

    expect(response.status).toBe(204);
    expect(response.headers.get("access-control-allow-methods")).toBe(
      "GET,POST,PUT,PATCH,DELETE,OPTIONS",
    );
    expect(response.headers.get("access-control-allow-headers")).toBe(
      "Content-Type,Authorization",
    );
    expect(response.headers.get("access-control-max-age")).toBe("600");
    expect(response.headers.get("access-control-allow-credentials")).toBe(
      "true",
    );
  });

  // covers: AC-8
  test("a preflight from another origin returns 204 with no CORS headers", async () => {
    const response = await buildApp().fetch(
      new Request("http://localhost/api/foundation/echo/abc", {
        method: "OPTIONS",
        headers: {
          Origin: "http://evil.example",
          "Access-Control-Request-Method": "POST",
        },
      }),
    );

    expect(response.status).toBe(204);
    expect(response.headers.get("access-control-allow-origin")).toBeNull();
    expect(response.headers.get("access-control-allow-methods")).toBeNull();
  });
});
