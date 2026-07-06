# 0023. Hard-scope agent edit permissions by owned resource

- **Status**: Proposed
- **Date**: 2026-07-06
- **Deciders**: workspace maintainer
- **Supersedes**: ADR-0019 prompt-bounded edit premise (partial, upon acceptance)
- **Superseded by**: -

## Context

The workspace now has ten opencode agents whose lanes span orchestration,
research, design, implementation, delivery records, release, security review, and
developer-environment maintenance. Earlier agent decisions relied on scalar
`permission.edit = "allow" | "deny"` and prompt prose to keep writable agents in
their lane. ADR-0019 explicitly accepted that shape for Dev-Environment: broad
`edit = "allow"`, bounded by the prompt rather than by the runtime permission
model.

That premise is no longer acceptable as the standing posture model. Research has
confirmed that opencode `permission.edit`, as documented for opencode v1.1.1,
accepts either a scalar action or a map of path glob patterns to actions. The map
is evaluated against normalized forward-slash paths, `*` crosses `/`, and the
last matching rule wins; default is `ask`, so an explicit `"*" = "deny"` rule is
required for a deny-by-default map. There is no `permission.write` key: write,
edit, and apply-patch operations route through `permission.edit`.

The workspace must therefore move from prompt-bounded write posture to
hard-scoped write posture: every writing agent receives an `edit` map that allows
only its owned resources, and the prompt repeats that boundary as defense in
depth. The pinned opencode version in the developer environment must be confirmed
to support this v1.1.1 permission shape before rollout.

This decision reconciles the agent posture with:

- ADR-0017: Scribe owns the delivery record and tracker evidence by default.
- ADR-0019: Dev-Environment owns local-dev and Nix/tooling, but its write access
  must be hard-scoped instead of prompt-only.
- ADR-0021: `.sdlc/<task-slug>/` is scratch, not a third source of truth; durable
  records are born in `docs/` and promoted by the owning track agent.
- `docs/wiki/implementation-workflow.md`: PRDs are drafted by Scribe with
  Researcher input; specs/ADRs by Architect; implementation by Engineers; release
  mechanics by Release-Engineer; learning capture by Scribe with Architect
  escalation when a decision/design change is needed.

## Decision

We will render every writing agent with a deny-by-default, path-scoped
`permission.edit` map over its owned resources, explicitly deny peer delegation
(`task`) for all subagents, and reserve web access for the Orchestrator and
Researcher lanes. The Orchestrator may write only task-local `.sdlc/` index and
coordination artifacts; the Security Reviewer remains hard non-writing to
preserve audit independence.

### Built-in tool posture matrix

The following values are the target `permission` entries for the five built-in
tools this policy governs. Capability-derived MCP and skill permissions are still
merged separately by the renderer.

