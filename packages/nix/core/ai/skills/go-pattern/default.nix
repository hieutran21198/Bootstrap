{ config, ... }: {
  options.core.ai.skills.go-pattern =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption { default = true; };
      content = utils.makeStrOption {
        default = builtins.readFile (config.core.workspace.root + "/tools/ai/skills/go-pattern/SKILL.md");
        readOnly = true;
      };
    };
}
