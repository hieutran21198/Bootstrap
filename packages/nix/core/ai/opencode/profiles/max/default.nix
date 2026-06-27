{ config, lib, ... }: {

  config =
    let
      opts = config.core.ai.opencode;
      inheritAgent =
        x:
        {
          inherit (x) model;
          fallback_models = x.fallbacks;
        }
        // lib.optionalAttrs (x.variant != null) { inherit (x) variant; };
    in
    lib.mkIf (opts.enable && opts.profile == "max") {
      opencode.settings = {
        plugin = [ "oh-my-openagent@latest" ];
      };
      files.".opencode/oh-my-openagent.json".json =
        let
          inherit (config.core.ai.opencode) agents;
        in
        {
          "$schema" =
            "https://raw.githubusercontent.com/code-yeongyu/oh-my-openagent/dev/assets/oh-my-opencode.schema.json";
          agents = {
            # stronger orchestrator
            sisyphus = inheritAgent agents.orchestrator;
            hephaestus = inheritAgent agents.worker;
            oracle = inheritAgent agents.architecturer;
            librarian = inheritAgent agents.researcher;
            explorer = inheritAgent agents.codeExplorer;
            multimodal-looker = inheritAgent agents.looker;

            # planning agents
            ## main - strategic planner
            prometheus = inheritAgent agents.orchestrator;
            ## analysis - identity hidden intentions, ambiguities
            metis = inheritAgent agents.orchestrator-minion;

            # planning -> orchestrator tasks
            # to-do list.
            atlas = inheritAgent agents.orchestrator-minion;
            # category-spawn executor.
            sysiphus-junior = inheritAgent agents.orchestrator-minion;
          };
        };
    };
}
