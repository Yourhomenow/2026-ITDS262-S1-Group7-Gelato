# Database

PostgreSQL schema for the gelato store. Two files, applied in order:

```bash
psql "$DATABASE_URL" -f database/schema.sql   # structures (drops + recreates)
psql "$DATABASE_URL" -f database/seed.sql     # demo data (truncates + refills)
```

Requires PostgreSQL 13+ (uses `gen_random_uuid()`, no extension needed;
`pg_trgm` for keyword search is created by the schema).

> `schema.sql` drops every table it owns. It is a "rebuild from scratch" script for
> development, not a migration. Once real data exists, changes go through numbered
> migrations instead.

The previous contents of these files were a MySQL bookshop template
(`ITDS242_BookShop`) and described nothing in this domain.

## Why it looks like this

These are the decisions behind the shape. They were made explicitly; changing one
is a deliberate act, not a refactor.

| # | Decision | Why |
|---|---|---|
| D1 | One `staff_account` table with a `role` enum | Staff and managers share the password + OTP + session flow. Two tables would duplicate all of it and still need a union for login. |
| D2 | A `staff_session` row can only exist after an `otp_challenge` is consumed | This is requirement 1.5 as a schema invariant: checking the password alone can never mint a session. |
| D3 | Stock is `inventory_lot` rows, not a quantity column | Each delivery has its own import date, supplier, cost and shelf-life (requirement 4.4). On-hand is `SUM(qty_remaining)`. |
| D4 | Consumption is first-expired-first-out, per branch, per ingredient | The only allocation rule that doesn't silently waste food. |
| D5 | `branch_menu_item.available_qty` is separate from ingredient stock | "Have we sold out of pistachio?" and "do we have milk?" are different questions (requirement 4.9). The first is a manual serving count. |
| D6 | `recipe_requirement` has either a `menu_item_id` or a `modifier_id`, never both | Toppings consume stock, so both items and modifiers need recipes. One table keeps order consumption to a single query; the CHECK plus two foreign keys keep it referentially honest. |
| D7 | `modifier.servings_multiplier` drives sizes | A large cup is 3 servings of the base recipe and takes 3 off availability, without duplicating a recipe per size. |
| D8 | Price, discount and totals are stored, not recomputed | Menus and campaigns change; a sale must not. `order_item_modifier.price_delta` is a snapshot for the same reason. |
| D9 | Stock is deducted when the order is placed, and restored from the ledger on cancel | Requirement 3.2 asks for real-time validation. Restoring reads the `SALE_CONSUMPTION` movements rather than re-deriving from the recipe, so a later recipe edit can't corrupt a reversal. |
| D10 | Money is `numeric(12,2)`, never float; quantities are `numeric(12,3)` | Exact arithmetic in SQL, and legible in a report. The API must serialise money as a string so JSON doesn't lose precision. |
| D11 | `uuid` primary keys | Requirement 1.7 only asks for unique, lookup-able IDs. UUIDs also stop `/orders/17` from leaking how many orders exist. |
| D12 | Nothing is hard-deleted; `is_active` / `status` instead | Reports, ledgers and foreign keys all point at history. |
| D13 | Prep status lives on `order_item`, not `customer_order` | Each cup is blended and rested separately (requirement 3.4). |
| D14 | COGS uses `ingredient.unit_cost` | Simple, defensible, and matches how a small shop actually prices. Lot-weighted average is more accurate and deliberately not used. |
| D15 | One shop timezone (`Asia/Ho_Chi_Minh`), stored as `timestamptz` | "Daily" report boundaries are computed with `AT TIME ZONE`, never from the server clock, or reports shift depending on where the API runs. |

## Invariants the database enforces

These all fail loudly in SQL, which is verified in `database/seed.sql`'s self-check
and by the checks below:

- an order can have at most one `SUCCEEDED` payment, but any number of failed attempts
  (`payment_one_success_uniq`);
