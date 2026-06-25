{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.core.toolchains.terraform = {
    enable = lib.mkEnableOption "Enable terraform";
  };
  config = {
    packages = with pkgs; [ ];
  };
}
