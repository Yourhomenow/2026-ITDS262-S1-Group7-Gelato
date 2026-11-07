# 0001. Adopt Hono, Zod and one HTTP seam for the API

**Date**: 2026-11-06
**Status**: Accepted

## Summary

Every future endpoint needs the same four things: path parameters, body validation, one success and error shape, and one sign in check. Today the API is a flat path lookup with none of these. This spec adopts Hono with Zod, a small shared HTTP layer, and a session port that the sign in feature will fill in. It delivers one thin proof route through the whole seam, then later features reuse it.

## Requirements

**User stories**:
- As a staff member, I want bad input rejected with a clear field error so I can correct it.
- As a staff member, I want protected endpoints to reject me when I am not signed in so my data stays safe.
- As a developer, I want one routing, validation, error and auth seam so every new endpoint behaves the same.
- As a manager, I want role checks so manager only endpoints stay out of staff reach.

**Acceptance criteria**:
- **AC-1**: A route with a path parameter receives the decoded parameter value, not a literal path match.
- **AC-2**: A request body that fails its Zod schema returns 400 with `VALIDATION_ERROR` and a `details` array naming each failing field; the handler does not run.
- **AC-3**: Malformed JSON returns 400 with `VALIDATION_ERROR` and the details entry `{ field: "body", message: "Invalid JSON body" }`; the handler does not run.
- **AC-4**: A successful request returns 200 with `{ "data": ... }`; every error returns `{ "error": { "code", "message", "details"? } }` using the messages in the error catalog.
- **AC-5**: A protected route with no session, an unknown token, an expired session, or a revoked session returns 401 `UNAUTHENTICATED`; with a valid session the handler receives `{ staffId, role, branchId, sessionId }`.
- **AC-6**: `requireRole("MANAGER")` returns 403 `FORBIDDEN` for a staff principal and permits a manager. The helper checks role only; branch scoping belongs to each endpoint.
- **AC-7**: An unknown path or a known path with the wrong method returns 404 `NOT_FOUND`; an unhandled error returns 500 `INTERNAL_ERROR` with a generic message and one server log.
- **AC-8**: CORS allows credentials only from `CLIENTS_ORIGIN`; a preflight from that origin returns 204 with the methods and headers named in this spec, and another origin gets no CORS headers.
- **AC-9**: A request body over 1 MB returns 413 `PAYLOAD_TOO_LARGE`.
- **AC-10**: `bun test`, `bun run typecheck` and `bun run lint` pass from the repo root, and `GET /api/health` plus `POST /api/foundation/echo/:id` prove the seam.
- **AC-11**: A JSON endpoint rejects a body whose `Content-Type` is not `application/json` with 415 `UNSUPPORTED_MEDIA_TYPE`.
- **AC-12**: Unknown body keys are dropped before the handler runs and never reach domain code.
- **AC-13**: A request runs through CORS, then the body limit, then auth, then validation, then the handler; an unsigned request with a bad body returns 401, not 400.

## Decision

**Chosen option**: Option 2: Hono with Zod

Adopt Hono as the router, Zod as the one schema layer for path parameters and JSON bodies, and a small shared HTTP layer for envelopes, error codes and a pinned error catalog. Authentication is a `SessionReader` port with a test fake; the real adapter lands with sign in. The app is built by a factory, `createApp({ sessions, config })`, so tests inject a fake reader and a config object, and the production entry point reads the environment once at startup.

**Implementation skills**: none

## Feature design

**Data model sketch**:
No schema change. The session port returns a `StaffPrincipal`:
- `staffId`: uuid string, from `staff_account.id`
- `role`: `STAFF` or `MANAGER`, from `staff_account.role`
- `branchId`: uuid string, from `staff_account.branch_id`
- `sessionId`: uuid string, from `staff_session.id`

The real adapter will hash the cookie token and look up `staff_session.token_hash`; that adapter is built in the sign in feature. The proof route and tests use a fake reader.

**State transitions**: none.

**API surface**:
| Endpoint | Method | Key inputs | Key outputs | Auth | Key errors |
|---|---|---|---|---|---|
| `/api/health` | GET | none | `{ data: { status: "ok", timestamp } }` | public | 500 |
| `/api/foundation/echo/:id` | POST | `id` path string, 1 to 64 characters; body `{ message: string }` (trimmed, 1 to 200 characters) | `{ data: { id, message, staffId, role, branchId, sessionId } }` | session cookie | 400, 401, 413, 415, 500 |
| any unknown path | any | none | error envelope | public | 404 |
| any unhandled error | any | none | error envelope | any | 500 |

**Error catalog**:
The code strings and messages below are constants in the shared error helper. Tests assert both.

| Code | HTTP | Message |
|---|---|---|
| `VALIDATION_ERROR` | 400 | Request validation failed |
| `UNAUTHENTICATED` | 401 | Sign in required |
| `FORBIDDEN` | 403 | You do not have access |
| `NOT_FOUND` | 404 | Not found |
| `PAYLOAD_TOO_LARGE` | 413 | Request body is too large |
| `UNSUPPORTED_MEDIA_TYPE` | 415 | Expected application/json |
| `INTERNAL_ERROR` | 500 | Internal server error |

