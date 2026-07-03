{
  config,
  lib,
  ...
}:
{
  options.core.ai.mcps.context7 =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption {
        default = true;
      };
      apiKey = utils.makeStrOption {
        default = "";
      };
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [ "researcher" ];
        description = "Agents this MCP is wired to (allowed); every other agent is denied.";
      };
      toolDef = utils.makeStrOption {
        default = "fetch official, version-specific library and framework documentation; prefer it over guessing an API.";
      };
      toolGlob = utils.makeStrOption {
        default = "context7_*";
      };
    };
  config =
    let
      opts = config.core.ai.mcps.context7;
      opencodeOpts = config.core.ai.opencode;
    in
    lib.mkIf opts.enable {
      opencode = lib.mkIf opencodeOpts.enable {
        settings.mcp.context7 = {
          type = "remote";
          url = "https://mcp.context7.com/mcp";
          headers = {
            "CONTEXT7_API_KEY" = opts.apiKey;
          };
          oauth = false;
        };
      };
    };
}
