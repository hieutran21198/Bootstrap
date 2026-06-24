{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.workspace = {
    dir = lib.mkOption {
      type = lib.types.path;
      default = config.devenv.root;
      readOnly = true;
      description = "Workspace root directory for the development environment.";
    };
    name = lib.mkOption {
      type = lib.types.str;
      default = "Bootstrap";
      description = "Workspace name for the development environment.";
    };
    mandatoryFolders = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = { };
      description = "Mandatory folders and their descriptions for the workspace.";
    };
    toolchainCommandInfos = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = "Additional command information files for the workspace.";
    };
  };
  config =
    let
      better-tree = pkgs.buildGoModule {
        pname = "better-tree";
        version = "0.1.0";

        src = ../..;
        subPackages = [ "generators/better-tree" ];
        vendorHash = null;
        nativeBuildInputs = [
          pkgs.makeWrapper
        ];
        postInstall = ''
          wrapProgram $out/bin/better-tree \
            --prefix PATH : ${lib.makeBinPath [ pkgs.tree ]}
        '';
        meta.mainProgram = "better-tree";
      };
    in
    {
      env = {
        WORKSPACE_ROOT = config.workspace.dir;
        WORKSPACE_NAME = config.workspace.name;
      };

      packages = with pkgs; [
        git
        jq
        tree

        better-tree
      ];

      files =
        let

          gitKeepFiles = lib.mapAttrs' (
            name: _:
            lib.nameValuePair "${name}/.gitkeep" {
              text = "";
              copyMode = "seed";
            }
          ) config.workspace.mandatoryFolders;

          infoList = lib.mapAttrsToList (path: desc: ''
            ${path}
            ''\t${desc}
          '') config.workspace.mandatoryFolders;
        in
        gitKeepFiles
        // {
          ".info" = {
            text = lib.concatStringsSep "\n" infoList;
          };
          ".editorconfig" = lib.mkDefault {
            text = ''
              # https://editorconfig.org
              # One source of truth for whitespace across Go + TS + docs.
              root = true

              [*]
              charset                  = utf-8
              end_of_line              = lf
              insert_final_newline     = true
              trim_trailing_whitespace = true
              indent_style             = space
              indent_size              = 2

              # Tree information.
              [.info]
              indent_style = tab
              indent_size  = 4

              # Go uses tabs; gofmt enforces this and will fight any other setting.
              [*.go]
              indent_style = tab
              indent_size  = 4

              # Makefiles still want literal tabs (even though we use devenv tasks).
              [Makefile]
              indent_style = tab

              # Markdown should keep trailing spaces (line breaks).
              [*.md]
              trim_trailing_whitespace = false
            '';
          };
        };

      scripts = {
        ws-info.exec = ''
          cat <<EOF
          ---
          root_dir: $WORKSPACE_ROOT
          name: $WORKSPACE_NAME
          ---
          Welcome to development environment of $WORKSPACE_NAME!
          ---
          # Workspace Layout
          $(${lib.getExe better-tree} --info -L 2 --gitignore --tabular --doc-only)
          ---
          # Workspace Commands
            devenv up       # deploys the workspace and starts all services.
            devenv shell    # enters a shell with the workspace environment variables set.
            better-tree     # renders the workspace tree structure with descriptions from .info.
            ws-info         # prints workspace information and layout.
          ---
          # Toolchain information
          ${lib.concatStringsSep "\n\t" config.workspace.toolchainCommandInfos}
          EOF
        '';
      };

      enterShell = ''
        ${config.scripts.ws-info.exec}
      '';
    };
}
