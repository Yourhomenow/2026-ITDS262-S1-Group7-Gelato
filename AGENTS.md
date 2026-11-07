# This is a Full-stack Gelato store and management projects

`server` is the backend (Bun and TypeScript), `clients` is the frontend (Next.js), and PostgreSQL is the database.

## Stack

- **Language / runtime**: TypeScript on Bun 1.4
- **Backend**: `Bun.serve` with Hono routes, Zod validation and one shared HTTP seam in `server/src/http/`
- **Frontend**: Next.js 16 (App Router, React 19) with Tailwind CSS 4
- **Database**: PostgreSQL 13 or newer; schema in `database/schema.sql`
- **Package manager**: Bun
- **Money and quantities**: money is `numeric(12,2)` and leaves the API as a string; quantities are `numeric(12,3)` (see D10 in `database/README.md`)

## Build approach

**Tracer Bullet**: every feature ships end to end through the database, the API and the screen, so a slice that slips never breaks the demo.

## Commands

```bash
# Install (once per package)
bun install
bun install --cwd=server
bun install --cwd=clients

# Dev servers
bun run dev:server
bun run dev:clients

# From the repo root
bun test
bun run typecheck
bun run lint
bun run format
bun run format:check

# Database (rebuilds from scratch; drops and refills data)
psql "$DATABASE_URL" -f database/schema.sql
psql "$DATABASE_URL" -f database/seed.sql
```

## Rules

- Use the domain vocabulary in `docs/agents/domain.md`. A `menu item` is never a product, a `member` is a registered account, and `stock` (ingredient lots) is not `availability` (servings a branch will sell today).
- Server modules use ES modules and `.js` import extensions, because `server/tsconfig.json` uses `NodeNext`.
- Daily boundaries use the shop timezone `Asia/Ho_Chi_Minh`, never the server clock (D15).
- Treat the schema decisions D1 to D15 in `database/README.md` as the closest thing to ADRs. Surface a conflict instead of quietly diverging.


1. **User Management & Authentication**
  - The system shall allow store staff to register their accounts.
  - The system shall allow store managers to register their accounts.
  - The system shall authenticate store staff via credentials.
  - The system shall authenticate store managers via credentials.
  - The system shall enforce multi-factor authentication (MFA) via One-Time Password (OTP) sent to the registered phone number prior to session establishment.
  - All user accounts and inventory items must be assigned unique identifiers (IDs) supporting lookup operations.
2. **Reporting & Analytics**
  - The system shall allow store managers to retrieve branch financial summary reports.
  - The system shall allow store managers to retrieve branch sales summary reports.
  - The system shall allow store managers to compare sales performance across multiple branches.
  - The system shall allow store managers and staff to view daily itemized sales reports.
3. **Order Management & Fulfillment**
  - The system shall allow store staff to create customer orders.
  - The system shall validate orders against real-time inventory stock levels to prevent over-allocation.
  - The system shall allow store staff to customize order parameters (e.g., sizing, toppings, flavor modifications).
  - The system shall allow store staff to record and update order preparation statuses (e.g., blending, resting, ready to serve).
  - The system shall allow store managers and staff to track real-time order preparation statuses.
  - The system shall support integrated payment processing methods including QR Code, credit card, and bank transfer transactions.
4. **Menu & Inventory Management**
  - The system shall allow store managers to create new menu items with metadata including recipes, ingredient requirements, storage guidelines, and unit pricing.
  - The system shall allow store managers to update existing menu item configurations, recipes, and storage guidelines.
  - The system shall allow store managers and staff to view detailed information for specific menu items.
  - The system shall allow store managers and staff to register new inventory stock with metadata (quantity, import date, supplier, shelf-life).
  - The system shall allow store managers to audit current inventory stock levels for procurement planning.
  - The system shall trigger automated low-stock alerts to store managers when inventory falls below defined safety thresholds.
  - The system shall allow store managers to issue purchase orders to suppliers for inventory replenishment.
  - The system shall allow store managers and staff to execute keyword-based searches across menu items and inventory stock.
  - The system shall allow store staff to adjust remaining menu item availability quantities.
5. **Customer Relationship Management (CRM) & Promotions**
  - The system shall allow store staff to query member/customer accounts by phone number or full name.
  - The system shall allow store staff to register new member accounts.
  - The system shall allow store staff to update member account details.
  - The system shall allow store managers to configure promotional campaigns (naming, discount rates, applicable menu items, and active duration).
  - The system shall allow store managers to update existing promotional campaigns.

## Agent skills

### Issue tracker

Issues and specs live as GitHub issues in this repo; all access goes through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles, using the default label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` at the repo root plus `docs/adr/`. See `docs/agents/domain.md`.
