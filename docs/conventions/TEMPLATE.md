# <Rule name in title case>

> **Scope**: <which files / directories this rule applies to — be specific. e.g. "every `*.go` file under `packages/`, `services/`, `tools/`, `apps/`".>
> **Status**: Active
> **Decided by**: [ADR-NNNN](../../adrs/NNNN-<title>.md)
> **Last reviewed**: YYYY-MM-DD

**Rule.** <One-sentence imperative statement. The rule itself, nothing else. "Use X.", "Never Y.", "Prefer A over B.">

**Rationale.** <Why this rule exists. What failure modes it prevents. Be concrete; avoid handwaving.>

**Apply.**

- <Concrete guidance, step or principle 1.>
- <Concrete guidance, step or principle 2.>
- <... include enough that someone unfamiliar with the project knows how to comply.>

**Examples.**

✓ Good:

```<language>
// code that follows the rule
```

✗ Bad:

```<language>
// code that violates the rule
```

**Enforcement.** <Code review | Linter rule | Pre-commit hook | Manual>. If automated, name the tool and the specific rule. If human-only, say so explicitly.

## See also

- [<Topic> conventions index](README.md)
- [ADR-NNNN](../../adrs/NNNN-<title>.md) — the decision that established this rule.
- <Related convention or governance doc, e.g. `packages/go/AGENTS.md` for package-level governance that specializes this rule.>
- <External authority, e.g. Effective Go, language style guide, library best practice.>
