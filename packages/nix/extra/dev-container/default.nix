{
  config,
  lib,
  ...
}:
{
  options.extra.dev-container = {
    enable = lib.mkEnableOption "Enable github codespaces";
  };

  config =
    let
      opts = config.extra.dev-container;
    in
    lib.mkIf opts.enable {
      devcontainer = {
        enable = true;
        settings = {
          image = "ghcr.io/cachix/devenv/devcontainer:latest";
          customizations = { };
        };
      };
    };
}
