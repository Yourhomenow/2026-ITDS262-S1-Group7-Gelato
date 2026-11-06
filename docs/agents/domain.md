# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Layout: single-context

One `CONTEXT.md` at the repo root plus `docs/adr/`. The gelato domain vocabulary
(branch, member, menu item, ingredient, inventory lot, order, promotion) is shared
by the API and the web client, so a single context is the honest model. Per-app
specifics live in the nested `AGENTS.md` files (`server/AGENTS.md`,
`clients/AGENTS.md`), not in separate contexts.

```
/
├── CONTEXT.md
├── docs/
│   ├── adr/
│   │   └── 0001-....md
│   ├── agents/          ← these files
│   └── specs/           ← written by /architect
├── server/
├── clients/
└── database/
```

## Before exploring, read these

- **`CONTEXT.md`** at the repo root.
- **`docs/adr/`**: read ADRs that touch the area you're about to work in.
- **`database/README.md`**: the schema decisions (D1–D15) are load-bearing and are
  the closest thing this repo has to architecture decisions today. Until those are
  promoted into `docs/adr/`, treat them as ADRs.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

Known traps in this domain, worth watching for:

- **"stock" vs "availability"** — stock is ingredient lots; availability is how many
  servings of a menu item a branch will sell today. They are different tables.
- **"member" vs "customer"** — the brief says both. A member is a registered loyalty
  account with a phone number; a walk-in customer has no row anywhere.
- **"menu item" vs "product"** — always a menu item.
- **"inventory item"** (requirement 1.7) — means a stock record with a unique ID:
  an `inventory_lot`, not an ingredient.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_