| Agent | `edit` | `bash` | `task` | `webfetch` | `websearch` |
|---|---|---:|---:|---:|---:|
| `orchestrator` | `{ "*": "deny", ".sdlc/*/README.md": "allow", ".sdlc/*/coordination/*": "allow" }` | `deny` | `allow` | `allow` | `allow` |
| `researcher` | `{ "*": "deny", ".sdlc/*/research/*": "allow", ".sdlc/*/learnings/*": "allow", "docs/findings/*": "allow" }` | `deny` | `deny` | `allow` | `allow` |
| `explorer` | `{ "*": "deny", ".sdlc/*/research/*": "allow", ".sdlc/*/learnings/*": "allow" }` | `deny` | `deny` | `deny` | `deny` |
| `architect` | `{ "*": "deny", ".sdlc/*/learnings/*": "allow", "docs/adrs/*": "allow", "docs/conventions/*": "allow", "docs/specs/*": "allow", "docs/wiki/architecture/*": "allow" }` | `deny` | `deny` | `deny` | `deny` |
| `backend-engineer` | `{ "*": "deny", ".sdlc/*/evidence/*": "allow", ".sdlc/*/learnings/*": "allow", "packages/go/*": "allow", "services/portal/*": "allow", "tools/generators/*": "allow", "tools/validators/*": "allow" }` | `allow` | `deny` | `deny` | `deny` |
| `frontend-engineer` | `{ "*": "deny", ".sdlc/*/evidence/*": "allow", ".sdlc/*/learnings/*": "allow", "apps/*": "allow" }` | `allow` | `deny` | `deny` | `deny` |
| `scribe` | `{ "*": "deny", ".sdlc/*/evidence/*": "allow", ".sdlc/*/learnings/*": "allow", "docs/debt/*": "allow", "docs/findings/*": "allow", "docs/glossary/*": "allow", "docs/prds/*": "allow", "docs/wiki/*": "allow", "docs/wiki/architecture/*": "deny" }` | `deny` | `deny` | `deny` | `deny` |
| `release-engineer` | `{ "*": "deny", ".github/workflows/*": "allow", ".sdlc/*/evidence/*": "allow", ".sdlc/*/learnings/*": "allow", "CHANGELOG.md": "allow", "deploy/*": "allow", "packages/nix/core/git/*": "allow", "tools/scripts/*": "allow" }` | `allow` | `deny` | `deny` | `deny` |
| `security-reviewer` | `deny` | `deny` | `deny` | `deny` | `deny` |
| `dev-environment` | `{ "*": "deny", ".sdlc/*/evidence/*": "allow", ".sdlc/*/learnings/*": "allow", "packages/nix/*": "allow", "tools/ai/*": "allow" }` | `allow` | `deny` | `deny` | `deny` |

Notes:

- The Scribe map intentionally adds `"docs/wiki/architecture/*" = "deny"` after
  the broader wiki allow because architecture views belong to Architect.
- `task = "deny"` on subagents mechanically preserves hub-and-spoke
  orchestration from ADR-0021; subagents report needs back to the Orchestrator
  instead of delegating to siblings.
- `webfetch` and `websearch` stay on the Orchestrator and Researcher only. Other
  agents route external/library questions to Researcher.

### Resolved posture and ownership calls

- **Orchestrator `.sdlc/` write**: grant a narrow `edit` map for
  `.sdlc/*/README.md` and `.sdlc/*/coordination/*`, while denying code and
  `docs/`. This preserves the “never implement inline” guarantee mechanically
  because code and durable docs remain denied, but lets the coordination hub own
  the task index and coordination notes that ADR-0021 introduced.
- **Security Reviewer `.sdlc/` verdict write**: keep hard `edit = "deny"`.
  The review verdict is returned in the Completion Report and captured by the
  handoff audit log. Keeping the reviewer non-writing preserves ADR-0014's audit
  independence and prevents a security gate from mutating the artifacts it
  audits.
- **`docs/glossary/` owner**: Scribe owns glossary maintenance because glossary
  entries are durable planning/domain-language records that feed PRDs. Architect
  is consulted, and an ADR is required, when a definition has structural
  consequences.
- **`.sdlc/<task-slug>/README.md` and `coordination/` owner**: Orchestrator owns
  both. The task index and coordination notes are operational routing artifacts,
  not durable `docs/` records and not implementation outputs.

### Resource-ownership map

`docs/` ownership:

| Resource | Owning agent | Notes |
|---|---|---|
| `docs/prds/` | Scribe | Researcher supplies domain input; human accepts PRDs. |
| `docs/adrs/` | Architect | Human accepts ADR status changes. |
| `docs/specs/` | Architect | Feature design track; link via `Tracks`. |
| `docs/conventions/` | Architect | Material convention changes require a new ADR. |
| `docs/glossary/` | Scribe | Architect consulted for structurally significant terms. |
| `docs/findings/` | Researcher and Scribe | Researcher authors investigation findings; Scribe records delivery-stage learnings and evidence. |
| `docs/debt/` | Scribe | Register plus append-only encounter ledger. |
| `docs/wiki/` | Scribe | Informal living notes, except architecture. |
| `docs/wiki/architecture/` | Architect | System-wide architecture views per ADR-0020. |
| `docs/architecture/` | Architect | Retired compatibility stubs only; do not revive the track. |

