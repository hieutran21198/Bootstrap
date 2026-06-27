{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.core.toolchains.aws = {
    enable = lib.mkEnableOption "Enable AWS toolchain";
  };
  config =
    let
      opts = config.core.toolchains.aws;
    in
    lib.mkIf opts.enable {
      packages = with pkgs; [
        awscli2
        aws-vault
      ];
    };
}
