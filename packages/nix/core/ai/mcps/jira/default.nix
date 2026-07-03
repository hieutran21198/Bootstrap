{
  config,
  lib,
  ...
}:
{
  options.core.ai.mcps.jira =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption {
        default = false;
      };
      url = utils.makeStrOption {
        default = "https://your-company.atlassian.net";
      };
      email = utils.makeStrOption {
        default = "your.email@company.com";
      };
      apiKey = utils.makeStrOption {
        default = "your_api_token";
      };
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [ "scribe" ];
        description = "Agents this MCP is wired to (allowed); every other agent is denied.";
      };
      toolDef = utils.makeStrOption {
        default = "read and write Jira issues (search, create, transition, comment) for backlog and status sync.";
      };
      toolGlob = utils.makeStrOption {
        default = "jira_*";
      };
    };
  config =
    let
      opts = config.core.ai.mcps.jira;
      opencodeOpts = config.core.ai.opencode;
    in
    lib.mkIf opts.enable {
      opencode = lib.mkIf opencodeOpts.enable {
        settings.mcp.jira = {
          type = "local";
          command = [
            "uvx"
            "mcp-atlassian"
          ];
          environment = {
            "JIRA_URL" = opts.url;
            "JIRA_USERNAME" = opts.email;
            "JIRA_API_TOKEN" = opts.apiKey;
          };
        };
      };
    };
}
