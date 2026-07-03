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
        default = builtins.readFile (config.core.workspace.root + "/tools/ai/skills/git-workflow/SKILL.md");
        readOnly = true;
      };
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [
          "backend-engineer"
          "release-engineer"
          "frontend-engineer"
          "scribe"
        ];
        description = "Agents this skill is available to (allowed); every other agent is denied.";
      };
    };
}
