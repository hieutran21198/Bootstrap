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
    in
    lib.mkIf opts.enable {
    };
}
