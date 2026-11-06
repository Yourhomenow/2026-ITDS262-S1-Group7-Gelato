-- ============================================================================
-- Gelato Store — PostgreSQL schema
-- ============================================================================

-- Conventions
--   * PostgreSQL 13+ (uses gen_random_uuid(), no extension needed).
--   * All timestamps are timestamptz. "Daily" report boundaries are computed
--     with AT TIME ZONE against the single shop timezone (SHOP_TIMEZONE,
--     Asia/Ho_Chi_Minh by default) — never from the server's local clock.
--   * Money and quantities are numeric, never float. Money is numeric(12,2),
--     ingredient quantities numeric(12,3). The API serialises money as a
--     string so no precision is lost in JSON.
--   * Nothing is hard-deleted. Rows carry is_active / status instead, because
--     reports and foreign keys point at history.
--   * Business rules that can be enforced by the database are enforced by the
--     database (CHECKs, partial unique indexes). Rules that need several rows
--     or the clock (stock deduction, discount math) live in one transaction
--     in the service layer.
--
-- Apply with:  psql "$DATABASE_URL" -f database/schema.sql
-- Then seed:   psql "$DATABASE_URL" -f database/seed.sql
-- ============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- keyword search (requirement 4.8)

-- ---------------------------------------------------------------------------
-- Drop in dependency-safe order so this file is re-runnable during development.
-- ---------------------------------------------------------------------------
DROP TABLE IF EXISTS stock_movement       CASCADE;
DROP TABLE IF EXISTS stock_alert          CASCADE;
DROP TABLE IF EXISTS stock_threshold      CASCADE;
DROP TABLE IF EXISTS purchase_order_item  CASCADE;
DROP TABLE IF EXISTS purchase_order       CASCADE;
DROP TABLE IF EXISTS inventory_lot        CASCADE;
DROP TABLE IF EXISTS order_promotion      CASCADE;
DROP TABLE IF EXISTS payment              CASCADE;
DROP TABLE IF EXISTS order_item_modifier  CASCADE;
DROP TABLE IF EXISTS order_item           CASCADE;
DROP TABLE IF EXISTS customer_order       CASCADE;
DROP TABLE IF EXISTS promotion_menu_item  CASCADE;
DROP TABLE IF EXISTS promotion            CASCADE;
DROP TABLE IF EXISTS member               CASCADE;
DROP TABLE IF EXISTS branch_menu_item     CASCADE;
DROP TABLE IF EXISTS recipe_requirement   CASCADE;
DROP TABLE IF EXISTS modifier             CASCADE;
DROP TABLE IF EXISTS menu_item            CASCADE;
DROP TABLE IF EXISTS ingredient           CASCADE;
DROP TABLE IF EXISTS supplier             CASCADE;
DROP TABLE IF EXISTS staff_session        CASCADE;
DROP TABLE IF EXISTS auth_event           CASCADE;
DROP TABLE IF EXISTS otp_challenge        CASCADE;
DROP TABLE IF EXISTS staff_account        CASCADE;
DROP TABLE IF EXISTS branch               CASCADE;

DROP TYPE IF EXISTS staff_role;
DROP TYPE IF EXISTS modifier_kind;
DROP TYPE IF EXISTS po_status;
DROP TYPE IF EXISTS order_status;
DROP TYPE IF EXISTS prep_status;
DROP TYPE IF EXISTS payment_method;
DROP TYPE IF EXISTS payment_status;
DROP TYPE IF EXISTS movement_reason;
DROP TYPE IF EXISTS alert_status;
DROP TYPE IF EXISTS auth_event_type;

-- ---------------------------------------------------------------------------
-- Enumerations
-- ---------------------------------------------------------------------------
CREATE TYPE staff_role       AS ENUM ('STAFF', 'MANAGER');
CREATE TYPE modifier_kind    AS ENUM ('SIZE', 'TOPPING', 'FLAVOR');
CREATE TYPE po_status        AS ENUM ('DRAFT', 'SENT', 'PARTIALLY_RECEIVED', 'RECEIVED', 'CANCELLED');
CREATE TYPE order_status     AS ENUM ('PLACED', 'PAID', 'COMPLETED', 'CANCELLED');
CREATE TYPE prep_status      AS ENUM ('QUEUED', 'BLENDING', 'RESTING', 'READY', 'SERVED');
CREATE TYPE payment_method   AS ENUM ('QR_CODE', 'CREDIT_CARD', 'BANK_TRANSFER');
CREATE TYPE payment_status   AS ENUM ('PENDING', 'SUCCEEDED', 'FAILED', 'REFUNDED');
CREATE TYPE movement_reason  AS ENUM ('PURCHASE_RECEIPT', 'SALE_CONSUMPTION', 'ORDER_RESTORE', 'WASTAGE', 'EXPIRY', 'ADJUSTMENT');
CREATE TYPE alert_status     AS ENUM ('OPEN', 'RESOLVED', 'DISMISSED');
CREATE TYPE auth_event_type  AS ENUM ('LOGIN_PASSWORD_OK', 'LOGIN_FAILED', 'OTP_SENT', 'OTP_FAILED', 'OTP_OK', 'LOGOUT');

