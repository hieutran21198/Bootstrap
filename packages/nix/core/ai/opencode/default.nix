{ lib, config, ... }: {
  imports = [ ./profiles/default.nix ];
  options.core.ai.opencode = {
    profile = lib.mkOption {
      type =
        with lib.types;
        (enum [
          "full"
          "openai"
          "slim-go"
          "slim-go-openai"
        ]);
      default = "full";
      description = "Which opencode profile to use.";
    };
    slimPresets = lib.mkOption {
      type = with lib.types; attrsOf anything;
      default = { };
    };
  };
  config = {
    env = {
      OPENCODE_CONFIG_DIR = config.core.workspace.root + "/.opencode";
      OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = true;
    };
  };
}
