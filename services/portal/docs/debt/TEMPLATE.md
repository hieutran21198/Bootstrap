# <Debt title — short, shape-oriented description of what's wrong>

> **Status**: Open
> **Priority**: Low
> **Hits**: 0
> **Owner**: <person responsible for tracking and shepherding the fix>
> **Created**: YYYY-MM-DD
> **Last reviewed**: YYYY-MM-DD

## What

<One sentence. State the debt directly. "The X is Y because Z." No hedging, no "we should consider …".>

## Why it exists

<Origin: an ADR tradeoff that accepted it, expedience to ship, evolved circumstance, vendor constraint. Cite the ADR or PR if there is one. If there is no clear origin, write "drift" and explain how portal ended up here.>

## Impact

<What is worse because of this debt. Concrete, not "it's ugly". Use only the dimensions that apply; write "—" or omit the rest.>

- **Correctness**: <…>
- **Performance**: <…>
- **Maintainability**: <…>
- **Developer experience**: <…>
- **Security**: <…>

## Resolution

<What paying this down looks like. Even if vague ("rewrite the bus"), say so. If a spec or ADR exists committing to fix, link it. If `Status: Accepted`, this section explains why we will live with it.>

## Encounters

Append-only ledger. Add a row each time this debt causes real pain in real work. **Never edit historic rows** — a wrong row gets a new correction row below it. Heavy investigations live in [`../findings/`](../findings/); link from *Evidence*.

| Date       | Severity                          | Reporter | Symptom                              | Evidence                                      |
| ---------- | --------------------------------- | -------- | ------------------------------------ | --------------------------------------------- |
| YYYY-MM-DD | <Low / Medium / High / Critical>  | <name>   | <One line: what the contributor hit> | <PR / finding / issue link, or "—">           |

After each encounter, bump `Hits`, bump `Last reviewed`, and update `Priority` / `Status` if a threshold in [`README.md`](README.md) was crossed.

## References

- <ADR (portal or workspace) that accepted this debt, if any.>
- <Spec or module `AGENTS.md` where this debt lives.>
- <Finding(s) that surfaced or investigated this debt.>
- <Ticket(s) tracking the fix.>
- <Prior art or external articles describing the shape of the problem.>
