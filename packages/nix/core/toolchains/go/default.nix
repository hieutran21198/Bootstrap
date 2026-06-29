{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./go-work/default.nix
    ./golangci-lint/default.nix
  ];
  options.core.toolchains.go = {
    enable = lib.mkEnableOption "Enable the core toolchain module for the development environment.";
  };
  config =
    let
      opts = config.core.toolchains.go;
    in
    lib.mkIf opts.enable {
      packages = with pkgs; [
        gotools
        air
      ];
      languages = {
        go = {
          enable = true;
          delve = {
            enable = true;
          };
          lsp = {
            enable = true;
          };
          enableHardeningWorkaround = true;
          version = "1.26.3";
        };
      };

      scripts = {
        sync-go =
          let
            goModSync = "go mod tidy";
            goWorkSync = (
              lib.concatMapStringsSep "\n" (
                x:
                let
                  cleanPath = lib.removePrefix "./" x;
                in
                ''go -C "$WORKSPACE_ROOT"/${lib.escapeShellArg cleanPath} mod tidy''
              ) opts.go-work.mods
            );
          in
          {
            exec = ''
              set -euo pipefail''\n
              ${if opts.go-work.enable then goWorkSync else goModSync}
            '';
            description = "Run go mod tidy for all module inside go work.";
          };
        go-info = {
          exec = ''
            cat<<EOF
            # Golang Toolchain Information
            Version: ${config.languages.go.version}
            Go work enabled: ${toString opts.go-work.enable}
            Go work modules:
            ''\t${lib.optionalString (opts.go-work.enable) "${lib.concatStringsSep "\n\t" opts.go-work.mods}"}

            # Workspace commands
            lint-go       # Lint Go files
            sync-go       # Synchronize Go modules in workspace
            EOF
          '';
          description = "Go toolchain information";
        };
      };

      git-hooks.hooks = lib.mkIf config.core.git.enable {
        lint-go = {
          enable = true;
          name = "golangci-lint (workspace)";
          entry = "lint-go";
          language = "system";
          files = "\\.go$";
          pass_filenames = false;
        };
      };

      core = {
        workspace = {
          toolchainCommandInfos = [
            {
              name = "go-info";
              inherit (config.scripts.go-info) description;
            }
          ];
          editorConfig = {
            "*.go" = {
              indent_style = "tab";
              indent_size = 4;
            };
          };
        };
      };
    };
}
