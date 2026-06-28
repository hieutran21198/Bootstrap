# 0007. Manage the developer environment with Nix + devenv

- **Status**: Accepted
- **Date**: 2026-06-28
- **Deciders**: Minh Hieu Tran <hieu.tran21198@gmail.com>
- **Supersedes**: -
- **Superseded by**: -

## Context

This is a polyglot monorepo: three Go modules bound by `go.work`, a Docusaurus (Node) docs app under `apps/`, Postgres for the portal service, AWS tooling, a `prek` pre-commit pipeline, and a set of generated configuration files (`go.work`, `.golangci.yml`, `.editorconfig`, `.info`, `.claude/*`, `.opencode/*`). The toolchain must be reproducible across machines and pinned to exact versions (Go `1.26.3`, `golangci-lint v2.12.2`, Node, etc.), or "works on my machine" drift becomes the default failure mode.

We needed a single answer to four coupled questions:

1. **How is the toolchain provisioned?** Contributors should not hand-install Go, Node, linters, AWS CLI, secret scanners, and Postgres at the right versions.
2. **How is per-project environment scoped?** The root, each shared package, and each service (`services/portal`, `apps/workspace-docs`) need their own shell — different languages, services, and secrets — without a monolithic global config.
3. **How are project conventions enforced as code?** Lint rules, editor settings, pre-commit hooks, and folder descriptions should be defined once, version-controlled, and regenerated deterministically — never hand-maintained.
4. **How do contributors enter the environment?** Entry should be automatic and uniform, with no `Makefile` / `setup.sh` / `bootstrap.sh` to drift out of sync with reality.

The constraint shaping the options: the workspace already commits to "the value is in the conventions enforced by tooling, not in code volume." Whatever we pick has to make tooling the source of truth, with generated artifacts that are reproducible from declarative source.

## Decision

We will manage the entire developer environment with **[Nix](https://nixos.org/) + [devenv](https://devenv.sh/)**, with [direnv](https://direnv.net/) for automatic shell entry.

1. **Nix flakes via devenv provide every tool**, version-pinned through `devenv.yaml` inputs (`nixpkgs` rolling, `go-overlay`, `git-hooks`). No tool is installed by hand.
2. **Each subtree is its own devenv.** The root, and each service/app (`services/portal/`, `apps/workspace-docs/`), carries its own `devenv.nix` + `devenv.yaml`, importing the shared module tree via `imports: [ <path>/packages/nix ]`. A subtree enables only what it needs (portal enables `core.services.postgres`; workspace-docs enables `languages.javascript`).
3. **Reusable Nix modules live under [`packages/nix/`](../../packages/nix/)**, split into `core/` (mandatory, imported by `core/default.nix`) and `extra/` (opt-in, not imported by default — currently `dev-container`). Every module gates on its own `enable` flag set in the consuming `devenv.nix`, and builds options through the shared `core.utils.make*` helpers for uniform option shapes.
4. **Generated config is owned by Nix, never hand-edited.** `core.workspace.treeInfos` generates `.info`; `core.toolchains.go.go-work.mods` generates `go.work`; the golangci-lint module generates `.golangci.yml`; the workspace module generates `.editorconfig`; the AI modules generate `.claude/*` + `.opencode/*`. All are gitignored Nix-store symlinks, regenerated on `direnv reload`.
5. **`direnv allow` is the only entry step.** Shell entry is automatic on every `cd` and auto-runs `ws-info`. devenv `scripts` (`ws-info`, `ws-tree`, `lint-go`, `go-info`, `migrate-*`, `docs-*`) are the only runners — there is no `Makefile`, `setup.sh`, or `bootstrap.sh`.

## Consequences

- **Positive**:
  - Reproducible, version-pinned toolchain across every contributor and CI — Go `1.26.3` + `golangci-lint v2.12.2` + Node are guaranteed identical, eliminating version drift.
  - Conventions are enforced as code: lint rules, editor config, pre-commit hooks, and folder descriptions are declared once in Nix and regenerated deterministically, so they cannot rot the way hand-maintained config does.
  - Per-subtree devenv keeps each service/app's environment minimal and explicit; adding `apps/workspace-docs` (Node) required only a self-contained `devenv.nix` enabling `languages.javascript` plus local `docs-*` scripts — mirroring the portal pattern with zero impact on the root.
  - One uniform entry path (`direnv allow` → auto shell + `ws-info`) removes onboarding friction and the class of "I forgot to run setup" bugs.
- **Negative**:
  - Nix has a steep learning curve; contributors unfamiliar with the language pay an upfront cost to read or extend modules under `packages/nix/`.
  - First-time provisioning and `direnv reload` after input bumps can be slow (full evaluation + build) compared to a pre-installed local toolchain.
  - Hard dependency on Nix + direnv + devenv being installed before any work begins; there is deliberately no non-Nix fallback runner.
  - The generated-artifact model has a sharp edge: hand-editing `.golangci.yml`, `go.work`, `.info`, etc. is silently overwritten on the next reload, which surprises contributors who don't know the file is Nix-owned.
- **Neutral**:
  - Module authorship is constrained to `core/` + `extra/` with `enable`-gated `lib.mkIf` config and `core.utils.make*` option helpers — uniform, but a fixed structure newcomers must follow.
  - Secrets are sourced through `secretspec` (root: `protonpass`/`development`; services: `dotenv`/`local`) rather than ad-hoc `.env` files; a different but not strictly better surface.

## Alternatives considered

- **Plain `go.work` + a `Makefile`/`setup.sh` and manually installed tools.** Rejected because it provides no version pinning and no reproducibility — every contributor's Go/linter/Node version drifts, and the setup script inevitably falls out of sync with the real toolchain. This is exactly the failure mode the workspace exists to prevent.
- **Docker / dev-container as the primary environment.** Rejected as the *default* because it adds a container boundary around routine local Go/Node work (slower file IO, editor/LSP integration friction) for little gain over a native reproducible shell. It is kept as an **opt-in** path under `packages/nix/extra/dev-container/` for contributors who want it, layered on the same Nix definitions.
- **`asdf` / `mise` for version management + a separate hook tool.** Rejected because it pins language runtimes but not the rest (linters, AWS CLI, Postgres, secret scanners), and it does not give us declarative *generation* of `go.work` / `.golangci.yml` / `.editorconfig` / `.info`. We would still need a second mechanism for the generated-config requirement, splitting the source of truth.
- **Raw Nix flakes + `nix develop` without devenv.** Rejected because devenv supplies the higher-level surface we actually rely on — `scripts`, `languages.*`, `services.postgres`, `git-hooks`, `secretspec`, and `enterShell` — which we would otherwise have to reimplement by hand on top of bare flakes for no benefit.

## References

- [AGENTS.md](../../AGENTS.md) — workspace overview; "the value lives in conventions enforced by tooling."
- [packages/nix/AGENTS.md](../../packages/nix/AGENTS.md) — module conventions, `core/` vs `extra/`, generated-artifact ownership, option-helper rules.
- [`devenv.nix`](../../devenv.nix) / [`devenv.yaml`](../../devenv.yaml) — root environment wiring and input pins.
- [`services/portal/devenv.nix`](../../services/portal/devenv.nix) — self-contained service devenv (Postgres + migrations).
- [`apps/workspace-docs/devenv.nix`](../../apps/workspace-docs/devenv.nix) — self-contained app devenv (Node + `docs-*` scripts).
- [Nix](https://nixos.org/) · [devenv](https://devenv.sh/) · [direnv](https://direnv.net/) — the underlying tools.
