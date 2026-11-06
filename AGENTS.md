# This is a Full-stack Gelato store and management projects

directory server is backend which is express, and in clients directory It's frontend which is Next.js and we will use PostgreSql as a database


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
