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
    };
  config =
    let
      opts = config.core.ai.mcps.context7;
      opencodeOpts = config.core.ai.opencode;
    in
    lib.mkIf opts.enable {
      core.ai.agents = {
        researcher = {
          permission = {
            "context7_*" = "allow";
          };
          mcps = [ "context7" ];
          toolDefs = {
            "context7" = "use to get official library documentation.";
          };
        };
        orchestrator.permission = {
          "context7_*" = "deny";
        };
        architecturer.permission = {
          "context7_*" = "deny";
        };
        designer.permission = {
          "context7_*" = "deny";
        };
        explorer.permission = {
          "context7_*" = "deny";
        };
        worker.permission = {
          "context7_*" = "deny";
        };
      };
      opencode = lib.mkIf opencodeOpts.enable {
        settings = {
          mcp = {
            "context7" = {
              type = "remote";
              url = "https://mcp.context7.com/mcp";
              headers = {
                "CONTEXT7_API_KEY" = opts.apiKey;
              };
              oauth = false;
            };
          };
        };
      };
    };
}