- `customer_order.total = subtotal - discount`;
- `order_item.line_total = unit_price * quantity`;
- `inventory_lot.qty_remaining` is between 0 and `qty_received`;
- a purchased line cannot be received beyond what was ordered;
- a promotion's rate is 1–100% and it cannot end before it starts;
- one `OPEN` stock alert per branch+ingredient, so the alert job is idempotent;
- a recipe row has exactly one owner (menu item or modifier);
- member phone and staff phone are unique, as is `employee_code` / `sku` / `order_no`.

## What application code must still do

The database cannot enforce these, because they span rows or depend on the clock.

**Placing an order — one transaction, two gates:**

```sql
BEGIN;
-- 1. price the lines from menu + modifier deltas, write totalling in ONE statement
-- 2. lock the lots this recipe needs, oldest expiry first
SELECT id, qty_remaining FROM inventory_lot
 WHERE branch_id = $1 AND ingredient_id = ANY($2) AND qty_remaining > 0
 ORDER BY expires_on NULLS LAST
 FOR UPDATE;
--    short on any ingredient -> ROLLBACK, 409 Conflict
UPDATE inventory_lot SET qty_remaining = qty_remaining - $n WHERE id = $lot;
-- 3. availability gate: 0 rows affected means sold out at this branch
UPDATE branch_menu_item SET available_qty = available_qty - $servings
 WHERE branch_id = $1 AND menu_item_id = $m AND available_qty >= $servings;
-- 4. one stock_movement row per (order line, ingredient) with reason SALE_CONSUMPTION
COMMIT;
```

Requirements per line are `recipe_requirement` for the menu item × servings
(servings = quantity × the chosen SIZE modifier's `servings_multiplier`) plus each
`order_item_modifier`'s own recipe × its quantity. `database/seed.sql` runs exactly
this calculation in SQL, so it doubles as a reference implementation.

**Cancelling an order:** read that order's `SALE_CONSUMPTION` movements, write
`ORDER_RESTORE` rows with the negated `delta_qty` against the same lots, add the
`qty_remaining` back, set `cancelled_at`. Net effect on the ledger is zero.

**Totals:** `subtotal`, `discount` and `total` must be written in a single `UPDATE`.
The `CHECK (total = subtotal - discount)` is deliberately not deferrable, so
setting `subtotal` on its own fails — as it should.

**Low-stock alerts:** compare `SUM(qty_remaining)` per branch+ingredient against
`stock_threshold.safety_qty`; insert an `OPEN` row when below. The partial unique
index makes that safe to run on a timer. `seed.sql` derives its alerts the same way.

## Reporting notes

- **Revenue** is defined as orders in `PAID` or `COMPLETED`. A `PLACED` order has
  already consumed stock but has no money behind it yet — decide whether your
  financial summary wants it, and put that in the spec either way.
- **COGS** falls out of the ledger with no extra work:
  `-SUM(stock_movement.delta_qty * inventory_lot.unit_cost)` per order line.
  A cancelled order's `SALE_CONSUMPTION` + `ORDER_RESTORE` pair nets to zero, so
  it drops out of profit on its own.
- **Daily** boundaries: `(placed_at AT TIME ZONE 'Asia/Ho_Chi_Minh')::date`.
- **Keyword search** (requirement 4.8) is `ILIKE '%term%'` across `menu_item.name`,
  `ingredient.name` and `member.full_name`, which are all covered by GIN trigram
  indexes.

## Deliberately not modelled

Audit trail beyond `auth_event` (the old template's `USERTRANSACTION`), loyalty
tiers, order status history/replay, tax, multi-currency, delivery, employee shifts,
refunds beyond a `REFUNDED` payment status.

## Open questions for `/architect`

1. Which Postgres client: raw `pg`, `postgres.js`, or Drizzle/Prisma? The schema
   above is written to be used directly, without an ORM, which is the simplest
   thing that can satisfy the requirements.
2. Revenue policy for `PLACED` orders (see Reporting notes).
3. Whether `stock_movement` receipts should also be recorded as movements
   (`qty_received` is currently the ledger baseline, so `qty_remaining =
   qty_received + SUM(delta_qty)`).
4. Demo passwords are all `gelato123` with a shared argon2id hash — fine for a
   course demo, must not survive contact with anything real.
