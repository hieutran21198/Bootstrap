{ lib, config, ... }: {
  imports = [
    ./openai/default.nix
    ./slim-go/default.nix
    ./slim-go-openai/default.nix
  ];
  config =
    let
      opts = config.core.ai.opencode;
    in
    {
      opencode.settings = {
        plugin =
          if opts.profile == "full" then [ "oh-my-openagent@latest" ] else [ "oh-my-opencode-slim@latest" ];
      };
      files.".opencode/oh-my-opencode-slim.json".json = lib.mkIf (opts.profile != "full") {
        "$schema" = "https://unpkg.com/oh-my-opencode-slim@latest/oh-my-opencode-slim.schema.json";
        showStartupToast = false;
        companion = {
          enabled = true;
          position = "bottom-left";
          size = "small";
        };
        preset = opts.profile;
        presets = { } // opts.slimPresets;
      };
    };
}
