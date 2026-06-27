{ lib, config, ... }: {
  imports = [
    ./agents/default.nix
    ./profiles/default.nix
  ];
  options.core.ai.opencode = {
    enable = lib.mkEnableOption "Enable opencode";
    profile = lib.mkOption {
      type =
        with lib.types;
        (enum [
          "max"
          "slim"
        ]);
      default = "slim";
      description = "Which opencode profile to use.";
    };
    slimPresets = lib.mkOption {
      type = with lib.types; attrsOf anything;
      default = { };
    };
  };
  config = lib.mkIf config.core.ai.opencode.enable {
    opencode = {
      enable = true;
    };
    env = {
      OPENCODE_CONFIG_DIR = config.core.workspace.root + "/.opencode";
      OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS = true;
    };
  };
}
