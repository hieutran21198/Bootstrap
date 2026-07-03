{
  config,
  lib,
  pkgs,
  ...
}:
let
  utils = config.core.utils;
  cfg = config.core.worktree;
  markerPath = config.git.root + "/${cfg.markerFileName}";
  markerExists = builtins.pathExists markerPath;
  markerRaw = if markerExists then builtins.readFile markerPath else "0";
  markerTrimmed = lib.strings.trim markerRaw;
  markerSyntaxValid = builtins.match "[0-9]+" markerTrimmed != null;
  parsedOffset = if markerSyntaxValid then builtins.fromJSON markerTrimmed else 0;
  offsetValid = markerSyntaxValid && parsedOffset >= 0 && lib.mod parsedOffset cfg.portStride == 0;

  wsWorktreePkg = pkgs.buildGoModule {
    pname = "ws-worktree";
    version = "0.1.0";

    src = ../../../../tools;
    subPackages = [ "generators/ws-worktree" ];
    vendorHash = null;
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postInstall = ''
      wrapProgram $out/bin/ws-worktree --prefix PATH : ${
        lib.makeBinPath [
          pkgs.git
          config.core.git.gitGuardPackage
        ]
      }
    '';
    meta.mainProgram = "ws-worktree";
  };
in
{
  options.core.worktree = {
    enable = lib.mkEnableOption "Git worktree tooling and port-offset support.";
    markerFileName = utils.makeStrOption {
      default = ".worktree-offset";
      description = "Name of the root marker file containing the worktree port offset.";
    };
    portStride = utils.makeIntOption {
      default = 10;
      description = "Port offset stride between managed worktree slots.";
    };
    portOffset = utils.makeIntOption {
      readOnly = true;
      default = if cfg.enable then parsedOffset else 0;
      description = "Port offset read from the current worktree marker file.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (utils.failWhen {
        condition = cfg.portStride <= 0;
        message = "core.worktree.portStride must be greater than zero.";
      })
      (utils.failWhen {
        condition = !offsetValid;
        message = "Invalid .worktree-offset: content must be an integer >= 0 and divisible by core.worktree.portStride.";
      })
    ];

    packages = [ wsWorktreePkg ];

    core.workspace.toolchainCommandInfos = [
      {
        name = "ws-worktree";
        description = "Create, list, and remove managed parallel-agent Git worktrees.";
      }
    ];
  };
}
