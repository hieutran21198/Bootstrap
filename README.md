# Bootstrap

A greenfield Go monorepo scaffold managed by [Nix](https://nixos.org/) + [devenv](https://devenv.sh/). Three Go modules bound via [`go.work`](go.work); toolchain, shell environment, linters, and pre-commit hooks all defined as code in [`tools/_nixenv/`](tools/_nixenv/).

> **Scaffold-stage.** Most product folders are `.gitkeep` placeholders — the value is in the conventions enforced by tooling, not in the code yet. Treat empty directories as placement contracts.

## Quick start

Prerequisites: [Nix](https://nixos.org/download) with flakes enabled, [direnv](https://direnv.net/), [devenv](https://devenv.sh/).

```bash
git clone <repo> bootstrap
cd bootstrap
direnv allow            # one-time consent; auto-enters the dev shell on every cd
ws-info                 # workspace overview (auto-runs on shell entry)
```

Provisions: Go 1.26.3, delve, gopls, golangci-lint v2.12.2, commitizen, secret scanners (`ripsecrets`, `trufflehog`, `detect-aws-credentials`, `detect-private-keys`). No `Makefile`, no `setup.sh` — devenv scripts are the runner.

## Layout

```
bootstrap/
├── apps/               # platform-specific apps           (scaffold)
├── deploy/             # infra defs                       (scaffold)
├── docs/               # ADRs / specs / conventions / glossary
├── packages/go/        # shared Go module
├── services/portal/    # Clean Arch + CQRS service        (scaffold)
├── tools/              # workspace tooling Go module + Nix env
│   ├── _nixenv/        # numbered devenv modules
│   └── generators/     # workspace CLI tools
├── devenv.nix          # workspace name + mandatoryFolders
├── devenv.yaml         # imports tools/_nixenv/{001,002,003}
└── go.work             # binds packages/go, services/portal, tools
```

Every populated subtree has its own `AGENTS.md` — terse knowledge base for humans and AI agents:

| Path                                                     | Covers                                                  |
| -------------------------------------------------------- | ------------------------------------------------------- |
| [AGENTS.md](AGENTS.md)                                   | Canonical project knowledge base — start here for depth |
| [docs/AGENTS.md](docs/AGENTS.md)                         | ADRs, specs, conventions, glossary                      |
| [packages/go/AGENTS.md](packages/go/AGENTS.md)           | Shared Go library governance                            |
| [services/portal/AGENTS.md](services/portal/AGENTS.md)   | Clean Architecture + CQRS module layout                   |
| [tools/AGENTS.md](tools/AGENTS.md)                       | Generators, validators, scripts                         |
| [tools/_nixenv/AGENTS.md](tools/_nixenv/AGENTS.md)       | Nix devenv module conventions                           |

## Shell commands

Available after entering the shell (i.e. any `cd` into the repo with direnv enabled):

| Command       | What                                                                     |
| ------------- | ------------------------------------------------------------------------ |
| `ws-info`     | Workspace overview                                                       |
| `better-tree` | `tree` + inline descriptions from `.info`                                |
| `go-info`     | Go toolchain `version` + `env`                                           |
| `lint-go`     | `golangci-lint` across every `go.work` module (pass `--fix` to auto-fix) |
| `devenv up`   | Spin up workspace services (when defined)                                |

## Conventions

- **Whitespace**: [.editorconfig](.editorconfig) — Go uses tabs; everything else 2 spaces; Markdown preserves trailing spaces.
- **Go module path**: `bootstrap/<segment>/<module>`. No domain prefix; the workspace name *is* the prefix.
- **Go version**: `1.26.3` across all `go.mod` + `go.work`. Match when adding modules.
- **New folders**: Add a key to `workspace.mandatoryFolders` in [devenv.nix](devenv.nix) — devenv seeds `.gitkeep` + a row in `.info` automatically. Do not create scaffold dirs manually.
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/) via commitizen pre-commit hook.
- **ADRs**: append-only, `NNNN-kebab-case-title.md`. See [docs/adrs/TEMPLATE.md](docs/adrs/TEMPLATE.md).
- **Local-only (gitignored)**: `.opencode/`, `.claude/`, `.codex/`, `.omo/` — per-developer agent config.
- **File size cap**: 1 MB (`check-added-large-files --maxkb=1024`).

### Generated files — do not hand-edit

| File                      | Source                                                                                                |
| ------------------------- | ----------------------------------------------------------------------------------------------------- |
| `.pre-commit-config.yaml` | [tools/_nixenv/002-git-hooks/devenv.nix](tools/_nixenv/002-git-hooks/devenv.nix)                       |
| `.golangci.yml`           | [tools/_nixenv/003-go-toolchain/golangci-lint/default.nix](tools/_nixenv/003-go-toolchain/golangci-lint/default.nix) |
| `go.work`                 | [tools/_nixenv/003-go-toolchain/devenv.nix](tools/_nixenv/003-go-toolchain/devenv.nix) → `go-toolchain.go-work.mods` |
| `.info`                   | [devenv.nix](devenv.nix) → `workspace.mandatoryFolders`                                                |
| `.editorconfig`           | [tools/_nixenv/001-workspace/devenv.nix](tools/_nixenv/001-workspace/devenv.nix)                       |

Edit the Nix source, re-enter the shell (`direnv reload`), and the artifact regenerates.

## Linting

`golangci-lint` v2.12.2 is configured entirely in Nix:

- **Source of truth**: [tools/_nixenv/003-go-toolchain/golangci-lint/default.nix](tools/_nixenv/003-go-toolchain/golangci-lint/default.nix)
- **Artifact**: `.golangci.yml` at the repo root is a **read-only symlink** into the Nix store, regenerated on every shell entry. It is gitignored.
- **Set**: standard linters (`errcheck`, `govet`, `ineffassign`, `staticcheck`, `unused`) plus `bodyclose`, `errorlint`, `gocritic`, **`gocyclo`**, `gosec`, `misspell`, `nakedret`, `nilerr`, `nolintlint`, `prealloc`, `revive`, `unconvert`, `unparam`, `usestdlibvars`.
- **govet shadow analyzer** enabled. **`gocyclo` threshold**: 15.
- **Formatters**: `gofumpt` + `goimports` (`-local bootstrap/`).

To change lint rules:

```bash
$EDITOR tools/_nixenv/003-go-toolchain/golangci-lint/default.nix
direnv reload                      # regenerate the .golangci.yml symlink
lint-go                            # verify clean across all modules
```

## Further reading

- [AGENTS.md](AGENTS.md) — full project knowledge base (this README is the 30-second tour; AGENTS.md is the full map)
- [docs/adrs/](docs/adrs/) — Architecture Decision Records
- [tools/_nixenv/AGENTS.md](tools/_nixenv/AGENTS.md) — how to add a new Nix devenv module
