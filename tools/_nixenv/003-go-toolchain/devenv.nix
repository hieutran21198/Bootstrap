{
  pkgs,
  config,
  lib,
  ...
}:
{
  options.go-toolchain = {
    package = lib.mkOption {
      type = with lib.types; package;
      default = config.languages.go.package or pkgs.go;
      description = "Path to the Go toolchain package.";
    };
  };
  config =
    let
      goPkg = config.go-toolchain.package;
    in
    {
      workspace = {
        toolchainCommandInfos = [ "go-info \t# ${config.scripts.go-info.description}" ];
      };

      packages = with pkgs; [
        golangci-lint
        gotools
      ];

      scripts = {
        go-info = {
          exec = ''
            $(${lib.getExe goPkg} version)
            ${lib.getExe goPkg} env
          '';
          description = "Go toolchain information";
        };
      };

      languages = {
        go = {
          enable = true;
          delve = {
            enable = true;
          };
          lsp = {
            enable = true;
          };
          enableHardeningWorkaround = true;
          version = "1.26.3";
        };
      };
    };
}
