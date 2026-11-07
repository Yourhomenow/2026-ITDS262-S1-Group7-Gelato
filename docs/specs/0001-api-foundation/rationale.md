# 0001. API foundation: rationale

## Context

The API is a Bun scaffold. `server/src/app.ts` looks up a handler by exact pathname in a plain object, so `/api/menu-items/:id` is impossible today. There is no request body validation, no shared success or error shape, and no auth check. The only routes are `/api/test` and a placeholder `/api/admins` that returns `"hiiii!"`.

Every feature in the scope needs the same seam: path parameters, validated input, one response shape, and a way to require a signed in staff member. The data model already has `staff_account` and `staff_session` (D1, D2, D11), but the database access layer and sign in flow are not built. The frontend is a separate Next app on another dev port, so cookie auth needs a configured origin and credentialed CORS.

The team is small, the project is a course demo, and the build approach is Tracer Bullet. The decision should be boring, testable, and cheap to operate, not a framework the team has to learn for weeks.

## Options considered

### Option 1: Extend the custom router

Keep the `Routes` object and add a path matcher, manual body checks, a shared error helper, and a small auth middleware. No new framework.

**Pros**:
- No new dependency and full control over the request pipeline.
- The existing entry point stays untouched.

**Cons**:
- Rebuilds routing, params, middleware composition, error handling and validation that a router already provides.
- Validation and error shapes drift as each handler invents its own checks.
- The team owns the bugs in the router.

### Option 2: Hono with Zod (chosen)

Replace the flat map with Hono. Hono gives path params, middleware, a typed context and a test client on Bun. Zod gives one schema for params and bodies, and `@hono/zod-validator` maps schema failures to field errors.

**Pros**:
- Small, web standard, proven, and runs on Bun without a special adapter.
- Middleware and `onError` give one place for CORS, auth, errors and the body limit.
- `app.request()` tests the whole pipeline without a listening server.
- Zod is one schema layer for future forms and API inputs.

**Cons**:
- Three new dependencies and a framework API to learn.
- The team gives up direct control of the request loop.
- The proof route is temporary scaffolding.

### Option 3: Elysia with TypeBox

Use Bun's native framework with end to end types and built in TypeBox validation.

**Pros**:
- Deep Bun integration and strong type inference.
- Validation is part of the framework, not an add on.

**Cons**:
- Tighter Bun lock in and a larger, faster moving API surface.
- TypeBox is more verbose than Zod and less common in the team's likely experience.
- The end to end type benefit is small for a dozen routes.

### Option 4: Express with Zod

Keep a familiar Node framework and add Zod.

**Pros**:
- Mature and widely known.
- Large middleware ecosystem.

**Cons**:
- The server recently moved off Express to Bun and TypeScript.
- Express is not Bun native and adds a compatibility layer.
- More boilerplate for params, async errors and typing.

## Rationale

Hono is the smallest proven router that gives path params, middleware, a test client and a clean Bun fit. It removes the custom routing code without asking the team to adopt a Bun specific framework. Zod is the common schema layer for this stack and produces the field level errors the forms need. Elysia's end to end types are real, but the extra learning cost and tighter Bun coupling do not pay for themselves on a small course project. Express is the wrong direction after the recent port away from it. Extending the custom router is the tempting option, but it recreates the exact middleware and validation work this feature exists to standardise.

The auth seam is a port rather than a database query because the sign in flow is not built. A port lets the foundation prove the gate with a fake, keeps the production app free of a bypass, and gives the sign in feature one adapter to implement. The cookie transport is safer than a Bearer token in browser storage, and the cost is a configured CORS origin.

The error catalog is pinned rather than left to each handler because clients and tests need one vocabulary. If handlers invent messages, the same failure shows up with different text on every screen. The fixed pipeline order also matters: auth runs before validation, so a stranger cannot probe the schema of a protected route without a session. Requiring `application/json` and stripping unknown keys are the strict defaults. They cost nothing today because no client depends on the old behavior, and they keep malformed or unexpected input out of domain code.

Branch scope is deliberately not part of `requireRole`. The reporting features must let a manager compare several branches, so a role check that also pins a branch would block a real requirement. Each endpoint will state its own branch rule when it lands. The real session adapter is the next risk: it must hash the token, compare in constant time, and reject expired or revoked rows, and it must honor D2, the rule that a session exists only after an OTP challenge was consumed. That work belongs to the sign in feature, and the spec records it as a follow-up so it is not lost.
