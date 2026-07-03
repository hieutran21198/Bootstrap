# AI orchestrator implements inline instead of delegating to specialized agents

> **Status**: Open
> **Priority**: Medium
> **Hits**: 1
> **Owner**: unassigned
> **Created**: 2026-07-01
> **Last reviewed**: 2026-07-01

## What

The orchestrator agent performs bulk implementation itself instead of routing it to specialized subagents, because no context-passing protocol between agents has been adopted.

## Why it exists

Drift, reinforced by three properties of the current agent runtime: subagents start with a **fresh context window**, their transcripts are **invisible to the user** (only the orchestrator sees them), and **sibling subagents cannot see each other**. Once the orchestrator has paid the discovery cost for a task (loaded a skill, read the conventions and neighbouring code), doing the work inline feels cheaper than writing a self-contained brief and re-paying that cost in a worker. No convention or AI-agent config codifies the alternative, so the path of least resistance wins. The workspace already externalizes context to disk (`AGENTS.md`, `docs/`, `skills/`), so the substrate for delegation exists — it is simply unused.

## Impact

- **Correctness**: single-agent implementation has no independent review gate; the writer grades its own homework, raising defect risk.
- **Maintainability**: the orchestrator's context window fills with full file bodies, cutting the headroom available for planning, routing, and review.
- **Developer experience**: specialized agents (`explore`, `worker`, `architecturer`, `researcher`) and their strengths go unused; no `writer ≠ reviewer` separation.
- **Performance**: work runs serially where independent, read-only steps could fan out in parallel, lowering throughput.

## Resolution

Codify the **externalize-then-delegate** protocol so agents follow it by default:

1. Durable context lives on disk (code, `docs/`, a scratch spec) — never only in the orchestrator's window or an agent transcript.
2. Delegate with a **thin brief + pointers** (goal, acceptance criteria, exact paths, the skill to load, 2–3 canonical files to mirror) rather than dumping context.
3. Orchestrator keeps only the index (plan, decisions log, who-did-what) and re-derives code on demand (e.g. via codegraph).
4. Use `task_id` to resume the same subagent for review iterations instead of re-briefing a fresh one.
5. Enforce `writer ≠ reviewer`: a fresh reviewer/`architecturer` checks the implementer's output.
6. Treat verification as a **proof gate** — agents return raw `go test` / `lint-go` output, which the orchestrator attaches to its summary (since transcripts are invisible to the user).
7. Fan out read-only discovery in parallel; serialize writes to shared files.

Land this as a workspace convention (`docs/conventions/`) and/or in the opencode agent config (`packages/nix/core/ai/opencode/`) plus the relevant `AGENTS.md`, so it is the default rather than a per-task decision. Until then, the inline path is tolerated only for small, single-file, convention-heavy tasks.

## Encounters

Append-only ledger. Add a row each time this debt causes real pain in real work. **Never edit historic rows** — a wrong row gets a new correction row below it. Heavy investigations live in [`../findings/`](../findings/); link from *Evidence*.

| Date       | Severity | Reporter | Symptom                                                                                      | Evidence |
| ---------- | -------- | -------- | ------------------------------------------------------------------------------------------- | -------- |
| 2026-07-01 | Medium   | user     | Orchestrator wrote the `errorsx` package inline rather than delegating; user flagged the missed delegation and the absence of a context-routing protocol. | —        |

After each encounter, bump `Hits`, bump `Last reviewed`, and update `Priority` / `Status` if a threshold in [`README.md`](README.md) was crossed.

## References

- `packages/go/errorsx/` — the package whose implementation triggered the first encounter.
- `.opencode/skills/go-pattern/SKILL.md` — the externalized knowledge layer a delegated worker would load.
- Root `AGENTS.md` (Tool usage policy) — already directs work to the Task tool / specialized agents; this debt is the gap between that policy and practice.
- `packages/nix/core/ai/opencode/` — where the agent-default behaviour would be configured.
