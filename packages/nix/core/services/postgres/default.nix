{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.core.services.postgres;

  # TCP host for connection info (fallback to localhost when using unix sockets)
  connHost = if cfg.listenAddress != "" then cfg.listenAddress else "localhost";

  # Idempotent role creation — safe across re-initialisation
  createRoleSQL = name: password: ''
    DO $$
    BEGIN
      CREATE ROLE "${name}" WITH LOGIN PASSWORD '${password}';
    EXCEPTION WHEN duplicate_object THEN RAISE NOTICE '%, skipping', SQLERRM USING ERRCODE = SQLSTATE;
    END
    $$;
  '';
in
{
  options.core.services.postgres = {
    enable = lib.mkEnableOption "PostgreSQL service with configurable login roles (admin, writer, reader).";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql;
      defaultText = lib.literalExpression "pkgs.postgresql";
      description = "PostgreSQL package to use.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        TCP/IP address to listen on. Empty string for unix socket only.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5432;
      description = "TCP port for PostgreSQL connections.";
    };

    database = lib.mkOption {
      type = lib.types.str;
      default = "app";
      description = "Name of the initial database to create. Owned by the admin role when admin is enabled.";
    };

    roles.admin = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Create the admin login role (database owner).";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Admin role name.";
      };
      password = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Admin role password. Override with secretspec-managed value.";
      };
      superuser = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Grant SUPERUSER to the admin role.";
      };
    };

    roles.writer = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Create the writer login role (SELECT, INSERT, UPDATE, DELETE).";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "writer";
        description = "Writer role name.";
      };
      password = lib.mkOption {
        type = lib.types.str;
        default = "writer";
        description = "Writer role password. Override with secretspec-managed value.";
      };
    };

    roles.reader = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Create the reader login role (SELECT only).";
      };
      name = lib.mkOption {
        type = lib.types.str;
        default = "reader";
        description = "Reader role name.";
      };
      password = lib.mkOption {
        type = lib.types.str;
        default = "reader";
        description = "Reader role password. Override with secretspec-managed value.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgres = {
      enable = true;
      package = cfg.package;
      listen_addresses = cfg.listenAddress;
      port = cfg.port;

      # Database owned by admin (or default $USER when admin is disabled)
      initialDatabases = [
        (
          if cfg.roles.admin.enable then
            {
              name = cfg.database;
              user = cfg.roles.admin.name;
              pass = cfg.roles.admin.password;
            }
          else
            { name = cfg.database; }
        )
      ];

      # Runs after initialDatabases — elevate admin and create writer/reader.
      # initialScript executes against the "postgres" database, so we use
      # \connect to switch to the target database for per-database grants
      # (GRANT ON SCHEMA, ALTER DEFAULT PRIVILEGES are database-scoped).
      initialScript = lib.concatStringsSep "\n" (
        # --- Phase 1: role-level operations (work from any database) ---
        # Elevate admin to superuser
        (lib.optional (cfg.roles.admin.enable && cfg.roles.admin.superuser) ''
          ALTER ROLE "${cfg.roles.admin.name}" WITH SUPERUSER;
        '')
        # Create writer role + database-level CONNECT grant
        ++ (lib.optional cfg.roles.writer.enable ''
          ${createRoleSQL cfg.roles.writer.name cfg.roles.writer.password}
          GRANT CONNECT ON DATABASE "${cfg.database}" TO "${cfg.roles.writer.name}";
        '')
        # Create reader role + database-level CONNECT grant
        ++ (lib.optional cfg.roles.reader.enable ''
          ${createRoleSQL cfg.roles.reader.name cfg.roles.reader.password}
          GRANT CONNECT ON DATABASE "${cfg.database}" TO "${cfg.roles.reader.name}";
        '')
        # --- Phase 2: switch to target database for per-database grants ---
        ++ [ "\\connect \"${cfg.database}\"" ]
        # Writer per-database grants + default privileges
        ++ (lib.optional cfg.roles.writer.enable ''
          GRANT USAGE ON SCHEMA public TO "${cfg.roles.writer.name}";
          GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "${cfg.roles.writer.name}";
          GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "${cfg.roles.writer.name}";
          ${lib.optionalString cfg.roles.admin.enable ''
            ALTER DEFAULT PRIVILEGES FOR ROLE "${cfg.roles.admin.name}" IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "${cfg.roles.writer.name}";
            ALTER DEFAULT PRIVILEGES FOR ROLE "${cfg.roles.admin.name}" IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO "${cfg.roles.writer.name}";
          ''}
        '')
        # Reader per-database grants + default privileges
        ++ (lib.optional cfg.roles.reader.enable ''
          GRANT USAGE ON SCHEMA public TO "${cfg.roles.reader.name}";
          GRANT SELECT ON ALL TABLES IN SCHEMA public TO "${cfg.roles.reader.name}";
          ${lib.optionalString cfg.roles.admin.enable ''
            ALTER DEFAULT PRIVILEGES FOR ROLE "${cfg.roles.admin.name}" IN SCHEMA public GRANT SELECT ON TABLES TO "${cfg.roles.reader.name}";
          ''}
        '')
      );
    };

    # Expose structural connection parameters as environment variables.
    # Consumers (services, CLIs) read these individual fields and construct
    # their own connection objects — no DSN string opinion.
    env = lib.mkMerge [
      {
        POSTGRES_HOST = connHost;
        POSTGRES_PORT = toString cfg.port;
        POSTGRES_DATABASE = cfg.database;
      }
      (lib.optionalAttrs cfg.roles.admin.enable {
        POSTGRES_ADMIN_USER = cfg.roles.admin.name;
        POSTGRES_ADMIN_PASSWORD = cfg.roles.admin.password;
      })
      (lib.optionalAttrs cfg.roles.writer.enable {
        POSTGRES_WRITER_USER = cfg.roles.writer.name;
        POSTGRES_WRITER_PASSWORD = cfg.roles.writer.password;
      })
      (lib.optionalAttrs cfg.roles.reader.enable {
        POSTGRES_READER_USER = cfg.roles.reader.name;
        POSTGRES_READER_PASSWORD = cfg.roles.reader.password;
      })
    ];

    # pg-info script for discoverability via ws-info
    scripts.pg-info = {
      exec = ''
        cat <<EOF
        # PostgreSQL Service Information
        Database: ${cfg.database}
        Listen:   ${connHost}:${toString cfg.port}
        Roles:
        ''\t${lib.optionalString cfg.roles.admin.enable "admin  (${cfg.roles.admin.name}) — superuser, database owner"}
        ''\t${lib.optionalString cfg.roles.writer.enable "writer (${cfg.roles.writer.name}) — CRUD (SELECT, INSERT, UPDATE, DELETE)"}
        ''\t${lib.optionalString cfg.roles.reader.enable "reader (${cfg.roles.reader.name}) — SELECT only"}
        Connection (structural env vars):
        ''\tPOSTGRES_HOST=${connHost}
        ''\tPOSTGRES_PORT=${toString cfg.port}
        ''\tPOSTGRES_DATABASE=${cfg.database}
        ''\t${lib.optionalString cfg.roles.admin.enable "POSTGRES_ADMIN_USER=${cfg.roles.admin.name}  POSTGRES_ADMIN_PASSWORD=***"}
        ''\t${lib.optionalString cfg.roles.writer.enable "POSTGRES_WRITER_USER=${cfg.roles.writer.name}  POSTGRES_WRITER_PASSWORD=***"}
        ''\t${lib.optionalString cfg.roles.reader.enable "POSTGRES_READER_USER=${cfg.roles.reader.name}  POSTGRES_READER_PASSWORD=***"}
        EOF
      '';
      description = "PostgreSQL service information (database, roles, connection env vars)";
    };

    # Surface pg-info in ws-info command listing
    core.workspace.toolchainCommandInfos = [
      {
        name = "pg-info";
        inherit (config.scripts.pg-info) description;
      }
    ];
  };
}
