# PRD authoring and PRD template best practices

> **Status**: Resolved
> **Authors**: architect (agent session, PRD skill research)
> **Investigated**: 2026-07-06
> **Tracks**: docs/prds/TEMPLATE.md, docs/wiki/prd-authoring.md, packages/nix/core/ai/skills/prd-authoring/SKILL.md

## Symptom

The workspace needed to answer: what requirements-engineering and spec-driven
development practices should shape the PRD-authoring skill and the formal
`docs/prds/TEMPLATE.md`, without weakening this repo's existing rule that PRDs
remain requirements-only and solution-free?

## Reproduction

```text
Research task: independently review PRD / requirements-authoring practices,
EARS notation, requirements quality standards, spec-driven-development tools,
real public requirements artifacts, and AI skill authoring patterns; synthesize
findings into .sdlc/prd-skill-research/research-report.md; promote the durable
evidence into docs/findings/ and apply the parts that fit the existing PRD
track convention.
```

## Hypotheses considered

- **H1: EARS should replace the whole PRD structure.** Disproved — EARS is best
  used for observable system behaviours and acceptance criteria. The PRD still
  needs problem, personas, scope, domain intent, open questions, and downstream
  traceability in the existing workspace section order.
- **H2: BDD / Given-When-Then should be preferred over EARS.** Rejected for this
  template — BDD is useful for scenario tests, but EARS maps more directly to
  concise requirement statements and the workspace already names EARS as the PRD
  convention.
- **H3: A full PRD template should add mandatory sections for success criteria,
  assumptions, constraints, risks, and downstream handoff.** Partially confirmed
  as best practice, but not applied structurally because adding mandatory
  sections would change the PRD track contract in `docs/AGENTS.md` and
  `docs/prds/README.md`.
- **H4: One-page PRDs are enough and the formal template can be shortened.**
  Rejected — right-sizing is useful for an authoring skill, but the repo's
  formal PRD track needs a stable, traceable, repeatable section set.
- **H5: The existing PRD convention can be improved without changing its
  structure.** Confirmed — stronger EARS guidance, stable IDs, clarification
  discipline, implementation-leakage checks, measurable wording, and a review
  checklist all fit inside the existing template and README.

## Investigation

The investigation combined the internal synthesis report with supporting source
notes:

- Full evidence report preserved verbatim in
  [`2026-07-06-prd-authoring-and-prd-template-best-practices.assets/research-report.md`](2026-07-06-prd-authoring-and-prd-template-best-practices.assets/research-report.md).
- Supporting enrichment notes:
  `.sdlc/prd-skill-research/track-a-web-enrichment.md`.
- Existing repo authorities checked before applying changes:
  `docs/AGENTS.md`, `docs/prds/TEMPLATE.md`, `docs/prds/README.md`,
  `docs/findings/TEMPLATE.md`, `docs/findings/README.md`, and
  `docs/wiki/README.md`.

The report synthesized EARS, ISO/IEC/IEEE 29148 requirement-quality
characteristics, GitHub spec-kit, Amazon Kiro, OpenSpec, product-discovery
literature, traceability practice, and real public requirements / skill files.

## Root cause

The key finding is that high-quality PRD authoring depends on a strict tier
boundary: the PRD is the what/why source of truth, while ADRs and specs carry
the downstream how. Within that boundary, requirements need stable IDs,
testable and observable wording, EARS-shaped acceptance where appropriate,
explicit scope boundaries, budgeted clarification, and a checklist that catches
implementation leakage before a draft is accepted.

## Resolution

- Companion PRD-authoring skill update:
  [`packages/nix/core/ai/skills/prd-authoring/SKILL.md`](../../packages/nix/core/ai/skills/prd-authoring/SKILL.md)
  — uses the research to guide agent drafting, clarification, and validation.
- Enhanced formal PRD template:
  [`docs/prds/TEMPLATE.md`](../prds/TEMPLATE.md) — keeps the canonical PRD
  front matter, section set, section order, and `Draft → Accepted` gate while
  adding stronger EARS pattern guidance, stable requirement IDs, clarification
  caps with recommended defaults, measurable / technology-agnostic wording,
  implementation-leakage checks, and an embedded review checklist.
- Updated PRD track README:
  [`docs/prds/README.md`](../prds/README.md) — keeps the existing lifecycle and
  section policy accurate after the within-structure template enhancements.
- Added informal stakeholder-facing wiki guidance:
  [`docs/wiki/prd-authoring.md`](../wiki/prd-authoring.md) — records the PRD
  principles and a plain-language intake form that feeds formal PRD authoring.
- Added this finding and its evidence asset so future authors can see the
  source research instead of rediscovering the same practices.

## References

- [Full research report evidence](2026-07-06-prd-authoring-and-prd-template-best-practices.assets/research-report.md)
- EARS — Alistair Mavin: https://alistairmavin.com/ears/
- EARS — Wikipedia / RE'09 provenance: https://en.wikipedia.org/wiki/Easy_Approach_to_Requirements_Syntax
- GitHub spec-kit: https://github.com/github/spec-kit
- spec-kit spec template: https://raw.githubusercontent.com/github/spec-kit/main/templates/spec-template.md
- spec-kit specify command: https://raw.githubusercontent.com/github/spec-kit/main/templates/commands/specify.md
- Snowflake-Labs coco-skills EARS notation: https://raw.githubusercontent.com/Snowflake-Labs/coco-skills/main/skills/spec-driven/references/EARS_NOTATION.md
- Snowflake-Labs coco-skills spec-driven skill: https://raw.githubusercontent.com/Snowflake-Labs/coco-skills/main/skills/spec-driven/SKILL.md
- Amazon Kiro specs: https://kiro.dev/docs/specs
- Amazon Kiro property-based testing: https://kiro.dev/blog/property-based-testing
- OpenSpec: https://github.com/Fission-AI/OpenSpec
- Product manager toolkit example: https://raw.githubusercontent.com/majiayu000/spellbook/main/skills/product-manager-toolkit/SKILL.md
- ISO/IEC/IEEE 29148:2018 (requirements-engineering standard; summarized in the evidence report)
- Jama requirements management and traceability guide: https://www.jamasoftware.com/requirements-management-guide/
- Michael Nygard ADR pattern / Thoughtworks ADR writeups: https://www.thoughtworks.com/radar/techniques/lightweight-architecture-decision-records
- Agent Skills specification: https://agentskills.io/specification
- Kiro skills docs: https://kiro.dev/docs/skills
- Avo requirements brainstorm example: https://raw.githubusercontent.com/avo-hq/avo/main/docs/brainstorms/2026-06-08-on-demand-frame-loading-requirements.md
- Rune-kit requirements fixture: https://raw.githubusercontent.com/Rune-kit/rune/master/evals/converge/clean-pass/fixture/.rune/features/feedback-board/requirements.md
