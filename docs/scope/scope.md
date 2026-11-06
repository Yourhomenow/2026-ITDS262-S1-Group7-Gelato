# Scope: Gelato store and management system

A gelato chain's store system: staff take orders and watch preparation, managers run the menu, stock, promotions and reporting, and every sale moves real inventory. Built for a small team delivering all 30 requirements in the brief.

**Build approach:** Tracer Bullet (every feature ships end to end through the database, the API and the screen, so a slice that slips never breaks the demo).
**Workflow:** Beta (after `/develop`, `/check verify` then `/test`). Auth and payments carry the `· GA` tag, so those two also get a fresh model review and a document pass. The project default level of rigor. `/architect` is the recommended first stop for a feature with a real decision, but skippable when you already know the build.

_These are recommendations to keep your build orderly, not requirements. Skip anything that does not fit: if you already know how to build a feature, use `/develop` and skip `/architect`. You decide when a feature is `done`._

## At a glance

| # | Feature | Phase | Status |
|---|---------|-------|--------|
| 1 | Stack scaffold | Foundation | existing |
| 2 | Data model | Foundation | existing |
| 3 | API foundation | Foundation | planned |
| 4 | Database access layer | Foundation | planned |
| 5 | Coding standards and tooling | Foundation | planned |
| 6 | App shell and design foundation | Foundation | planned |
| 7 | Account registration | Slice 1 | planned |
| 8 | Sign in with password and OTP | Slice 1 | planned |
| 9 | Menu browse and item detail | Slice 1 | planned |
| 10 | Create an order with live stock validation | Slice 1 | planned |
| 11 | Preparation status board | Slice 1 | planned |
| 12 | Record a payment | Slice 1 | planned |
| 13 | Menu item management with recipes | Slice 2 | planned |
| 14 | Inventory stock registration | Slice 2 | planned |
| 15 | Stock audit and low stock alerts | Slice 2 | planned |
| 16 | Purchase orders | Slice 2 | planned |
| 17 | Keyword search across menu and stock | Slice 2 | planned |
| 18 | Availability adjustment | Slice 2 | planned |
| 19 | Member lookup and maintenance | Slice 3 | planned |
| 20 | Promotions and checkout discount | Slice 3 | planned |
| 21 | Daily itemised sales report | Slice 4 | planned |
| 22 | Branch summaries and comparison | Slice 4 | planned |

## Foundations

### 1. Stack scaffold · existing
Bun and TypeScript backend with a Next 16 frontend, both booting and typechecking. The server has no domain logic yet. code in `server/src/`, `clients/src/`

### 2. Data model · existing
25 table Postgres schema with the constraints that encode the brief, a demo seed, and the decisions behind both. Covers requirement 1.6: every account and every stock record carries a unique identifier that supports direct lookup. code in `database/`

### 3. API foundation · needs a decision
The seam every feature hangs off: how routes take path parameters, how request bodies are validated, what an error looks like, and where the auth check sits. Today the router is a flat path lookup with no parameters and no validation, so this decision is blocking before any endpoint can be trusted.
**Done when:** a route with a path parameter and a validated body returns the documented success and error shapes, and one shared mechanism rejects an unauthenticated request.
- [ ] Design it (spec): `/architect API foundation`

### 4. Database access layer · needs a decision
How the API talks to Postgres: the client, how queries are written, how migrations run once the schema starts changing, and how one order placement holds a transaction.
**Done when:** the API reads a real row from Postgres through the chosen client, and a change to the schema can be applied to a fresh database by one documented command.
- [ ] Design it (spec): `/architect database access layer`

### 5. Coding standards and tooling
Capture the conventions actually in use, then install the checks that keep a small team honest: a test runner, lint and format, and a typecheck that runs on every change.
**Done when:** root `AGENTS.md` reflects the real stack, and `bun test`, typecheck and lint all run clean from a fresh clone.
- [ ] Capture conventions and tooling choices: `/audit`
- [ ] Install the tooling: `/develop tooling`
- [ ] Check it runs clean: `/test`