A schema failure puts each Zod issue in `details` as `{ field, message }`, where `field` is the dotted path (for example `message`). Malformed JSON uses the single entry `{ field: "body", message: "Invalid JSON body" }`. The 500 message never changes with the environment, and the real error and stack go to the server log only.

**Request pipeline order**:
1. CORS, including the preflight short circuit.
2. Body limit, 1 MB.
3. Authentication, only on protected routes.
4. Content type check and Zod validation.
5. The handler.

An unsigned request with a bad body therefore returns 401. A signed request with a bad body returns 400. A signed request with a body over 1 MB returns 413 before validation.

**CORS settings**:
- Allowed origin: `CLIENTS_ORIGIN` only, with `Access-Control-Allow-Credentials: true`.
- Allowed methods: `GET,POST,PUT,PATCH,DELETE,OPTIONS`.
- Allowed headers: `Content-Type, Authorization`.
- Preflight max age: 600 seconds. Preflight returns 204.
- A request from any other origin gets no CORS headers at all.

**Body handling**:
- A JSON route requires `Content-Type: application/json`; anything else returns 415, checked after auth.
- Unknown body keys are stripped by the Zod schema and never reach the handler.
- `message` is trimmed before the length check, so a body of spaces fails validation.

**Current shapes replaced**:
The bare `{ message }` error from `server/src/app.ts` and the bare health payload from `server/src/routes/index.ts` are both replaced by the envelopes above. There is no compatibility layer and no caller depends on the old shapes.

**Value sourcing**:
| Action | Value produced / displayed | Source |
|---|---|---|
| echo route | `id` | URL path parameter, decoded by Hono and validated by Zod as a non empty string of at most 64 characters |
| echo route | `message` | JSON request body, trimmed and validated by Zod to 1 to 200 characters |
| echo route | `staffId`, `role`, `branchId`, `sessionId` | `SessionReader` port; real adapter reads `staff_account` and `staff_session` in the sign in feature |
| health route | `timestamp` | `new Date().toISOString()` at request time |
| every error | `code`, `message` | the fixed error catalog above, exposed as constants from the shared HTTP layer |
| validation error | `details` | Zod issues mapped to `{ field, message }`; malformed JSON maps to `{ field: "body", message: "Invalid JSON body" }` |
| every response | CORS origin, methods, headers, max age | `CLIENTS_ORIGIN` plus the fixed settings in the CORS section |
| auth read | cookie name | `SESSION_COOKIE_NAME`, default `gelato_session` |
| app construction | `sessions`, `config` | `createApp({ sessions, config })`; `server.ts` reads the environment once at startup and passes the values in |
| body guard | 1 MB limit | constant in the HTTP layer |

**Key invariants**:
- Every response is JSON in one of the two envelopes. No raw payloads, no bare `{ message }`, and no compatibility layer for the old shapes.
- The pipeline order is fixed: CORS, body limit, auth, validation, handler. A request never reaches an earlier stage after a later one rejects it.
- Validation runs before the handler; a failed schema never reaches domain code.
- Body keys not named in the schema are stripped, so a new client field never reaches domain code by accident.
- Authentication runs before authorization; a role check never runs without a principal.
- An expired or revoked session is treated exactly like a missing or unknown one: 401 `UNAUTHENTICATED`.
- `requireRole` checks role only and never branch. Branch scoping is decided by each endpoint, because later reports may compare branches.
- The production app never accepts a dev bypass header. The fake `SessionReader` exists only in tests.
- Error responses never include a stack or internal message.
- CORS never uses `*` when credentials are allowed.
- The proof route is temporary and must be removed when the first real domain endpoint lands.

**Security model**:
- Public: `GET /api/health` and the 404 and 500 envelopes.
- Signed in staff: `POST /api/foundation/echo/:id`.
- Manager only: no production route in this slice; `requireRole("MANAGER")` is tested with a small test app.
- Session validity: the `SessionReader` answers with a principal or nothing. Missing, unknown, expired and revoked all produce nothing, and the gate answers 401.
- Session transport: httpOnly cookie. The foundation reads it; the sign in feature sets it with `HttpOnly`, `SameSite=Lax`, `Path=/`, and `Secure` in production.
- CORS allows credentials only from `CLIENTS_ORIGIN`. A request from any other origin gets no CORS headers, so a browser cannot read its response.
- Branch scope: `requireRole` does not enforce branch, and no route in this slice is branch scoped. Each later endpoint states its own branch rule. This is deliberate because the sales comparison feature lets a manager read several branches.
- No PII is stored or logged in this slice. Auth and payments are the later compliance sensitive areas.

**Configuration required**:
- `CLIENTS_ORIGIN`: allowed browser origin for credentialed CORS, default `http://localhost:3000`.
- `SESSION_COOKIE_NAME`: session cookie name, default `gelato_session`.

The environment is read once in `server.ts` at startup, given the defaults above, and passed to `createApp({ sessions, config })`. The app factory reads no environment variables itself, so tests set config directly.

