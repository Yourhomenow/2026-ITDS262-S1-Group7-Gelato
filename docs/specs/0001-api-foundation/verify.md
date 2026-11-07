# Verify: API foundation · spec 0001 · updated 2026-11-07

_Steps derived from spec 0001 acceptance criteria. `/check verify` runs these; `/test` locks the durable ones._

## UI / manual

The proof route needs a valid session, and the real session adapter lands with sign in. Until then the production app answers 401 on protected routes, and the tests below use the fake `SessionReader` the spec calls for. These manual steps cover the public surface and the gate.

- [x] Start the server with `cd server && bun run start`, then `GET /api/health` → 200 with `{"data":{"status":"ok","timestamp":"<ISO string>"}}` and no other top level key → AC-4, AC-10
- [x] `POST /api/foundation/echo/abc` with a JSON body and no cookie → 401 `{"error":{"code":"UNAUTHENTICATED","message":"Sign in required"}}` → AC-5
- [x] `POST /api/foundation/echo/abc` with no cookie and a non JSON body → 401, not 415 (auth runs before the content type check) → AC-13
- [x] `GET /api/nope` → 404 `{"error":{"code":"NOT_FOUND","message":"Not found"}}` → AC-7
- [x] Send `OPTIONS /api/foundation/echo/abc` with `Origin: $CLIENTS_ORIGIN` and `Access-Control-Request-Method: POST` → 204 with `Access-Control-Allow-Origin` equal to the origin, credentials `true`, methods `GET,POST,PUT,PATCH,DELETE,OPTIONS`, headers `Content-Type,Authorization`, max age `600` → AC-8
- [x] Repeat the preflight with `Origin: http://evil.example` → 204 with no `Access-Control-*` headers → AC-8
- [x] Request `GET /api/health` from `$CLIENTS_ORIGIN` → `Access-Control-Allow-Origin` is that exact origin, `Access-Control-Allow-Credentials: true`, and `Vary` contains `Origin` → AC-8
- [x] Request `GET /api/health` from another origin → no `Access-Control-Allow-Origin` and no credentials header → AC-8

## Commands

- [x] `bun test` → 23 pass, 0 fail → AC-1 through AC-13
- [x] `bun run typecheck` → exits 0 for server and clients → AC-10
- [x] `bun run lint` → exits 0 for server and clients → AC-10
- [x] `bun run format:check` → exits 0 (project gate beyond the ACs) → AC-10
- [x] `bun test -t "decoded path parameter"` → id `hello%20world` arrives as `hello world`, message trimmed, full principal returned → AC-1, AC-4, AC-5
- [x] `bun test -t "missing message"` → 400 `VALIDATION_ERROR` with a detail whose field is `message`, and no handler data → AC-2
- [x] `bun test -t "malformed JSON"` → 400 with exactly `{ field: "body", message: "Invalid JSON body" }` → AC-3
- [x] `bun test -t "unknown body keys"` → the extra keys never appear in the handler output and the principal role is unchanged → AC-12
- [x] `bun test -t "unknown, expired and revoked"` → all three return 401 → AC-5
- [x] `bun test -t "requireRole MANAGER"` and `bun test -t "manager passes"` → staff 403, manager 200, branch differences ignored → AC-6
- [x] `bun test -t "wrong content type"` → signed text body returns 415 `UNSUPPORTED_MEDIA_TYPE` → AC-11
- [x] `bun test -t "over 1 MB"` → 413 `PAYLOAD_TOO_LARGE` → AC-9
- [x] `bun test -t "bad body returns 401"` → unsigned bad body returns 401 → AC-13
- [x] `bun test -t "wrong method"` → 404 → AC-7
- [x] `bun test -t "unhandled error"` → 500 `INTERNAL_ERROR` with a generic message and exactly one `console.error` call → AC-7

## Value source checks

- [x] `id` source: URL path decoded by Hono, then Zod 1 to 64 characters → `POST /api/foundation/echo/hello%20world` returns `"id": "hello world"` → AC-1
- [x] `message` source: JSON body trimmed by Zod, then 1 to 200 characters → `{"message":"  hi  "}` returns `"hi"`; spaces only is rejected with field `message` → AC-1, AC-2
- [x] `staffId`, `role`, `branchId`, `sessionId` source: the `SessionReader` port → the echo response carries the exact fake principal in tests; the real adapter is owed by the sign in feature → AC-5
- [x] `timestamp` source: `new Date().toISOString()` at request time → the health timestamp parses back to itself and is close to the clock → AC-4
- [x] error `code` and `message` source: the pinned error catalog → trigger 400, 401, 404, 413, 415 and 500 and check the exact strings → AC-4
- [x] validation `details` source: Zod issues mapped to dotted paths; malformed JSON maps to the single body entry → missing `message` names `message`, id over 64 names `id` → AC-2, AC-3
- [x] CORS values source: `CLIENTS_ORIGIN` plus the fixed settings in the spec → allowed origin gets headers, every other origin gets none → AC-8
- [x] auth cookie name source: `SESSION_COOKIE_NAME` config, default `gelato_session` → a custom name authenticates under that name and the default name is ignored → AC-5
- [x] 1 MB body guard source: the constant in the HTTP layer → a body just over 1 MB returns 413 before validation → AC-9

## Acceptance-criteria coverage

- AC-1 covered by the decoded path parameter step and the `bun test -t "decoded path parameter"` run.
- AC-2 covered by the missing message, spaces only, long id and validation details checks.
- AC-3 covered by the malformed JSON step.
- AC-4 covered by the health step, the error catalog checks and the envelope assertions in `bun test`.
- AC-5 covered by the no cookie step, the unknown/expired/revoked runs, and the cookie name source check.
- AC-6 covered by the two `requireRole` runs.
- AC-7 covered by the unknown path, wrong method and unhandled error runs.
- AC-8 covered by the preflight and origin checks.
- AC-9 covered by the over 1 MB run and the body guard source check.
- AC-10 covered by the four root gate commands.
- AC-11 covered by the wrong content type run.
- AC-12 covered by the unknown body keys run.
- AC-13 covered by the unsigned bad body and wrong content type runs.
