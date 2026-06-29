{
  config,
  lib,
  ...
}:
{
  options.core.toolchains.go.go-work = {
    enable = lib.mkEnableOption "Enable go.work support (requires Go 1.18+).";
    mods = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "List of go.work module directories (relative to workspace root).";
    };
  };
  config =
    let
      goOpts = config.core.toolchains.go;
      opts = goOpts.go-work;
    in
    lib.mkIf opts.enable {
      assertions = [
        {
          assertion = goOpts.enable;
          message = "Go toolchain support must be enabled to use go.work support.";
        }
      ];
      files."go.work" = lib.mkIf opts.enable {
        copyMode = "symlink";
        text = ''
          go ${config.languages.go.version}

          use (
          ${lib.concatMapStringsSep "\n" (dir: "\t${dir}") opts.mods}
          )
        '';
      };
      scripts = {
        lint-go = {
          exec = ''
            set -o pipefail
            cd "$WORKSPACE_ROOT" || exit 1

            # Module list is declared in Nix at go-toolchain.go-work.mods.
            # No runtime `go list -m` — Nix is the single source of truth.
            mods=(${lib.concatMapStringsSep " " (m: ''"${m}"'') opts.mods})

            if [ ''${#mods[@]} -eq 0 ]; then
              echo "lint-go: no modules declared in go-toolchain.go-work.mods — nothing to lint." >&2
              exit 0
            fi

            echo "Running golangci-lint across declared go.work modules (skips empties; pass --fix to auto-fix)"

            rc=0
            for mod in "''${mods[@]}"; do
              mod_dir="$WORKSPACE_ROOT/$mod"
              pkgs=$(cd "$mod_dir" && go list ./... 2>/dev/null || true)
              if [ -z "$pkgs" ]; then
                echo "→ $mod: no Go packages, skipping"
                continue
              fi
              echo "→ $mod"
              (cd "$mod_dir" && golangci-lint run ./... "$@") || rc=$?
            done

            exit $rc
          '';
          description = "Run golangci-lint across declared go.work modules (skips empties; pass --fix to auto-fix)";
        };
      };
    };
}