-- ===========================================================================
-- 1. ORGANISATION AND ACCESS
-- ===========================================================================

-- Every user, lot, order and purchase order belongs to a branch. Three report
-- requirements are cross-branch comparisons, so the branch is not optional.
CREATE TABLE branch (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code       text NOT NULL UNIQUE,
  name       text NOT NULL,
  address    text NOT NULL,
  opened_on  date,
  is_active  boolean NOT NULL DEFAULT true
);

-- One table for both roles. Staff and managers share the login, OTP and session
-- flow; only authorisation differs, so role is a column, not a second table.
CREATE TABLE staff_account (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id      uuid NOT NULL REFERENCES branch(id),
  employee_code  text NOT NULL UNIQUE,
  full_name      text NOT NULL,
  phone          text NOT NULL UNIQUE,       -- MFA target, E.164 ('+8490...')
  email          text UNIQUE,
  role           staff_role NOT NULL,
  password_hash  text NOT NULL,              -- argon2id via Bun.password
  is_active      boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX staff_account_branch_idx ON staff_account (branch_id);

-- One challenge per login attempt. The OTP is stored hashed, never in clear.
CREATE TABLE otp_challenge (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id    uuid NOT NULL REFERENCES staff_account(id) ON DELETE CASCADE,
  code_hash   text NOT NULL,
  phone       text NOT NULL,
  attempts    int NOT NULL DEFAULT 0 CHECK (attempts >= 0),   -- app caps at 5, then burns the challenge
  expires_at  timestamptz NOT NULL,
  consumed_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (expires_at > created_at)
);
CREATE INDEX otp_challenge_staff_idx ON otp_challenge (staff_id, created_at DESC);

-- A session row exists only after the OTP challenge was consumed. That is the
-- MFA requirement expressed as a schema invariant: password check alone can
-- never mint one.
CREATE TABLE staff_session (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  staff_id   uuid NOT NULL REFERENCES staff_account(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  CHECK (expires_at > created_at)
);
CREATE INDEX staff_session_staff_idx ON staff_session (staff_id);

-- Replaces the LOGINLOG table from the old bookshop template. Needed to reason
-- about OTP abuse and to answer "who was on shift when this was rung up".
CREATE TABLE auth_event (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  staff_id   uuid REFERENCES staff_account(id) ON DELETE CASCADE,
  type       auth_event_type NOT NULL,
  success    boolean NOT NULL,
  ip         inet,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX auth_event_staff_idx ON auth_event (staff_id, created_at DESC);

-- ===========================================================================
-- 2. CATALOGUE: INGREDIENTS, MENU ITEMS, MODIFIERS
-- ===========================================================================

CREATE TABLE supplier (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name      text NOT NULL,
  phone     text,
  email     text,
  address   text,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE ingredient (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name               text NOT NULL UNIQUE,
  unit               text NOT NULL CHECK (unit IN ('g', 'ml', 'piece')),
  unit_cost          numeric(12,2) NOT NULL CHECK (unit_cost >= 0),  -- current cost basis for COGS
  storage_guidelines text,
  shelf_life_days    int CHECK (shelf_life_days > 0)
);
CREATE INDEX ingredient_name_trgm_idx ON ingredient USING gin (name gin_trgm_ops);

CREATE TABLE menu_item (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sku                text NOT NULL UNIQUE,
  name               text NOT NULL,
  description        text,
  category           text NOT NULL CHECK (category IN ('GELATO', 'SORBET', 'DRINK', 'CAKE')),
  base_price         numeric(12,2) NOT NULL CHECK (base_price >= 0),
  storage_guidelines text,
  is_active          boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX menu_item_name_trgm_idx ON menu_item USING gin (name gin_trgm_ops);

-- A modifier is a size / topping / flavour choice attached to an order line.
-- menu_item_id NULL means "available on every item".
--
-- servings_multiplier is what makes "sizing" work without duplicating a recipe
-- per size: a large cup is 3 servings of the item's base recipe and takes 3 off
-- branch_menu_item.available_qty. It stays 1 for toppings, whose own recipe is
-- the thing that scales (one order_item_modifier row = one portion of topping).
CREATE TABLE modifier (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind                modifier_kind NOT NULL,
  name                text NOT NULL,
  price_delta         numeric(12,2) NOT NULL DEFAULT 0,
  servings_multiplier numeric(5,2) NOT NULL DEFAULT 1 CHECK (servings_multiplier > 0),
  menu_item_id        uuid REFERENCES menu_item(id) ON DELETE CASCADE,
  is_active           boolean NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX modifier_scope_uniq ON modifier (
  COALESCE(menu_item_id, '00000000-0000-0000-0000-000000000000'::uuid), kind, name
);

-- What a menu item OR a modifier consumes, per single unit sold.
-- One table for both owners keeps order consumption to a single query, while
-- the two foreign keys and the CHECK still make every row referential-integrity
-- checked (no polymorphic owner_type/owner_id guessing).
CREATE TABLE recipe_requirement (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  menu_item_id  uuid REFERENCES menu_item(id) ON DELETE CASCADE,
  modifier_id   uuid REFERENCES modifier(id) ON DELETE CASCADE,
  ingredient_id uuid NOT NULL REFERENCES ingredient(id),
  quantity      numeric(12,3) NOT NULL CHECK (quantity > 0),   -- in ingredient.unit
  CHECK (num_nonnulls(menu_item_id, modifier_id) = 1)
);
CREATE UNIQUE INDEX recipe_requirement_menu_item_uniq
  ON recipe_requirement (menu_item_id, ingredient_id) WHERE menu_item_id IS NOT NULL;
CREATE UNIQUE INDEX recipe_requirement_modifier_uniq
  ON recipe_requirement (modifier_id, ingredient_id) WHERE modifier_id IS NOT NULL;
CREATE INDEX recipe_requirement_ingredient_idx ON recipe_requirement (ingredient_id);

-- Sellable availability at a branch. A row means "we offer this here"; a
-- missing row means "we don't". available_qty is a manual serving count that
-- staff lower when a flavour runs out, and is checked *in addition to*
-- ingredient stock (they answer different questions: "do we have milk?" vs
-- "have we sold out of pistachio?").
CREATE TABLE branch_menu_item (
  branch_id     uuid NOT NULL REFERENCES branch(id),
  menu_item_id  uuid NOT NULL REFERENCES menu_item(id),
  available_qty int NOT NULL DEFAULT 0 CHECK (available_qty >= 0),
  price         numeric(12,2) CHECK (price >= 0),   -- NULL means use menu_item.base_price
  is_sold_out   boolean NOT NULL DEFAULT false,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (branch_id, menu_item_id)
);

-- ===========================================================================
-- 3. INVENTORY
-- ===========================================================================

-- Stock arrives in batches, each with its own import date, supplier, cost and
-- expiry. Current stock for an ingredient is SUM(qty_remaining), ordered by
-- expires_on so consumption is first-expired-first-out.
CREATE TABLE inventory_lot (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id         uuid NOT NULL REFERENCES branch(id),
  ingredient_id     uuid NOT NULL REFERENCES ingredient(id),
  supplier_id       uuid REFERENCES supplier(id),
  purchase_order_id uuid,                 -- FK added below, after purchase_order exists
  qty_received      numeric(12,3) NOT NULL CHECK (qty_received > 0),
  qty_remaining     numeric(12,3) NOT NULL CHECK (qty_remaining >= 0),
  unit_cost         numeric(12,2) NOT NULL CHECK (unit_cost >= 0),
  imported_on       date NOT NULL DEFAULT current_date,
  expires_on        date,
  received_by       uuid REFERENCES staff_account(id),
  created_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (qty_remaining <= qty_received),
  CHECK (expires_on IS NULL OR expires_on >= imported_on)
);
CREATE INDEX inventory_lot_stock_idx ON inventory_lot (branch_id, ingredient_id)
  WHERE qty_remaining > 0;
CREATE INDEX inventory_lot_expiry_idx ON inventory_lot (expires_on)
  WHERE qty_remaining > 0;

-- The safety threshold that drives the low-stock alert (requirement 4.6).
CREATE TABLE stock_threshold (
  branch_id     uuid NOT NULL REFERENCES branch(id),
  ingredient_id uuid NOT NULL REFERENCES ingredient(id),
  safety_qty    numeric(12,3) NOT NULL CHECK (safety_qty >= 0),
  PRIMARY KEY (branch_id, ingredient_id)
);

-- One OPEN alert per branch+ingredient, so the alert job is idempotent: it can
-- run every minute and still only ever have one live row per shortage.
CREATE TABLE stock_alert (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id     uuid NOT NULL REFERENCES branch(id),
  ingredient_id uuid NOT NULL REFERENCES ingredient(id),
  qty_at_alert  numeric(12,3) NOT NULL,
  threshold_qty numeric(12,3) NOT NULL,
  status        alert_status NOT NULL DEFAULT 'OPEN',
  raised_at     timestamptz NOT NULL DEFAULT now(),
  resolved_at   timestamptz
);
CREATE UNIQUE INDEX stock_alert_open_uniq ON stock_alert (branch_id, ingredient_id)
  WHERE status = 'OPEN';

CREATE TABLE purchase_order (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  po_number   text NOT NULL UNIQUE,
  branch_id   uuid NOT NULL REFERENCES branch(id),
  supplier_id uuid NOT NULL REFERENCES supplier(id),
  status      po_status NOT NULL DEFAULT 'DRAFT',
  created_by  uuid NOT NULL REFERENCES staff_account(id),
  issued_at   timestamptz,
  expected_on date,
  received_at timestamptz,
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX purchase_order_branch_idx ON purchase_order (branch_id, created_at DESC);

CREATE TABLE purchase_order_item (
  purchase_order_id uuid NOT NULL REFERENCES purchase_order(id) ON DELETE CASCADE,
  ingredient_id     uuid NOT NULL REFERENCES ingredient(id),
  qty_ordered       numeric(12,3) NOT NULL CHECK (qty_ordered > 0),
  qty_received      numeric(12,3) NOT NULL DEFAULT 0 CHECK (qty_received >= 0),
  unit_cost         numeric(12,2) NOT NULL CHECK (unit_cost >= 0),
  PRIMARY KEY (purchase_order_id, ingredient_id),
  CHECK (qty_received <= qty_ordered)
);

ALTER TABLE inventory_lot
  ADD CONSTRAINT inventory_lot_purchase_order_fk
  FOREIGN KEY (purchase_order_id) REFERENCES purchase_order(id);

-- Append-only stock ledger. Every change to qty_remaining (and every quantity
-- change at all) writes one row here in the same transaction, so the ledger and
-- the live quantity can be reconciled and mistakes traced to a person.
-- Cancelling an order reads its SALE_CONSUMPTION rows and writes ORDER_RESTORE
-- rows against the same lots — the ledger, not the recipe, is the record of what
-- was actually consumed.
CREATE TABLE stock_movement (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  inventory_lot_id uuid NOT NULL REFERENCES inventory_lot(id),
  branch_id        uuid NOT NULL REFERENCES branch(id),
  ingredient_id    uuid NOT NULL REFERENCES ingredient(id),
  delta_qty        numeric(12,3) NOT NULL CHECK (delta_qty <> 0),
  reason           movement_reason NOT NULL,
  order_item_id    uuid,               -- set for SALE_CONSUMPTION / ORDER_RESTORE
  note             text,
  created_by       uuid REFERENCES staff_account(id),
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX stock_movement_stock_idx ON stock_movement (branch_id, ingredient_id, created_at DESC);
CREATE INDEX stock_movement_order_item_idx ON stock_movement (order_item_id);

-- ===========================================================================
-- 4. CRM AND PROMOTIONS
-- ===========================================================================

CREATE TABLE member (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_code text NOT NULL UNIQUE,
  full_name   text NOT NULL,
  phone       text NOT NULL UNIQUE,     -- primary lookup key
  email       text,
  birthday    date,
  points      int NOT NULL DEFAULT 0 CHECK (points >= 0),
  joined_at   timestamptz NOT NULL DEFAULT now(),
  is_active   boolean NOT NULL DEFAULT true
);
CREATE INDEX member_name_trgm_idx ON member USING gin (full_name gin_trgm_ops);

CREATE TABLE promotion (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text NOT NULL,
  discount_rate numeric(5,2) NOT NULL CHECK (discount_rate > 0 AND discount_rate <= 100),
  starts_at     timestamptz NOT NULL,
  ends_at       timestamptz NOT NULL,
  is_active     boolean NOT NULL DEFAULT true,
  created_by    uuid NOT NULL REFERENCES staff_account(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at)
);

CREATE TABLE promotion_menu_item (
  promotion_id uuid NOT NULL REFERENCES promotion(id) ON DELETE CASCADE,
  menu_item_id uuid NOT NULL REFERENCES menu_item(id),
  PRIMARY KEY (promotion_id, menu_item_id)
);

-- ===========================================================================
-- 5. ORDERS, PAYMENT, PREPARATION
-- ===========================================================================

CREATE TABLE customer_order (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_no     text NOT NULL UNIQUE,
  branch_id    uuid NOT NULL REFERENCES branch(id),
  member_id    uuid REFERENCES member(id),
  created_by   uuid NOT NULL REFERENCES staff_account(id),
  status       order_status NOT NULL DEFAULT 'PLACED',
  subtotal     numeric(12,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
  discount     numeric(12,2) NOT NULL DEFAULT 0 CHECK (discount >= 0),
  total        numeric(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
  notes        text,
  placed_at    timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  cancelled_at timestamptz,
  CHECK (total = subtotal - discount)
);
CREATE INDEX customer_order_branch_day_idx ON customer_order (branch_id, placed_at DESC);
CREATE INDEX customer_order_member_idx ON customer_order (member_id);

-- Preparation status lives on the line, not the order: each cup is blended and
-- rested separately, and staff advance them independently.
CREATE TABLE order_item (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     uuid NOT NULL REFERENCES customer_order(id) ON DELETE CASCADE,
  menu_item_id uuid NOT NULL REFERENCES menu_item(id),
  quantity     int NOT NULL CHECK (quantity > 0),
  unit_price   numeric(12,2) NOT NULL CHECK (unit_price >= 0),  -- base + modifier deltas, per unit
  line_total   numeric(12,2) NOT NULL CHECK (line_total >= 0),
  prep_status  prep_status NOT NULL DEFAULT 'QUEUED',
  notes        text,
  CHECK (line_total = unit_price * quantity)
);
CREATE INDEX order_item_order_idx ON order_item (order_id);
CREATE INDEX order_item_prep_idx ON order_item (prep_status)
  WHERE prep_status <> 'SERVED';

CREATE TABLE order_item_modifier (
  order_item_id uuid NOT NULL REFERENCES order_item(id) ON DELETE CASCADE,
  modifier_id   uuid NOT NULL REFERENCES modifier(id),
  quantity      int NOT NULL DEFAULT 1 CHECK (quantity > 0),
  price_delta   numeric(12,2) NOT NULL DEFAULT 0,   -- snapshot: menu prices change, sales don't
  PRIMARY KEY (order_item_id, modifier_id)
);

CREATE TABLE payment (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     uuid NOT NULL REFERENCES customer_order(id),
  method       payment_method NOT NULL,
  status       payment_status NOT NULL DEFAULT 'PENDING',
  amount       numeric(12,2) NOT NULL CHECK (amount > 0),
  provider_ref text,                    -- gateway transaction id for reconciliation
  paid_at      timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX payment_order_idx ON payment (order_id);
-- An order can have failed attempts before a successful one, but never two
-- successful payments.
CREATE UNIQUE INDEX payment_one_success_uniq ON payment (order_id)
  WHERE status = 'SUCCEEDED';

-- Which promotion was applied to which order, and what it actually took off.
-- Stored rather than recomputed: the campaign can be edited after the sale.
CREATE TABLE order_promotion (
  order_id        uuid NOT NULL REFERENCES customer_order(id) ON DELETE CASCADE,
  promotion_id    uuid NOT NULL REFERENCES promotion(id),
  discount_amount numeric(12,2) NOT NULL CHECK (discount_amount >= 0),
  PRIMARY KEY (order_id, promotion_id)
);

-- Circular dependency: stock_movement references order_item, which is defined
-- here. Added after the fact to keep each section readable.
ALTER TABLE stock_movement
  ADD CONSTRAINT stock_movement_order_item_fk
  FOREIGN KEY (order_item_id) REFERENCES order_item(id);

COMMIT;