`.sdlc/<task-slug>/` ownership:

| Resource | Owning agent | Notes |
|---|---|---|
| `README.md` | Orchestrator | Optional task index, owner, docs/ refs, Linear refs, cleanup checklist. |
| `research/` | Researcher and Explorer | Researcher writes external/domain notes; Explorer writes repo maps/traces. |
| `coordination/` | Orchestrator | Multi-agent routing and coordination scratch; not durable truth. |
| `handoffs/` | Handoff audit plugin | Agents never hand-edit captured Delegation Briefs or Completion Reports. |
| `evidence/` | Agent that produced the evidence; Scribe promotes | Raw verification/log bundles before Linear attach or docs promotion. |
| `learnings/` | Any writing agent may propose; Scribe triages | Candidates are re-authored into findings/debt/wiki or discarded at close. |

### Implementation requirements for Dev-Environment

Dev-Environment implements this ADR after human sign-off; this ADR does not edit
the Nix agent modules or renderer directly.

1. **Renderer type widening**: `packages/nix/core/ai/default.nix` must widen
   `core.ai.agents.<name>.posture` from `utils.makeAttrsOption { ofType =
   lib.types.str; }` to a value type that accepts either a string action or a
   map of string pattern to string action, for example
   `lib.types.either lib.types.str (lib.types.attrsOf lib.types.str)`. The
   rendered `permission` frontmatter must preserve map-valued permissions.
2. **No `permission.write`**: do not introduce a `write` permission key; it is a
   no-op in opencode. All write/apply-patch control belongs under `edit`.
3. **PRD authoring skill**: `packages/nix/core/ai/skills/prd-authoring/default.nix`
   must allow the PRD author, `scribe`, not `orchestrator`. If a branch still has
   `agents = [ "orchestrator" ];`, move it to `agents = [ "scribe" ];`; if it
   already has `scribe`, keep it there and ensure `orchestrator` is not listed.
4. **Prompt reinforcement**: add the scope paragraphs below to each affected
   `PROMPT.md`. The hard `edit` maps are the enforcement boundary; prompt text is
   defense in depth.

#### Description strings to use where identity wording changes

- `orchestrator`: `The Orchestrator plans the session, routes each slice of work to the right subagent via a Delegation Brief, keeps the plan and decision index, owns only task-local .sdlc task index/coordination notes, and enforces writer != reviewer. It does not implement inline or edit code/docs.`
- `researcher`: `The Researcher agent gathers external, library, and domain knowledge, evaluates options and trade-offs, and synthesizes sourced findings into clear recommendations. It may write only sourced research/finding artifacts in its allowed .sdlc research paths and docs/findings/; it never changes code.`
- `explorer`: `The Explorer agent maps this codebase: it locates files and symbols, traces call paths and data flow, and answers 'where/how does X work' within the repo. It may write only repo maps/traces in its allowed .sdlc research paths; it never edits code or durable docs.`
- `scribe`: `The Scribe agent owns the durable planning and delivery record: it drafts PRDs, maintains glossary, findings/debt/wiki records, files and reconciles tracked work items, syncs evidence, and writes status reports. It records and maintains artifacts; it never coordinates other agents or makes design decisions.`
- `security-reviewer`: `The Security Reviewer agent independently audits DB-touching changes for RLS policy correctness, tenant/system scoping, role/GUC contracts, and SystemReadCapability usage. It is non-writing and returns verdicts only.`
- `dev-environment`: `The Dev-Environment agent owns the local-dev and workspace-tooling lane: worktree lifecycle, devenv/Nix module toggles, direnv and shell ergonomics, local .env/secret bootstrap, codegraph init guidance, ws-info/ws-tree usage, AI/dev-environment wiring under packages/nix/ and tools/ai/, and .sdlc cleanup.`

