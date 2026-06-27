# Portal documentation

Service-scoped documentation for the **portal** service. This tree holds only what concerns portal alone; anything reusable lives in the workspace-wide [`docs/`](../../../docs/).

## Two-tier model

| Tier | Location | Holds |
| ---- | -------- | ----- |
| **Global** | [`docs/`](../../../docs/) (repo root) | Standards, decisions, terms, and investigations shared across services, the shared Go/Nix packages, and deployment. |
| **Service** | `services/portal/docs/` (here) | Decisions, designs, investigations, and debt that concern **only** portal. |

**Rule of thumb:** if another service would inherit it, it's global; if it dies with portal, it belongs here.

- A portal feature design → `specs/` (here).
- A portal-only decision that does not bind other services → `adrs/` (here).
- A workspace standard portal merely *implements* (DDD/CQRS, Go code style, UUIDv7) → stays in [`docs/adrs/`](../../../docs/adrs/) / [`docs/conventions/`](../../../docs/conventions/).
- A glossary term or convention → always global; the workspace is the single source. Link to it, do not redefine it here.

## Tracks

| Track | Question it answers | Lifecycle |
| ----- | ------------------- | --------- |
| [adrs/](adrs/) | *Why did portal choose this?* | Append-only, numbered |
| [specs/](specs/) | *How is this portal feature built?* | Living per spec |
| [findings/](findings/) | *What did we find investigating portal?* | Append-only, dated |
| [debt/](debt/) | *What does portal still owe?* | Living + ledger |

## Format authority

Each track here mirrors its workspace counterpart. The **format, naming, and lifecycle rules are defined once, globally** — each track's `README.md` links to the authoritative workspace track. Use the local `TEMPLATE.md` to start a new document. See [`docs/AGENTS.md`](../../../docs/AGENTS.md) for the full per-track convention reference.
