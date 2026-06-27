{ pkgs, ... }:
{
  imports = [
    ./ai/default.nix
    ./docs/default.nix
    ./git/default.nix
    ./secrets/default.nix
    ./services/default.nix
    ./workspace/default.nix
    ./toolchains/default.nix
  ];
  options.core = {
  };
  config = {
    packages = with pkgs; [
      git
      jq
    ];
  };
}
