{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.core.secrets = {
    enable = lib.mkEnableOption "Enable secrets";
  };
  config =
    let
      opts = config.core.secrets;
    in
    lib.mkIf opts.enable {
      # secretspec = {
      #   enable = true;
      #   profile = "local";
      #   provider = "protonpass://Project-Bootstrap";
      # };
    };
}
