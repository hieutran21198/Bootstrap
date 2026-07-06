{
  config,
  lib,
  ...
}:
{
  options.core.ai.utils.plan =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption {
        default = true;
        description = "Enable the plan utility";
      };
      planingAgents = utils.makeListOption {
        ofType = lib.types.str;
        default = [ ];
      };
    };
  config =
    let
      opts = config.core.ai.utils.plan;
    in
    {
      core.ai.opencode.settings.plugin = [
        [
          "@plannotator/opencode@latest"
          {
            workflow = "plan-agent";
            inherit (opts) planingAgents;
          }
        ]
      ];
    };
}
