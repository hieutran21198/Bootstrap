{ config, ... }: {
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
    };
}
