{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.core.git = {
    enable = lib.mkEnableOption "Git";
  };
  config =
    let
      opts = config.core.git;
    in
    lib.mkIf opts.enable {
      packages = with pkgs; [ git ];

      git-hooks = lib.mkIf (config.git.root == config.core.workspace.root) {
        hooks = {
          # Conventional Commits gate (commit-msg stage)
          commitizen.enable = true;

          # Secret / credential scanning (pre-commit stage)
          detect-aws-credentials.enable = true;
          detect-private-keys.enable = true;
          ripsecrets.enable = true;
          trufflehog.enable = true;
          # Repo hygiene
          check-added-large-files = {
            enable = true;
            # 1 MB ceiling - accommodates pnpm-lock.yaml & similar lockfiles.
            args = [ "--maxkb=1024" ];
          };
          check-merge-conflicts.enable = true;
          end-of-file-fixer.enable = true;
          trim-trailing-whitespace = {
            enable = true;
          };
          mixed-line-endings.enable = true;
        };
      };
    };
}
