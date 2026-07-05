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
      plugins = {
        handoff-audit-log = {
          enable = utils.makeBoolOption {
            default = false;
            description = "Enable the handoff-audit-log plugin (captures task tool calls to .sdlc/<task-slug>/handoffs/)";
          };
        };
      };
    };
  config =
    let
      inherit (config.core.ai.opencode) enable settings;
      pluginsCfg = config.core.ai.opencode.plugins;
    in
    lib.mkIf enable {
      opencode = {
        enable = true;
        settings = {
          agent = {
            explore.disable = true;
            plan.disable = true;
            build.disable = true;
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
      files = lib.mkIf pluginsCfg.handoff-audit-log.enable {
        ".opencode/plugins/handoff-audit-log.ts".text = builtins.readFile (
          config.core.workspace.root + "/tools/ai/plugins/handoff-audit-log/index.ts"
        );
      };
    };
}
