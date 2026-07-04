# `deploy/local/` — local ZITADEL stack

Operator runbook for the **local-only** identity stack: a four-container ZITADEL
deployment for development inside `devenv shell`. This is the local counterpart
to the production deployment, which targets **AWS via Terraform** (planned — see
[Scope](#scope)).

> **Decision & context**: [ADR-0006 — Zitadel as the identity and auth provider](../../docs/adrs/0006-zitadel-identity-auth.md).
> **Live topology**: [docs/wiki/architecture/deployment-topology.md](../../docs/wiki/architecture/deployment-topology.md).
> This README is the *how to run it*; the ADR is the *why*, the architecture view is the *what it is*.

## Scope

| Environment | Where | Mechanism | Status |
| ----------- | ----- | --------- | ------ |
| **Local dev** | `deploy/local/` (here) | `docker compose` | Exists — this runbook |
| **AWS** | `deploy/` (Terraform, TBD) | Terraform → AWS | Planned — not in repo yet |

`deploy/local/` is **for development only**. It is not the production artifact:
the masterkey, passwords, `sslmode=disable`, and the single-node Postgres here
are dev defaults. Production identity infra is provisioned by Terraform against
AWS (e.g. ECS/EKS for the ZITADEL containers, RDS PostgreSQL for state, ACM/ALB
for TLS, Secrets Manager for the masterkey). Treat the env vars below as the
**configuration surface** Terraform must supply in AWS — the names are the same,
the values and backing services differ.

## What runs

Four containers on a private `zitadel` Docker network, fronted by Traefik on a
single loopback port. Image tags are pinned in [`.env.example`](.env.example).

| Service | Image | Role |
| ------- | ----- | ---- |
| `proxy` | `traefik:v3.6.8` | Routes one port to the API + Login UI; published on `127.0.0.1:8080` only |
| `zitadel-api` | `ghcr.io/zitadel/zitadel:v4.13.0` | IAM API (gRPC/Connect-RPC over h2c); boots with `start-from-init` |
| `zitadel-login` | `ghcr.io/zitadel/zitadel-login:v4.13.0` | Login v2 UI (Next.js), required by ZITADEL v4 |
| `postgres` | `postgres:17.2-alpine` | ZITADEL event-sourced state; published on `127.0.0.1:5432` |

Routing (Traefik, by path on `Host(localhost)`):

- `/` → Login UI (rewritten to `/ui/v2/login/`)
- `/ui/v2/login` → Login UI
- `/api` → API (prefix stripped, h2c upstream for gRPC)
- everything else → API (console, OIDC discovery, JWKS)

> **Note on ZITADEL's own Postgres**: the `postgres` container here holds
> **ZITADEL's** state, not the portal's application database. The portal uses its
> own database (separate role split — `admin`/`writer`/`reader`, see the
> [role and scope contract](../../docs/conventions/database/role-and-scope-contract.md)).
> Do not point the portal at this `zitadel` database.

## Prerequisites

- Docker + the Compose v2 plugin (`docker compose`, not `docker-compose`).
- The workspace `devenv shell` (provides the rest of the toolchain). Docker
  itself is host-provided.

## Quick start

```bash
cd deploy/local
cp .env.example .env

# Generate a real 32-char masterkey and put it in .env (IMMUTABLE after first init):
tr -dc A-Za-z0-9 </dev/urandom | head -c 32   # paste into ZITADEL_MASTERKEY=

docker compose up -d --wait                   # waits for healthchecks to pass
open http://localhost:8080/ui/console          # or xdg-open on Linux
```

Default admin login (from `.env`): `admin@zitadel.localhost` / `Password1!`.
The login username is `<ZITADEL_FIRSTINSTANCE_ORG_HUMAN_USERNAME>@zitadel.<ZITADEL_DOMAIN>`,
**not** the `EMAIL_ADDRESS` field.

## Endpoints (local)

| Purpose | URL |
| ------- | --- |
| Admin console | `http://localhost:8080/ui/console` |
| Login v2 UI | `http://localhost:8080/ui/v2/login/` |
| OIDC discovery | `http://localhost:8080/.well-known/openid-configuration` |
| JWKS | `http://localhost:8080/oauth/v2/keys` |
| REST/gRPC API gateway | `http://localhost:8080/api` |
| Postgres (ZITADEL state) | `127.0.0.1:5432` (db `zitadel`, user `postgres`) |

## Configuration surface (`.env`)

`.env` is git-ignored; only [`.env.example`](.env.example) is tracked. The
load-bearing variables (full list in `.env.example`):

| Variable | Purpose | Production note (Terraform/AWS) |
| -------- | ------- | ------------------------------- |
| `ZITADEL_VERSION` | Pins both ZITADEL images | Pin the same tag in the Terraform task/image def |
| `ZITADEL_MASTERKEY` | 32-char key encrypting data at rest. **Immutable after first init** | Source from AWS Secrets Manager, never commit |
| `ZITADEL_DOMAIN` / `ZITADEL_EXTERNALPORT` / `ZITADEL_EXTERNALSECURE` / `ZITADEL_PUBLIC_SCHEME` | External URL shape | Real domain + `EXTERNALSECURE=true` + `https` behind ALB/ACM |
| `ZITADEL_DATABASE_POSTGRES_DSN` | ZITADEL ↔ Postgres connection | Point at RDS; `sslmode=require`, credentials from Secrets Manager |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | Local Postgres container creds | N/A — RDS-managed in AWS |
| `ZITADEL_FIRSTINSTANCE_*` | Default org + admin user created on **first boot only** | Set once at provisioning; rotate the admin password after |

Changing `ZITADEL_FIRSTINSTANCE_*` after the first boot has no effect — the
first instance is created once. To re-bootstrap, tear down volumes (below).

## Operating

```bash
docker compose ps                     # status + health
docker compose logs -f zitadel-api    # follow a service's logs
docker compose restart zitadel-api    # restart one service
docker compose down                   # stop + remove containers (KEEPS volumes/data)
docker compose down -v                # stop + DELETE volumes (full reset — see below)
```

### Full reset (re-run first-init)

The first instance, admin user, and `login-client` PAT are created **once** on
first boot. To start clean (e.g. masterkey change, corrupted state):

```bash
docker compose down -v    # removes pg-data + zitadel-bootstrap volumes
docker compose up -d --wait
```

> `down -v` is destructive: it deletes all ZITADEL state. Only use it locally.

## Troubleshooting

- **`zitadel-api` unhealthy / restarting** — almost always Postgres not ready or
  a bad `ZITADEL_DATABASE_POSTGRES_DSN`. Check `docker compose logs zitadel-api`;
  confirm `postgres` is healthy (`docker compose ps`).
- **Changed the masterkey and now data is unreadable** — the masterkey is
  immutable after init; encrypted data is lost. Do a [full reset](#full-reset-re-run-first-init).
- **Login redirects to the wrong host/port** — `ZITADEL_DOMAIN` /
  `ZITADEL_EXTERNALPORT` / `ZITADEL_PUBLIC_SCHEME` must match the URL you browse
  to; they bake into the Login v2 base URI and OIDC redirect URLs.
- **`login-client.pat` missing** — the `zitadel-login` container reads it from
  the shared `zitadel-bootstrap` volume; it appears after `zitadel-api`
  completes first-init. If the volume was cleared, the login UI fails until a
  re-init regenerates the PAT.
- **Port 8080 / 5432 already in use** — both bind to `127.0.0.1` only; stop the
  conflicting local process or change the published port in
  [`docker-compose.yaml`](docker-compose.yaml).

## See also

- [ADR-0006](../../docs/adrs/0006-zitadel-identity-auth.md) — the decision to self-host ZITADEL.
- [docs/wiki/architecture/deployment-topology.md](../../docs/wiki/architecture/deployment-topology.md) — the live topology view.
- [docs/wiki/architecture/system-overview.md](../../docs/wiki/architecture/system-overview.md) — where identity sits in the system.
- [`docker-compose.yaml`](docker-compose.yaml) · [`.env.example`](.env.example) — the files this runbook operates.
- [ZITADEL docker compose guide](https://zitadel.com/docs/self-hosting/deploy/compose) — upstream reference.
