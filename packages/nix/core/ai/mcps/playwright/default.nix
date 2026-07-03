{
  config,
  lib,
  ...
}:
{
  options.core.ai.mcps.playwright =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption {
        default = true;
      };
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [ "frontend-engineer" ];
        description = "Agents this MCP is wired to (allowed); every other agent is denied.";
      };
      toolDef = utils.makeStrOption {
        default = "drive a real browser (navigate, click, snapshot, evaluate) for browser-verified UI QA and polish.";
      };
      toolGlob = utils.makeStrOption {
        default = "playwright_*";
      };
    };
  config =
    let
      opts = config.core.ai.mcps.playwright;
      opencodeOpts = config.core.ai.opencode;
    in
    lib.mkIf opts.enable {
      opencode = lib.mkIf opencodeOpts.enable {
        settings.mcp.playwright = {
          type = "local";
          command = [
            "npx"
            "-y"
            "@playwright/mcp"
            "--browser"
            "chrome"
          ];
        };
      };
    };
}
