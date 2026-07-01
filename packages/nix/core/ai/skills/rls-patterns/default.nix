{ config, ... }: {
  options.core.ai.skills.rls-patterns =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption { default = true; };
      content = utils.makeStrOption {
        default = builtins.readFile (config.core.workspace.root + "/tools/ai/skills/rls-patterns/SKILL.md");
        readOnly = true;
      };
    };
}
