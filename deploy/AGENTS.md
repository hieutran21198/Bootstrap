# deploy/

## OVERVIEW

Deployment environments root with its **own devenv** (`devenv.nix` + `devenv.yaml`, evaluated standalone — it does NOT import `packages/nix/`, so no `core.*` options exist here; the current `devenv.nix` is still stock devenv boilerplate). Today the only real content is `local/` — a four-container ZITADEL docker-compose stack for development. Production deployment targets **AWS via Terraform** and is planned, not in the repo yet.

## WHERE TO LOOK

| Need | Location |
|------|----------|
| Run / operate the local ZITADEL stack | [local/README.md](local/README.md) — the operator runbook |
| Why ZITADEL | [ADR-0006](../docs/adrs/0006-zitadel-identity-auth.md) |
| What the deployment looks like | [docs/wiki/architecture/deployment-topology.md](../docs/wiki/architecture/deployment-topology.md) |
| Auth/OIDC integration contract | [docs/conventions/auth/](../docs/conventions/auth/) |
| Future AWS/Terraform work | `deploy/` (planned; Terraform toolchain module exists at `packages/nix/core/toolchains/terraform/`, not yet enabled) |

## NOTES

- `local/` is **development-only**: committed masterkey/passwords, `sslmode=disable`, single-node Postgres — never a production artifact.
- Operational procedures live in `local/README.md`; link to it, never copy its steps here.
- Managed-worktree port offsets do **not** apply to `deploy/local` docker-compose host ports (explicit non-goal of `docs/specs/parallel-agent-worktrees.md`).
