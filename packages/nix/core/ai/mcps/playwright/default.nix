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
    };
  config =
    let
      opts = config.core.ai.mcps.playwright;
      opencodeOpts = config.core.ai.opencode;
    in
    lib.mkIf opts.enable {
      core.ai.agents = {
        researcher.permission = {
          "playwright_*" = "deny";
        };
        orchestrator.permission = {
          "playwright_*" = "deny";
        };
        architecturer.permission = {
          "playwright_*" = "deny";
        };
        designer.permission = {
          "playwright_*" = "deny";
        };
        explorer.permission = {
          "playwright_*" = "deny";
        };
        worker = {
          permission = {
            "playwright_*" = "allow";
          };
          mcps = [ "playwright" ];
          toolDefs = {
            "playwright" = "use to get official library documentation.";
          };
        };
      };
      opencode = lib.mkIf opencodeOpts.enable {
        settings = {
          mcp = {
            "playwright" = {
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
      };
    };
}
