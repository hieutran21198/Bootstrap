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
      packages = with pkgs; [ secretspec ];
    };
}
