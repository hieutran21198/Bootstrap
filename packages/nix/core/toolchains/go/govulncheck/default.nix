{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.core.toolchains.go.govulncheck = {
    enable = lib.mkEnableOption "Enable govulncheck support.";
  };

  config =
    let
      goOpts = config.core.toolchains.go;
      opts = goOpts.govulncheck;
    in
    lib.mkIf opts.enable {
      assertions = [
        {
          assertion = goOpts.enable;
          message = "Go toolchain support must be enabled to use govulncheck support.";
        }
      ];

      packages = [ pkgs.govulncheck ];

      scripts.govuln-scan = {
        exec = ''
          set -euo pipefail
          cd "$WORKSPACE_ROOT" || exit 1

          for d in $(go list -m -f '{{.Dir}}' all); do
            (cd "$d" && govulncheck ./...)
          done
        '';
        description = "Run govulncheck across every module in the Go workspace";
      };

      core.workspace.toolchainCommandInfos = [
        {
          name = "govuln-scan";
          inherit (config.scripts.govuln-scan) description;
        }
      ];
    };
}
