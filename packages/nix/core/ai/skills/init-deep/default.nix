{ config, ... }: {
  options.core.ai.skills.init-deep =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption { default = true; };
      content = utils.makeStrOption {
        default = "";
        readOnly = true;
      };
    };
}
