{
  config,
  lib,
  ...
}:
{
  options.core.toolchains.markdown = {
    enable = lib.mkEnableOption "Enable the core toolchain module for the development environment.";
  };
  config =
    let
      opts = config.core.toolchains.markdown;
    in
    lib.mkIf opts.enable {
      git-hooks.hooks = {
        trim_trailing_whitespace = {
          args = [ "--markdown-linebreak-ext=md" ];
        };
      };
      core = {
        workspace = {
          editorConfig = {
            "*.md" = {
              trim_trailing_whitespace = false;
            };
          };
        };
      };
    };
}
