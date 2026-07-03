{
  config,
  lib,
  ...
}:
{
  options.core.ai.mcps.github =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption {
        default = true;
      };
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [ ];
        description = "Agents this MCP is wired to (allowed); every other agent is denied.";
      };
      toolDef = utils.makeStrOption {
        default = "Official GitHub MCP for searching code, issues, PRs, and more across public and private repos (requires GitHub PAT for private repos).";
      };
      toolGlob = utils.makeStrOption {
        default = "github_*";
      };
      apiKey = utils.makeStrOption {
        default = "";
        description = "GitHub Personal Access Token (PAT) for authenticated requests to GitHub API. Required for private repos or higher rate limits.";
      };
    };
  config =
    let
      opts = config.core.ai.mcps.github;
      opencodeOpts = config.core.ai.opencode;
    in
    lib.mkIf opts.enable {
      opencode = lib.mkIf opencodeOpts.enable {
        settings.mcp.github = {
          "url" = "https://api.githubcopilot.com/mcp/";
          "enabled" = true;
          "oauth" = false;
          "headers" = {
            "Authorization" = "Bearer ${opts.apiKey}";
          };
        };
      };
    };
}
