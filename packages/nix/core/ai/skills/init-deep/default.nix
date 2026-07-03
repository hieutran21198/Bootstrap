{
  config,
  lib,
  ...
}:
{
  options.core.ai.skills.init-deep =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption { default = true; };
      content = utils.makeStrOption {
        default = builtins.readFile (config.core.workspace.root + "/tools/ai/skills/init-deep/SKILL.md");
        readOnly = true;
      };
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [ "orchestrator" ];
        description = "Agents this skill is available to (allowed); every other agent is denied.";
      };
    };
}
