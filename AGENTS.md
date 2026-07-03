**Generated:** 2026-07-03T02:47:50Z
**Commit:** c2d1b69
**Branch:** feature/git-conventions-enforcement

## OVERVIEW
A greenfield Go monorepo managed by Nix and devenv. Three Go modules are bound via go.work; the value lives in conventions enforced by tooling, docs, and generated shell wiring.

## STRUCTURE
```
bootstrap/
├── apps/
│   └── workspace-docs/  # Docusaurus docs site (own devenv; renders root + portal docs)
├── deploy/              # deployment devenv + deploy/local ZITADEL docker-compose
├── docs/                # GLOBAL docs: ADRs / architecture / specs / conventions / glossary / findings / debt / wiki
├── packages/
│   ├── go/              # shared Go module (env, errorsx, aws/ssmx, gormx, idgen, migrate, echox)
│   └── nix/             # Nix devenv modules (core/ mandatory, extra/ opt-in)
├── services/portal/     # Clean Arch + CQRS service (domain/app/infra built; delivery/config/zitadel planned)
├── tools/               # workspace tooling Go module
│   ├── ai/skills/       # git-workflow / go-pattern / init-deep / rls-patterns skill bodies
│   ├── generators/ws-tree/   # tree + .info description inliner
│   ├── scripts/         # setup-branch-protection.sh GitHub ruleset helper
│   └── validators/git-guard/ # git rule validator used by hooks + CI
├── devenv.nix           # workspace name + core.workspace.treeInfos + module toggles
├── devenv.yaml          # imports packages/nix/ modules
└── go.work              # binds packages/go, services/portal, tools
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add workspace-wide ADR / convention | `docs/adrs/`, `docs/conventions/` | See [docs/AGENTS.md](docs/AGENTS.md) for per-track format + lifecycle |
| See/update the system architecture | `docs/architecture/` | Living, system-wide views (overview, request flow, deployment topology) — see [docs/architecture/README.md](docs/architecture/README.md), ADR-0010 |
| Git workflow / commit rules | `docs/conventions/git/`, `tools/validators/git-guard/` | ADR-0012; git-guard is the single source of truth |
| Auth / OIDC integration contract | `docs/conventions/auth/` | Provider-specific claims stay behind infra adapters |
| DB role & RLS scope contract | `docs/conventions/database/` | GUC + role contract for tenant/system scopes |
| Render/browse docs site | `apps/workspace-docs/` | Docusaurus app; use `docs-dev` in its devenv shell |
| Local identity stack | `deploy/local/` | ZITADEL docker-compose; see its README.md |
| Add portal-specific doc | `services/portal/docs/` | Service-scoped ADRs/specs/findings/debt — see [services/portal/docs/README.md](services/portal/docs/README.md) |
| Add a folder description | `core.workspace.treeInfos` in the owning `devenv.nix` | Generates the `.info` row `ws-tree` inlines (descriptions only — no `.gitkeep` seeding) |
| Add Nix devenv module | `packages/nix/core/` (or `extra/` for opt-in) | See [packages/nix/AGENTS.md](packages/nix/AGENTS.md) |
| Add Go code to portal | `services/portal/internal/` | See [services/portal/AGENTS.md](services/portal/AGENTS.md) |
| Add shared Go library | `packages/go/` | See [packages/go/AGENTS.md](packages/go/AGENTS.md) for SRP governance |
| Add workspace CLI tool | `tools/generators/<name>/` or `tools/validators/<name>/` | See [tools/AGENTS.md](tools/AGENTS.md) |
| Configure AI agents | `packages/nix/core/ai/opencode/` | opencode agents + `max`/`slim` profiles |
| Add/edit an AI skill body | `tools/ai/skills/<name>/SKILL.md` | Current bodies: `git-workflow`, `go-pattern`, `init-deep`, `rls-patterns` |

## CODE MAP
| Symbol | Type | Location | Role |
|--------|------|----------|------|
| env.Loader | interface | packages/go/env/port.go:6 | env-var loader port |
| env.Parse | func | packages/go/env/env.go:59 | typed generic parser, merges loaders |
| errorsx.Error | struct | packages/go/errorsx/errorsx.go:103 | structured transport-neutral app error |
| ssmx.Loader | struct | packages/go/aws/ssmx/ssm.go:34 | AWS SSM Parameter Store loader; structural `env.Loader` |
| ssmx.NewFromEnv | func | packages/go/aws/ssmx/ssm.go:47 | build loader from default AWS cred chain |
| gormx.New | func | packages/go/gormx/gormx.go:38 | gorm.DB wrapper ctor (SRP-stateful) |
| gormx/postgres.New | func | packages/go/gormx/postgres/postgres.go:50 | postgres dialector (pure-Go pgx) |
| gormx/sqlite.New | func | packages/go/gormx/sqlite/sqlite.go:27 | sqlite dialector (pure Go, no CGO) |
| idgen.NewFor | func | packages/go/idgen/idgen.go:38 | typed UUIDv7 generator (generic, stateless) |
| idgen.Validate | func | packages/go/idgen/idgen.go:58 | UUIDv7 boundary validation |
| migrate.New | func | packages/go/migrate/migrate.go:45 | goose migrator ctor (SRP-stateful) |
| echox.New | func | packages/go/server/echox/echox.go:44 | echo v4 server ctor (SRP-stateful) |
| organization.Organization | struct | services/portal/internal/domain/organization/organization.go:31 | tenant aggregate root |
| staff.Staff | struct | services/portal/internal/domain/staff/staff.go:30 | employed-person aggregate root |
| command.UnitOfWork | interface | services/portal/internal/app/command/port.go:55 | tenant-scoped write port (`DoOrganizationTransaction`) |
| query.ReadStore | interface | services/portal/internal/app/query/port.go:61 | tenant-scoped read port (`DoOrganizationQuery` + `DoSystemQuery`) |
| query.SystemReadCapability | struct | services/portal/internal/app/query/system_scope.go:88 | unforgeable cross-tenant read capability |
| postgres.NewMigrator | func | services/portal/internal/infra/postgres/migrate.go:29 | embedded goose migrations |
| ws-tree main | func | tools/generators/ws-tree/main.go:31 | tree + `.info` description inliner |
| git-guard main | func | tools/validators/git-guard/main.go:24 | git rules CLI for hooks + CI |

## CONVENTIONS
- **Whitespace**: `.editorconfig` (Nix-generated) — Go uses tabs; all others 2-space indent; Markdown preserves trailing spaces
- **Go module paths**: `bootstrap/<segment>/<module>` — no domain prefix; workspace name is the prefix
- **Go version**: `1.26.3` pinned across all `go.mod` + `go.work`; match when adding modules
- **Folder descriptions**: add the path to `core.workspace.treeInfos` in the owning `devenv.nix` (root, service, app) — generates the `.info` row `ws-tree` inlines (descriptions only)
- **Commits**: Conventional Commits and branch rules are enforced by `tools/validators/git-guard` and Nix-wired hooks (ADR-0012)
- **Docs are two-tier**: workspace-wide standards in root [`docs/`](docs/); service-only docs in `services/<name>/docs/` (e.g. [services/portal/docs/](services/portal/docs/)). ADRs append-only; conventions living — see [docs/AGENTS.md](docs/AGENTS.md)

## ANTI-PATTERNS (THIS PROJECT)
- **Generated files**: do not hand-edit `.pre-commit-config.yaml`, `.golangci.yml`, `.editorconfig`, `go.work`, `.info`, `.claude/*`, `.opencode/*`, or `CLAUDE.md`
- **Go import paths**: no vanity domain prefixes; `bootstrap/` is the root
- **No Makefile / setup.sh / bootstrap.sh**: devenv scripts are the only runner
- **File size cap**: 1 MB (`check-added-large-files --maxkb=1024`)
- **Local-only dirs**: `.opencode/`, `.claude/`, `.codex/`, `.omo/`, `.codegraph/` are gitignored per-developer agent configs/caches — do not commit

## UNIQUE STYLES
- No numeric prefixes for module dirs in `packages/nix/` — descriptive names only (the numbered `tools/_nixenv/` convention is retired)
- `enterShell` auto-runs `ws-info` on every `cd` with direnv enabled
- `ws-tree` reads `.info` for inline descriptions in tree output
- Each service/app can own its devenv and `treeInfos` (`services/portal/`, `apps/workspace-docs/`)

## COMMANDS
```bash
direnv allow     # one-time consent; auto-enters dev shell on every cd
ws-info          # workspace overview (auto-runs on shell entry)
ws-tree          # tree + inline .info descriptions
go-info          # Go toolchain version + env
lint-go          # golangci-lint across all go.work modules (--fix to auto-fix)
devenv shell     # explicit shell entry
```
Scoped devenv shells add local commands: `services/portal` has `migrate-up` / `migrate-down` / `migrate-status` / `migrate-new` / `pg-info`; `apps/workspace-docs` has `docs-install` / `docs-dev` / `docs-build` / `docs-serve`.

## NOTES
- Real content now spans `apps/workspace-docs/`, `deploy/local/`, `tools/validators/`, `tools/scripts/`, `packages/go/`, and `services/portal/internal/`.
- `services/portal/internal/` has substantial domain/app/infra code; `delivery/http`, `config/`, and `infra/zitadel/` are still planned/empty.
- `packages/nix/extra/` — optional Nix modules (currently `dev-container`); not imported by `core`, opt in via root `devenv.yaml`.
- ADRs currently run 0001–0012.
