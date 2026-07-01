{
  config,
  lib,
  ...
}:
{
  options.core.ai.mcps.gh_grep =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption {
        default = true;
      };
    };
  config =
    let
      opts = config.core.ai.mcps.gh_grep;
      opencodeOpts = config.core.ai.opencode;
    in
    lib.mkIf opts.enable {
      core.ai.agents = {
        # External code-search tool (grep.app by Vercel): literal/regex code search
        # across ~1M public GitHub repos. External-research lane → researcher only.
        # The researcher's instructions already document `gh_grep`; the worker's
        # instructions explicitly forbid it, so every other agent stays denied —
        # mirroring how context7 is scoped.
        researcher = {
          permission = {
            "gh_grep_*" = "allow";
          };
          mcps = [ "gh_grep" ];
          toolDefs = {
            "gh_grep" =
              "use to find real-world code examples across public GitHub repos (literal/regex code search via grep.app); prefer for unfamiliar API usage and best-practice patterns.";
          };
        };
        orchestrator.permission = {
          "gh_grep_*" = "deny";
        };
        architecturer.permission = {
          "gh_grep_*" = "deny";
        };
        designer.permission = {
          "gh_grep_*" = "deny";
        };
        explorer.permission = {
          "gh_grep_*" = "deny";
        };
        worker.permission = {
          "gh_grep_*" = "deny";
        };
      };
      opencode = lib.mkIf opencodeOpts.enable {
        settings = {
          mcp = {
            # Vercel grep.app hosted MCP; single tool `searchGitHub` (exposed to
            # agents as `gh_grep_searchGitHub`). Public endpoint — no auth/headers.
            "gh_grep" = {
              type = "remote";
              url = "https://mcp.grep.app";
              oauth = false;
            };
          };
        };
      };
    };
}
