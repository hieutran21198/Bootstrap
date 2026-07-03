{ config, lib, ... }: {
  options.core.ai.commands.init-deep =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption { default = true; };
    };
  config =
    let
      opts = config.core.ai.commands.init-deep;
      render = opts.enable && config.core.ai.opencode.enable && config.core.ai.skills.init-deep.enable;
    in
    lib.mkIf render {
      files.".opencode/command/init-deep.md".text = ''
        ---
        description: ${builtins.toJSON "Deep-init: regenerate this workspace's hierarchical AGENTS.md knowledge base via the init-deep skill"}
        agent: orchestrator
        ---
        Run `/init-deep` in this main session as the orchestrator.
        First invoke the skill tool exactly: `skill({ name: "init-deep" })`.
        After the skill loads, follow it as the source of truth.
        Treat these user arguments as the run request/scope: $ARGUMENTS
        Use TodoWrite and delegation per the skill; do not inline or duplicate the skill body here.
      '';
    };
}
