{ config, ... }:
{
  scripts = {
    migrate-new = {
      exec = ''
                if [ -z "$1" ]; then
                  echo "Usage: migrate-new <name>"
                  exit 1
                fi
                DIR="$WORKSPACE_ROOT/internal/infra/postgres/migrations"
                TIMESTAMP=$(date +%Y%m%d%H%M%S)
                FILE="$DIR/''${TIMESTAMP}_$1.sql"
                mkdir -p "$DIR"
                cat > "$FILE" <<'SQLEOF'
        -- +goose Up

        -- +goose Down
        SQLEOF
                echo "Created: $FILE"
      '';
      description = "Create a new portal migration file (e.g. migrate-new add_users_table)";
    };
    migrate-up = {
      exec = ''
        cd "$WORKSPACE_ROOT" && go run ./cmd/migrate up "$@"
      '';
      description = "Run pending portal database migrations";
    };
    migrate-down = {
      exec = ''
        cd "$WORKSPACE_ROOT" && go run ./cmd/migrate down "$@"
      '';
      description = "Roll back the latest portal database migration";
    };
    migrate-status = {
      exec = ''
        cd "$WORKSPACE_ROOT" && go run ./cmd/migrate status "$@"
      '';
      description = "Show portal database migration status";
    };
  };
  core = {
    ai = {
      claude = {
        enable = true;
      };
      opencode = {
        enable = true;
        profile = "slim";
      };
    };
    services = {
      postgres =
        let
          inherit (config.secretspec) secrets;
        in
        {
          enable = true;
          database = "portal";
          port = builtins.fromJSON secrets.POSTGRES_PORT;
          roles = {
            admin.password = secrets.POSTGRES_ADMIN_PASSWORD;
            writer.password = secrets.POSTGRES_WRITER_PASSWORD;
            reader.password = secrets.POSTGRES_READER_PASSWORD;
            # The RLS migrations (staff_rls, organizations_rls) define a
            # `system_read_*` policy `TO system_reader` (ADR-0009), so the role
            # must exist for migrations to apply even though the tenant-facing
            # portal never binds the `system` scope at runtime. Enabling it here
            # only provisions the login role + SELECT grant; cross-tenant
            # visibility still comes solely from the policy.
            systemReader = {
              enable = true;
              password = secrets.POSTGRES_SYSTEM_READER_PASSWORD;
            };
          };
        };
    };
    workspace = {
      enable = true;
      name = "portal";
      wsInfoDeepLevel = 4;
      treeInfos = {
        "README.md" = "Look at me first!";

        # docs (service-scoped; workspace-wide docs live in repo-root docs/)
        "docs" = "Portal service documentation — service-scoped ADRs, specs, findings, debt";
        "docs/adrs" = "Portal-only architecture decisions";
        "docs/specs" = "Portal feature and subsystem designs";
        "docs/findings" = "Portal investigation records";
        "docs/debt" = "Portal technical debt register";

        # command
        "cmd" = "Service binaries";
        "cmd/http" = "HTTP entrypoints (command + query binaries)";
        "cmd/http/command" = "Write-side HTTP binary";
        "cmd/http/query" = "Read-side HTTP binary";
        "cmd/migrate" = "Database migration CLI (up, down, status)";

        # configuration
        "config" = "Service config loader (uses packages/go/env)";

        "internal" = "Service internals — app, delivery, domain, infra";

        # app
        "internal/app" = "Application layer — use cases and ports";
        "internal/app/command" = "Write-side use cases + UnitOfWork port";
        "internal/app/query" = "Read-side use cases + read-model ports";

        # delivery
        "internal/delivery" = "Driving interface layer for HTTP services + business logic → app/query";
        ## delivery http
        "internal/delivery/http" = "HTTP delivery layer";
        "internal/delivery/http/command" = "Write-side HTTP handlers → app/command";
        "internal/delivery/http/query" = "Read-side HTTP handlers → app/query";

        # domain
        "internal/domain" = "Pure domain layer — one package per aggregate";
        "internal/domain/organization" = "Organization aggregate — entity, value objects (slug), ports";
        "internal/domain/staff" = "Staff aggregate — entity, value objects (email, role), ports";

        # infra
        "internal/infra" = "Driven infrastructure adapters — postgres (zitadel planned, ADR-0006)";
        ## infra postgres
        "internal/infra/postgres" = "Postgres adapters — migrations, repos, UoW, read store";
        "internal/infra/postgres/migrations" = "Database migration SQL files (goose)";
        "internal/infra/postgres/repo" = "Writer / Reader implementations (one file per aggregate)";
        "internal/infra/postgres/uow" = "UnitOfWork implementation";
        "internal/infra/postgres/readstore" = "Read-side store implementations (query models)";
      };
    };
    git = {
      enable = true;
    };
    toolchains = {
      aws = {
        enable = true;
      };
      markdown = {
        enable = true;
      };
      go = {
        enable = true;
        golangci-lint = {
          enable = true;
        };
      };
    };
  };
}
