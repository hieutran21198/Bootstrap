{
  config,
  lib,
  ...
}:
{
  options.core.ai.mcps.linear =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption {
        default = false;
      };
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [ "scribe" ];
        description = "Agents this MCP is wired to (allowed); every other agent is denied.";
      };
      toolDef = utils.makeStrOption {
        default = "read and write Linear issues (search, create, update, comment) for backlog sync and evidence-based delivery.";
      };
      toolGlob = utils.makeStrOption {
        default = "linear_*";
      };
    };
  config =
    let
      opts = config.core.ai.mcps.linear;
      opencodeOpts = config.core.ai.opencode;
    in
    lib.mkIf opts.enable {
      opencode = lib.mkIf opencodeOpts.enable {
        settings.mcp.linear = {
          type = "local";
          command = [
            "npx"
            "-y"
            "mcp-remote"
            "https://mcp.linear.app/mcp"
          ];
          environment = { };
        };
      };
    };
}
