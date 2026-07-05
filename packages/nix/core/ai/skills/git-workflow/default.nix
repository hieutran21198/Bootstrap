{
  config,
  lib,
  ...
}:
{
  options.core.ai.skills.git-workflow =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption { default = true; };
      content = utils.makeStrOption {
        default = builtins.readFile ./SKILL.md;
        readOnly = true;
      };
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [
          "backend-engineer"
          "release-engineer"
          "frontend-engineer"
          "scribe"
          "dev-environment"
        ];
        description = "Agents this skill is available to (allowed); every other agent is denied.";
      };
    };
}