**Critical test scenarios**:
- Happy path: `GET /api/health` returns 200 data envelope; `POST /api/foundation/echo/:id` with a valid fake session and body returns the id, message, and full principal. Verifies AC-1, AC-4, AC-5.
- Validation failure: missing or empty `message`, a message of only spaces, a path id longer than 64 characters, and malformed JSON each return 400 with field details and never call the handler. Verifies AC-2, AC-3.
- Body shape: unknown body keys are dropped and do not appear in the handler input or the response. Verifies AC-12.
- Auth failure: no cookie, an unknown token, an expired session, and a revoked session all return 401. Verifies AC-5.
- Role failure: a staff principal gets 403 from `requireRole("MANAGER")`; a manager passes. The helper ignores branch. Verifies AC-6.
- Pipeline order: an unsigned request with a bad body returns 401, and a signed request with a body over 1 MB returns 413. Verifies AC-13.
- Content type: a signed request with a text body returns 415. Verifies AC-11.
- Routing and server failure: unknown path and wrong method return 404; a throwing route returns 500 generic and logs once. Verifies AC-7.
- CORS: allowed origin gets the allow header, credentials, the method list, the header list, and max age 600; another origin gets no CORS headers; preflight is 204. Verifies AC-8.
- Body limit: a body just over 1 MB returns 413. Verifies AC-9.
- Gates: the root test, typecheck and lint commands pass. Verifies AC-10.

## Build plan

Tracer Bullet: the proof route is the thin thread. Build the seam around it first, then let later features add routes without changing the seam.

1. [x] Remove the `/api/admins` placeholder route, controller and service; keep `/api/test` as the seed for `/api/health`. Prefactor for AC-4 and AC-7.
2. [x] Install `hono`, `zod` and `@hono/zod-validator`; add `CLIENTS_ORIGIN` and `SESSION_COOKIE_NAME` to `server/.env.example`. Satisfies AC-1, AC-8, AC-9.
3. [x] Build the shared HTTP layer: success and error envelopes, the pinned error catalog, Zod error mapping, unknown key stripping, the content type check, and the 1 MB body guard. Satisfies AC-2, AC-3, AC-4, AC-7, AC-9, AC-11, AC-12.
4. [x] Build the session port and middleware: `SessionReader` (with expired and revoked treated as no session), cookie reading, `requireStaff`, `requireRole`. Satisfies AC-5, AC-6.
5. [x] Build `createApp({ sessions, config })` with credentialed CORS, `notFound`, `onError`, `/api/health` and `POST /api/foundation/echo/:id`, in the fixed pipeline order; start it from `server.ts` with the environment read once. Satisfies AC-1 through AC-13.
6. [x] Replace the old tests with the critical scenarios above, including the fake session reader and a throwing test route. Satisfies AC-1 through AC-13.
7. [x] Run `bun test`, `bun run typecheck` and `bun run lint`, then update the scope and the backend line in `AGENTS.md`. Satisfies AC-10.

## Consequences

**Positive**:
- One place for params, validation, envelopes, error codes and auth.
- Zod schemas give field level errors for forms.
- The app factory makes every route testable without a running server.
- Cookie transport keeps the session token out of browser JavaScript.
- Future features add a route and a schema, not a new error style.

**Negative / tradeoffs**:
- Hono, Zod and the Zod validator are three new dependencies to learn and maintain.
- Cookie auth requires a configured client origin and credentialed CORS, which is stricter than the current wildcard.
- Requiring `application/json` is stricter than the current server, which reads no body at all.
- Dropping unknown body keys is silent. A typo in a field name is ignored rather than rejected.
- The proof route is throwaway code.
- The session port is a fake until sign in lands, so the end to end auth path is not real yet.
- 404 for a wrong method is less precise than 405.

**Neutral**:
- The existing `/api/test` and `/api/admins` routes change, and the old bare shapes are replaced with no compatibility layer; no external client depends on them.
- `AGENTS.md` needs its backend line updated after the build.
- No database work and no migration.

## Follow-up

- [ ] Remove the `/api/foundation/echo/:id` fixture when the first real domain endpoint lands.
- [ ] Implement the real `SessionReader` against `staff_session` in the sign in ticket: hash the cookie token, compare in constant time, reject a row whose `expires_at` has passed or whose `revoked_at` is set, and respect the D2 rule that a session exists only after an OTP challenge was consumed.
- [ ] Decide branch scoping per endpoint when the first branch sensitive feature lands. `requireRole` stays role only so a manager can compare several branches.
- [ ] Set the session cookie in the sign in ticket with the flags named in this spec.
- [ ] Update the backend line in `AGENTS.md` from the flat route table to Hono after the build.
- [ ] Add request ids and structured logging when the first real feature lands.
- [ ] Revisit 405 for wrong methods if a client needs the distinction.
- [ ] Consider a dedicated `server/AGENTS.md` once the API grows beyond a handful of routes.

## Rationale

Reasoning and options: see [rationale.md](./rationale.md).
