{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.core.toolchains.markdown = {
    enable = lib.mkEnableOption "Enable the core toolchain module for the development environment.";
  };
  config =
    let
      opts = config.core.toolchains.markdown;
      # Tuned ruleset: disables rules the repo house style intentionally
      # doesn't follow, keeps structural/hygiene rules (MD022, MD031,
      # MD032, MD040). All tracked markdown is linted; only raw evidence
      # assets (.assets/), generated artifacts, and vendored directories
      # are exempt.
      markdownlintConfig = builtins.toJSON {
        config = {
          MD004 = false; # ul-style: plus signs used in some docs
          MD009 = false; # trailing-spaces: editorconfig intentionally preserves in .md
          MD010 = false; # hard-tabs: Go code blocks in .md use tabs by design
          MD013 = false; # line-length: repo prose/tables run long by design
          MD024 = false; # duplicate-headings: repeated section names (Rule/Rationale) intentional
          MD028 = false; # blanks-blockquote: intentional formatting in PRDs/specs
          MD033 = false; # inline-html: templates use <placeholder> tokens
          MD034 = false; # bare-urls: not harmful enough to enforce
          MD041 = false; # first-line-heading: AGENTS.md headers vary by file type
          MD047 = false; # single-trailing-newline: generated/symlinked files may differ
          MD049 = false; # emphasis-style: mixed asterisk/underscore usage is intentional
          MD051 = false; # link-fragments: noisy across AI-generated content
          MD058 = false; # blanks-around-tables: compact tables used repo-wide
          MD060 = false; # table-column-style: compact tables used repo-wide
        };
        ignores = [
          "**/.claude/"
          "**/.codegraph/"
          "**/.devenv/"
          "**/.git/"
          "**/.opencode/"
          "**/.worktrees/"
          "**/node_modules/"
          "**/*.assets/"
          "CLAUDE.md"
        ];
      };
    in
    lib.mkIf opts.enable {
      packages = [
        pkgs.markdownlint-cli2
      ];

      # The generated config file (ruleset + ignores for glob-based runs).
      files.".markdownlint-cli2.jsonc".text = markdownlintConfig;

      git-hooks.hooks = {
        # Preserve trailing whitespace in Markdown (hard line breaks).
        trim_trailing_whitespace = {
          args = [ "--markdown-linebreak-ext=md" ];
        };

        # Markdown consistency gate — all tracked markdown is linted.
        # Only raw evidence assets (.assets/) are exempt; generated and
        # vendored files are already gitignored and never staged.
        markdownlint = {
          enable = true;
          name = "markdownlint: markdown consistency";
          entry = "${lib.getExe pkgs.markdownlint-cli2} --config .markdownlint-cli2.jsonc";
          language = "system";
          pass_filenames = true;
          files = "\.md$";
          excludes = [ "\.assets/" ];
        };
      };

      core = {
        workspace = {
          editorConfig = {
            "*.md" = {
              trim_trailing_whitespace = false;
            };
          };
        };
      };
    };
}
