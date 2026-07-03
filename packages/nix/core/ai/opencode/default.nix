{ lib, config, ... }: {
  options.core.ai.opencode =
    let
      inherit (config.core) utils;
    in
    {
      enable = lib.mkEnableOption "Enable opencode";
      settings = utils.makeAttrsOption {
        ofType = lib.types.anything;
        default = { };
      };
    };
  config =
    let
      inherit (config.core.ai.opencode) enable settings;
    in
    lib.mkIf enable {
      opencode = {
        enable = true;
        settings = {
          agent = {
            explore.enabled = false;
          };
          plugin = [
            "compound-engineering@git+https://github.com/EveryInc/compound-engineering-plugin.git"
            [
              "@plannotator/opencode@latest"
              {
                workflow = "plan-agent";
                planningAgents = [
                  "plan"
                  "orchestrator"
                ];
              }
            ]
          ];
        }
        // settings;
      };
      env = {
        OPENCODE_CONFIG_DIR = config.core.workspace.root + "/.opencode";
        OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = true;
      };
    };
}
