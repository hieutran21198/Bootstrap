# tools/

## OVERVIEW

Workspace-wide tooling. Dual nature: a Go module (`bootstrap/tools`) **and** the home of Nix devenv modules under `_nixenv/`. Most subdirs are scaffolds.

## STRUCTURE

```
tools/
├── _nixenv/        # numbered devenv modules           → see _nixenv/AGENTS.md
├── ai/             # agent prompts/presets/evals       (scaffold)
├── generators/     # code/doc generators (Go binaries)
│   └── better-tree/  # tree + .info description inliner
├── scripts/        # dev helper scripts                (scaffold)
├── validators/     # workspace/docs/arch validators    (scaffold)
└── go.mod          # bootstrap/tools
```

## WHERE TO LOOK

| Adding...                          | Goes in...                                                        |
| ---------------------------------- | ----------------------------------------------------------------- |
| Nix devenv module                  | [`_nixenv/`](_nixenv/) (read its AGENTS.md first)                 |
| New CLI generator                  | `generators/<name>/` (package `main`, follow better-tree pattern) |
| One-off dev shell helper           | `scripts/<name>`                                                  |
| Workspace structure validator      | `validators/<name>/`                                              |
| Prompt / eval / agent helper       | `ai/`                                                             |

## CONVENTIONS

- **Go generators**: each is its own `package main` under `generators/<name>/`. Compiled and wrapped into the dev shell as a Nix package — see how `better-tree` is built in [`_nixenv/001-workspace/devenv.nix`](_nixenv/001-workspace/devenv.nix).
- **External binary dependencies** (e.g. `tree` for `better-tree`): inject via `wrapProgram ... --prefix PATH` in the Nix derivation, not via `exec.LookPath` discovery from the user's `$PATH`.
- **Args parsing**: better-tree uses a small switch over `os.Args[1:]` — no `flag`/`cobra` for tiny CLIs. Match that style for similar-sized tools.
- **Env-var contract for tools**: prefer typed input via JSON-in-env-var (e.g. `WORKSPACE_TREE_DESCRIPTIONS`) over many flags, when the caller is another devenv script.

## ANTI-PATTERNS

- **Do not** ship a generator that depends on an external binary without wrapping it via Nix. The whole point is reproducibility.
- **Do not** add a generator to `services/portal` or `apps/`. Workspace-meta tools live here.
- **Do not** put Nix module logic outside `_nixenv/` — they would not be picked up by `devenv.yaml` imports.
- **Do not** add Go dependencies to `tools/go.mod` that drag in heavy frameworks; keep generators stdlib-leaning.
