{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.core.workspace = {
    enable = lib.mkEnableOption "Enable the core workspace module for the development environment.";
    name = lib.mkOption {
      type = lib.types.str;
      default = "Bootstrap";
      description = "Workspace name for the development environment.";
    };
    root = lib.mkOption {
      type = lib.types.path;
      default = config.devenv.root;
      readOnly = true;
      description = "Workspace root directory for the development environment.";
    };
    editorConfig = lib.mkOption {
      type = with lib.types; attrsOf anything;
      default = { };
      description = "EditorConfig settings for the workspace.";
    };
    treeInfos = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = { };
      description = "Tree information for the workspace, including folder structure and metadata.";
    };
    toolchainCommandInfos = lib.mkOption {
      type =
        with lib.types;
        listOf (submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name of the toolchain command.";
            };
            description = lib.mkOption {
              type = lib.types.str;
              description = "Description of the toolchain command.";
            };
          };
        });
      default = [ ];
      description = "Additional command information files for the workspace.";
    };
  };
  config =
    let
      opts = config.core.workspace;

      wsTreePkg = pkgs.buildGoModule {
        pname = "ws-tree";
        version = "0.1.0";

        src = ../../../../tools;
        subPackages = [ "generators/ws-tree" ];
        vendorHash = null;
        nativeBuildInputs = [
          pkgs.makeWrapper
        ];
        postInstall = ''
          wrapProgram $out/bin/ws-tree --prefix PATH : ${lib.makeBinPath [ pkgs.tree ]}
        '';
        meta.mainProgram = "ws-tree";
      };
    in
    lib.mkIf opts.enable {
      env = {
        WORKSPACE_ROOT = opts.root;
        WORKSPACE_NAME = opts.name;
      };

      packages = with pkgs; [
        git
        jq
        tree
        wsTreePkg
      ];

      files = {
        # ws-tree information.
        ".info".text =
          let
            infoList = lib.mapAttrsToList (path: desc: ''
              ${path}
              ''\t${desc}
            '') opts.treeInfos;
          in
          lib.concatStringsSep "\n" infoList;

        # editor config file.
        ".editorconfig".toml = {
          root = true;
          "*" = {
            charset = "utf-8";
            end_of_line = "lf";
            insert_final_newline = true;
            trim_trailing_whitespace = true;
            indent_style = "space";
            indent_size = 2;
          };
        }
        // opts.editorConfig;
      };

      scripts = {
        ws-info.exec = ''
          cat <<EOF
          ---
          root_dir: ${opts.root}
          name: ${opts.name}
          ---
          Welcome to development environment of ${opts.name}!
          ---
          # Workspace Layout
          $(${lib.getExe wsTreePkg} --info -L 99 --gitignore --tabular --doc-only)
          ---
          # Workspace Commands
          devenv up                       # deploys the workspace and starts all services.
          devenv shell                    # enters a shell with the workspace environment variables set.
          ws-info                         # prints workspace information and layout.
          ws-tree                         # renders the workspace tree structure with descriptions from .info.
          ws-tree --tabular --doc-only    # renders the workspace tree structure in tabular format with descriptions from .info.
          ---
          # Toolchain information
          ${lib.concatStringsSep "\n" (map (x: "${x.name}\t\t# ${x.description}") opts.toolchainCommandInfos)}
          EOF
        '';
      };

      enterShell = ''
        ${config.scripts.ws-info.exec}
      '';

      core.ai.tools.workspace = {
        permissions = [
          "Bash(ws-info:*)"
          "Bash(ws-tree:*)"
        ];
        sections = {
          inputs = ''
            ### Workspace context

            - The workspace root, name, and mandatory folder set are declared in `devenv.nix` — treat that file as the authoritative layout map.
            - Run `ws-info` for the workspace overview (root, name, layout, available commands); it auto-runs on shell entry.
            - Run `ws-tree` for the directory tree annotated with inline `.info` descriptions; `ws-tree --tabular --doc-only` renders a compact docs-only map suitable for quoting.
          '';
          toolGuidelines = ''
            ### Workspace tools

            - `ws-info` — workspace overview: root, name, layout, available commands. Auto-runs on shell entry.
            - `ws-tree` — directory tree with inline `.info` descriptions. `ws-tree --tabular --doc-only` renders a compact docs-only map.
          '';
        };
        order = 10;
      };
    };
}