### 6. App shell and design foundation · needs a decision
The frame every screen sits in: sign in wall, role aware navigation for staff and manager, page layout, tables, forms, and the visual language for a food product. Deciding it once stops each later screen inventing its own.
**Done when:** a signed in user reaches a role appropriate home screen with navigation, and a form plus a table render with consistent spacing, states and focus handling.
- [ ] Design it (spec): `/architect app shell and design foundation`

## Slice 1: One real sale

The walking skeleton. A staff member registers, signs in with a password and an OTP, sees the menu, rings up a gelato, watches it move through preparation, and takes payment. Real database, real auth, real screen, narrow breadth. Everything later thickens this thread.

### 7. Account registration · needs a decision
Staff and managers create their own account with a phone number, which later becomes the OTP target. Covers requirements 1.1 and 1.2.
**Done when:** a person can register as staff or as manager, a duplicate phone number is refused, and the new account can sign in.
- [ ] Design it (spec): `/architect account registration`

### 8. Sign in with password and OTP · needs a decision · GA
Two step sign in for both roles, with the one time code delivered to the registered phone before any session exists. Covers requirements 1.3 to 1.5, and is the hardest correctness problem in the brief.
**Done when:** a correct password alone yields no session, a wrong or expired or exhausted code is refused, and a complete sign in creates a session that role checks can read.
- [ ] Design it (spec): `/architect sign in with password and OTP`

### 9. Menu browse and item detail
The read side staff need before selling: today's menu per branch with availability, and a detail page with recipe, storage guidance and price. Covers requirement 4.3.
**Done when:** a staff member sees the branch menu, a sold out item is visibly unavailable, and the detail page shows the item's recipe and storage guidance.
- [ ] Build it: `/develop menu browse and item detail`

### 10. Create an order with live stock validation · needs a decision
The core write path: pick items, choose size and toppings, and have the system refuse the sale when ingredients or remaining servings cannot cover it. Covers requirements 3.1, 3.2 and 3.3, and it is the transaction that decides whether overselling is even possible.
**Done when:** an order deducts both ingredient stock and remaining servings in one transaction, two simultaneous orders for the last serving leave exactly one accepted, and a cancelled order returns what it took.
- [ ] Design it (spec): `/architect create an order with live stock validation`

### 11. Preparation status board · needs a decision
Staff move each cup through queued, blending, resting, ready and served, and the board shows every open line live. Covers requirements 3.4 and 3.5. Polling or push is the decision.
**Done when:** a status change is visible to another signed in screen within a few seconds, and the board shows only open lines with their current state.
- [ ] Design it (spec): `/architect preparation status board`

### 12. Record a payment · needs a decision · GA
Take payment by QR code, credit card or bank transfer against an order, and mark it settled. Simulated, no gateway: the method, the reference and the outcome are recorded honestly. Covers requirement 3.6.
**Done when:** an order can be settled by each of the three methods, a failed attempt does not leave the order paid, and an order cannot be settled twice.
- [ ] Design it (spec): `/architect record a payment`

## Slice 2: Catalogue and stock

### 13. Menu item management with recipes · needs a decision
Managers create and update menu items with their recipe, ingredient requirements, storage guidance and price. Covers requirements 4.1 and 4.2.
**Done when:** a manager creates an item with at least one ingredient requirement, edits its recipe and price, and the change is visible to staff on the next order.
- [ ] Design it (spec): `/architect menu item management with recipes`

### 14. Inventory stock registration · needs a decision
Receive a delivery as a batch with quantity, import date, supplier and shelf life, and see the resulting on hand figure. Covers requirement 4.4.
**Done when:** receiving stock creates a batch that raises on hand quantity, and the same item received twice shows two batches with different import dates and costs.
- [ ] Design it (spec): `/architect inventory stock registration`

