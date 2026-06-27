{ config, lib, ... }:
let
  opts = config.core.ai.opencode;
in
{
  config = lib.mkIf (opts.enable && opts.profile == "slim") {
    opencode.settings = {
      plugin = [ "oh-my-opencode-slim@latest" ];
    };
    files.".opencode/oh-my-opencode-slim.json".json = {
      "$schema" = "https://unpkg.com/oh-my-opencode-slim@latest/oh-my-opencode-slim.schema.json";
      showStartupToast = false;
      companion = {
        enabled = true;
        position = "bottom-left";
        size = "small";
      };
      preset = "slim";
      presets =
        let
          inherit (config.core.ai.opencode) agents;
          inheritAgent = x: {
            inherit (x)
              model
              variant
              skills
              mcps
              ;
          };
        in
        {
          slim = {
            orchestrator = inheritAgent agents.orchestrator;
            oracle = inheritAgent agents.architecturer;
            council = inheritAgent agents.orchestrator-minion;
            librarian = inheritAgent agents.researcher;
            explorer = inheritAgent agents.codeExplorer;
            designer = inheritAgent agents.designer;
            fixer = inheritAgent agents.worker;
          };
        };
    };
  };
}
