{ lib, config, ... }: {
  options.core.ai.opencode = {
    enable = lib.mkEnableOption "Enable opencode";
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