### 15. Stock audit and low stock alerts · needs a decision
Managers see current stock per branch against a safety threshold, and the system raises an alert when an ingredient falls below it. Covers requirements 4.5 and 4.6.
**Done when:** an ingredient below its threshold produces exactly one open alert, and raising the stock back above the threshold clears it.
- [ ] Design it (spec): `/architect stock audit and low stock alerts`

### 16. Purchase orders · needs a decision
Managers issue a purchase order to a supplier, then receive it into stock, which is how a low stock shortage gets closed. Covers requirement 4.7.
**Done when:** a purchase order moves from draft to sent to received, and receiving it creates the matching stock batches.
- [ ] Design it (spec): `/architect purchase orders`

### 17. Keyword search across menu and stock · needs a decision
One search box that finds menu items and ingredients by keyword, which is how a busy counter finds a flavour without scrolling. Covers requirement 4.8.
**Done when:** a keyword returns matching menu items and stock records, an empty result renders a clear empty state, and search stays responsive with a full menu loaded.
- [ ] Design it (spec): `/architect keyword search across menu and stock`

### 18. Availability adjustment
Staff lower or raise how many servings of an item the branch will sell today, without touching ingredient stock. Covers requirement 4.9.
**Done when:** a staff member sets an item to zero and the next order screen shows it as sold out, while the item's ingredient stock is unchanged.
- [ ] Build it: `/develop availability adjustment`

## Slice 3: Customers and promotions

### 19. Member lookup and maintenance
Find a member by phone number or name, register a new one, and correct their details. Covers requirements 5.1 to 5.3.
**Done when:** a search by partial phone number or partial name finds the member, a duplicate phone number is refused, and an edit is saved and reflected on the next lookup.
- [ ] Build it: `/develop member lookup and maintenance`

### 20. Promotions and checkout discount · needs a decision
Managers define a campaign with a name, a discount rate, the items it applies to and an active window. Checkout applies it and records what it took off. Covers requirements 5.4 and 5.5.
**Done when:** an active campaign on an order's items reduces the total by the configured rate, an expired campaign does not, and the discount stays recorded after the campaign is edited.
- [ ] Design it (spec): `/architect promotions and checkout discount`

## Slice 4: Reporting

### 21. Daily itemised sales report
Every line sold on a chosen day, per branch, with quantity, price and payment method. Covers requirement 2.4 and works for staff and managers.
**Done when:** a chosen day lists its sold lines with totals, a cancelled order is excluded, and the day boundary follows the shop timezone rather than the server clock.
- [ ] Build it: `/develop daily itemised sales report`

### 22. Branch summaries and comparison · needs a decision
Revenue, cost of goods and margin per branch, per period, and the same figures side by side across branches. Covers requirements 2.1 to 2.3. Deciding what counts as revenue is the open question.
- [ ] Design it (spec): `/architect branch summaries and comparison`

## Deferred

Out of scope for this pass, kept so the plan stays honest.
- **Audit trail viewer**: browse sign in and OTP events · needs a decision
- **Refunds**: reverse a settled payment · needs a decision
- **Notifications**: email or SMS on low stock · needs a decision
- **Deployment**: run the demo on a hosted server · needs a decision

## Legend

**The decision box.** Every feature carries exactly one, the sub task whose label ends with `(spec)`. Every other box is an execution box and `/architect` never ticks one.

**Lifecycle.** `planned` with `needs a decision` shows one box, `Design it (spec): /architect <feature>`. When `/architect` captures the spec it ticks that box, links the spec, adds the build milestones and the verify and test boxes for this tier. `/develop` ticks milestones, `/check verify` ticks verify, `/test` ticks test. `existing` means it predates the workflow, so `/develop` and `/sync` leave it alone; it is not the same as `done`.

**Tier.** `Beta` closes a feature after `/test`. The `· GA` tag on features 8 and 12 adds a fresh model review and a document pass, because auth and money are where a small team gets hurt.

**Next step.** Always the first unticked box, which is a command or a tracked milestone.
