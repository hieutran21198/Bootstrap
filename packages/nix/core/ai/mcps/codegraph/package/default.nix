{
  config,
  pkgs,
  lib,
  ...
}:
let
  codegraphVersion = "1.1.6";
  codegraphSrcs = {
    "x86_64-linux" = {
      target = "linux-x64";
      hash = "sha256-+rfx9stB8oJkiLRBHy68Ntp5km0ryg04IPT1EKvP0UM=";
    };
    "aarch64-linux" = {
      target = "linux-arm64";
      hash = "sha256-/AvIClQh63x0FmYcn4cifSXWyN6O+S7IKodnd1rtfDo=";
    };
    "x86_64-darwin" = {
      target = "darwin-x64";
      hash = "sha256-fdFZVSDXZNzpVfO8VIBkqK0QDfrQfgfKW+F4vp3q/DM=";
    };
    "aarch64-darwin" = {
      target = "darwin-arm64";
      hash = "sha256-NY8FbDA7feeND2fGGIk9I/WIAIkFxtwtrk01nFTFX4g=";
    };
  };
  codegraphSrc =
    codegraphSrcs.${pkgs.stdenv.hostPlatform.system}
      or (throw "codegraph: unsupported platform '${pkgs.stdenv.hostPlatform.system}'");
  codegraphPkg = pkgs.stdenvNoCC.mkDerivation {
    pname = "codegraph";
    version = codegraphVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/colbymchenry/codegraph/releases/download/v${codegraphVersion}/codegraph-${codegraphSrc.target}.tar.gz";
      inherit (codegraphSrc) hash;
    };
    sourceRoot = "codegraph-${codegraphSrc.target}";
    nativeBuildInputs = [ pkgs.makeWrapper ];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/lib/codegraph"
      cp -r lib/. "$out/lib/codegraph/"
      makeWrapper ${pkgs.nodejs_24}/bin/node "$out/bin/codegraph" \
        --add-flags "--liftoff-only $out/lib/codegraph/dist/bin/codegraph.js"
      runHook postInstall
    '';
    meta = {
      description = "Pre-indexed code knowledge graph + MCP server (run on nixpkgs nodejs_24)";
      homepage = "https://github.com/colbymchenry/codegraph";
      license = lib.licenses.mit;
      mainProgram = "codegraph";
      platforms = builtins.attrNames codegraphSrcs;
    };
  };
in
{
  config = lib.mkIf config.core.ai.mcps.codegraph.enable {
    packages = [ codegraphPkg ];
  };
}