#### PROMPT.md scope paragraphs to add

`orchestrator`:

```markdown
## Write scope

Your only writeable resources are task-local coordination artifacts: `.sdlc/<task-slug>/README.md` and files under `.sdlc/<task-slug>/coordination/`. Use them for the task index, routing notes, docs/ and Linear refs, and cleanup checklist. Do not edit code, durable `docs/` records, handoff captures, evidence, research notes, or learning candidates; delegate those to the owning agent.
```

`researcher`:

```markdown
## Write scope

You may write sourced research notes under `.sdlc/<task-slug>/research/`, learning candidates under `.sdlc/<task-slug>/learnings/`, and investigation findings under `docs/findings/` when the brief asks for a durable finding. Do not edit code, PRDs, ADRs, specs, glossary terms, debt records, wiki pages, or coordination artifacts.
```

`explorer`:

```markdown
## Write scope

You may write repo maps, traces, and exploration notes under `.sdlc/<task-slug>/research/`, plus learning candidates under `.sdlc/<task-slug>/learnings/`. Do not edit code, durable `docs/` records, coordination artifacts, evidence bundles, or generated files.
```

`architect`:

```markdown
## Write scope

You may edit only `docs/adrs/`, `docs/specs/`, `docs/conventions/`, `docs/wiki/architecture/`, and learning candidates under `.sdlc/<task-slug>/learnings/`. Do not edit code, PRDs, glossary entries, findings/debt records, non-architecture wiki pages, release/devenv wiring, or generated files.
```

`backend-engineer`:

```markdown
## Write scope

You may edit Go/backend resources under `packages/go/`, `services/portal/`, `tools/generators/`, and `tools/validators/`, and may stage raw verification or learning candidates under `.sdlc/<task-slug>/evidence/` and `.sdlc/<task-slug>/learnings/`. Do not edit `apps/`, ADRs/specs/conventions, release/devenv wiring, `tools/scripts/`, or generated files.
```

`frontend-engineer`:

```markdown
## Write scope

You may edit UI/app resources under `apps/`, and may stage raw verification or learning candidates under `.sdlc/<task-slug>/evidence/` and `.sdlc/<task-slug>/learnings/`. Do not edit Go backend/domain code, ADRs/specs/conventions, release/devenv wiring, or generated files.
```

`scribe`:

```markdown
## Write scope

You may edit `docs/prds/`, `docs/glossary/`, `docs/findings/`, `docs/debt/`, non-architecture `docs/wiki/` pages, and `.sdlc/<task-slug>/evidence/` / `.sdlc/<task-slug>/learnings/` during evidence and learning triage. Do not edit ADRs, specs, conventions, `docs/wiki/architecture/`, code, release/devenv wiring, coordination artifacts, or generated files.
```

`release-engineer`:

```markdown
## Write scope

You may edit release resources under `.github/workflows/`, `deploy/`, `packages/nix/core/git/`, `tools/scripts/`, `CHANGELOG.md`, and may stage release verification or learning candidates under `.sdlc/<task-slug>/evidence/` and `.sdlc/<task-slug>/learnings/`. Do not edit application Go/domain code, UI code, ADRs/specs/conventions, `tools/validators/git-guard` implementation, or generated files.
```

`security-reviewer`:

```markdown
## Write scope

You are non-writing by design: do not edit code, docs, `.sdlc/`, migrations, configs, generated files, or evidence bundles. Return the verdict in your Completion Report; the handoff audit log captures it, and the Orchestrator routes any durable finding to Scribe.
```

`dev-environment`:

