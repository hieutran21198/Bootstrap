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
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [ "researcher" ];
        description = "Agents this MCP is wired to (allowed); every other agent is denied.";
      };
      toolDef = utils.makeStrOption {
        default = "find real-world code examples across ~1M public GitHub repos (literal/regex search via grep.app); prefer for unfamiliar API usage and best-practice patterns.";
      };
      toolGlob = utils.makeStrOption {
        default = "gh_grep_*";
      };
    };
  config =
    let
      opts = config.core.ai.mcps.gh_grep;
      opencodeOpts = config.core.ai.opencode;
    in
    lib.mkIf opts.enable {
      opencode = lib.mkIf opencodeOpts.enable {
        # Vercel grep.app hosted MCP; single tool `searchGitHub` (exposed to
        # agents as `gh_grep_searchGitHub`). Public endpoint — no auth/headers.
        settings.mcp.gh_grep = {
          type = "remote";
          url = "https://mcp.grep.app";
          oauth = false;
        };
      };
    };
}
