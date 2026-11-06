# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

Edit the right-hand column to match whatever vocabulary you actually use.

## Labels created on GitHub

The five labels above exist in the repository. Beyond triage, the project also uses:

| Label | Meaning |
| --- | --- |
| `area:auth` | Requirements 1.x — accounts, credentials, MFA/OTP, sessions |
| `area:orders` | Requirements 3.x — orders, customisation, preparation, payment |
| `area:inventory` | Requirements 4.x — menu, stock, purchase orders, low-stock alerts |
| `area:reports` | Requirements 2.x — financial, sales, cross-branch, daily itemised |
| `area:crm` | Requirements 5.x — members and promotions |
| `area:platform` | Neither feature nor bug: tooling, schema, CI, docs |
| `type:spec` | A design issue produced by `/architect` |