```markdown
## Write scope

You may edit developer-environment resources under `packages/nix/` and AI/dev-environment wiring under `tools/ai/`, and may stage local verification or learning candidates under `.sdlc/<task-slug>/evidence/` and `.sdlc/<task-slug>/learnings/`. Do not edit application/domain code, `tools/generators/` or `tools/validators/` Go implementations, CI/release/deploy resources, ADRs/specs, or generated files. `.sdlc/<task-slug>/` cleanup is performed by shell only after the Orchestrator confirms durable content has been routed.
```

## Consequences

- **Positive**:
  - Prompt-only ownership becomes runtime-enforced least privilege for writes.
  - The Orchestrator can maintain the task-local index without gaining code or
    durable-doc write access.
  - The Security Reviewer remains an independent non-mutating audit gate.
  - PRD, glossary, `.sdlc/README.md`, and `.sdlc/coordination/` ownership is no
    longer ambiguous.
  - Subagents cannot peer-delegate through `task`; the Orchestrator remains the
    hub for artifact-mediated communication.
- **Negative**:
  - The renderer must support heterogeneous posture values, and generated
    frontmatter must be verified against the pinned opencode version.
  - Path globs are intentionally simple and `*` crosses `/`; broad directories
    such as `docs/wiki/*` need explicit deny exceptions when a sub-tree belongs
    to another agent.
  - Some legitimate cross-lane edits will now fail mechanically and require a new
    delegation to the owner instead of opportunistic inline edits.
- **Neutral**:
  - Skill and MCP allow-lists remain capability-owned and are still merged by the
    renderer after posture.
  - `.sdlc/` remains gitignored scratch, not a durable documentation track.
  - This ADR does not grant product, DoD, priority, or release authority to any
    agent; human gates from the implementation workflow remain unchanged.

## Alternatives considered

- **Keep scalar `edit` with prompt-bounded lanes.** Rejected because opencode now
  has a hard path-scoping mechanism; continuing to rely on prompt prose would
  preserve the ADR-0019 downgrade where `edit = "allow"` can touch anything.
- **Keep Orchestrator at hard `edit = "deny"`.** Rejected because the task index
  and coordination folder are the Orchestrator's natural scratch resources, and a
  narrow `.sdlc/` map preserves the no-code/no-doc implementation guarantee.
- **Allow Security Reviewer to write `.sdlc/` verdict artifacts.** Rejected
  because the handoff audit log already captures review reports, while hard
  non-writing posture preserves audit independence from ADR-0014.
- **Give glossary ownership to Architect.** Rejected because glossary maintenance
  is primarily domain/planning record work adjacent to PRDs. Architect remains the
  escalation path for structurally consequential definitions.
- **Leave subagent `task` unset.** Rejected because opencode defaults can still
  ask for permission; explicit `deny` better enforces ADR-0021 hub-and-spoke
  routing.

## References

- [ADR-0014: Add a Security Reviewer agent](0014-security-reviewer-agent.md)
- [ADR-0017: Evidence-based delivery](0017-evidence-based-delivery.md)
- [ADR-0019: Add a Dev-Environment agent](0019-dev-environment-agent.md)
- [ADR-0021: Artifact-mediated agent communication and the `.sdlc/` scratch workspace](0021-artifact-mediated-agent-communication-and-sdlc-scratch-workspace.md)
- [Implementation workflow](../wiki/implementation-workflow.md)
- [Artifact-mediated communication convention](../conventions/agents/artifact-mediated-communication.md)
- [`packages/nix/core/ai/default.nix`](../../packages/nix/core/ai/default.nix)
- [`packages/nix/core/ai/skills/prd-authoring/default.nix`](../../packages/nix/core/ai/skills/prd-authoring/default.nix)
- opencode permissions documentation: <https://opencode.ai/docs/permissions>
- opencode agent permissions documentation: <https://opencode.ai/docs/agents#permissions>
- opencode source: `anomalyco/opencode packages/core/src/v1/config/permission.ts`
