# tools/

## OVERVIEW
Workspace-wide tooling. Go module `bootstrap/tools`. Nix devenv modules have **moved** to `packages/nix/core/` -- look there for shell, linting, and git-hook configuration.

## STRUCTURE
```
tools/
├── ai/             # agent prompts / presets / evals (scaffold)
├── generators/
│   └── ws-tree/    # directory listing tool that injects .info metadata (Go binary)
├── scripts/        # dev helper scripts (scaffold)
├── validators/     # workspace / arch validators (scaffold)
└── go.mod          # bootstrap/tools
```

## WHERE TO LOOK
| Adding... | Goes in... |
|-----------|-----------|
| New CLI generator | `generators/<name>/` (package main; follow ws-tree pattern) |
| One-off dev shell helper | `scripts/<name>` |
| Workspace structure validator | `validators/<name>/` |
| Prompt / eval / agent helper | `ai/` |
| Nix devenv module (lint, hooks, Go toolchain) | Nix core modules under `packages/nix/` -- consult the sibling AGENTS guide |

## CONVENTIONS
- Generators: each is its own `package main` under `generators/<name>/`; compiled + injected into dev shell as a Nix package -- see `ws-tree` in `packages/nix/core/workspace/default.nix`
- External binary deps: inject via `wrapProgram ... --prefix PATH` in the Nix derivation, NOT via `exec.LookPath` discovery
- Args parsing: small switch over `os.Args[1:]` for tiny CLIs; no `flag`/`cobra` unless complex
- Env-var contracts for tool-to-script communication: JSON-in-env-var (e.g. `WORKSPACE_TREE_DESCRIPTIONS`), not many flags

## ANTI-PATTERNS
- Do not ship a generator that depends on an external binary without wrapping it via Nix
- Do not put a generator under `services/portal/` or `apps/`
- Do not put Nix module logic in tools/ -- it belongs in `packages/nix/core/`
- Do not add heavy frameworks to `tools/go.mod`; keep generators stdlib-leaning
