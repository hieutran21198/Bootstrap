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

      # git-guard: the Go CLI that validates this workspace's Git conventions
      # (docs/conventions/git/). Shared by the hooks below and the PR-validation
      # CI workflow so the rules never drift between local and CI.
      gitGuardPkg = pkgs.buildGoModule {
        pname = "git-guard";
        version = "0.1.0";

        src = ../../../../tools;
        subPackages = [ "validators/git-guard" ];
        vendorHash = null;
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postInstall = ''
          wrapProgram $out/bin/git-guard --prefix PATH : ${lib.makeBinPath [ pkgs.git ]}
        '';
        meta.mainProgram = "git-guard";
      };
    in
    lib.mkIf opts.enable {
      packages = [
        pkgs.git
        gitGuardPkg
      ];

      core.workspace.toolchainCommandInfos = [
        {
          name = "git-guard";
          description = "Validate Git conventions (commit-msg / branch / pr-title) — docs/conventions/git/";
        }
      ];

      # Seed new commit messages with the Conventional Commits scaffold.
      # Set locally on shell entry so it needs no manual `git config`; the
      # `.gitmessage` body is version-controlled at the workspace root.
      enterShell = lib.mkIf (config.git.root == config.core.workspace.root) ''
        git config --local commit.template "${config.core.workspace.root}/.gitmessage"
      '';

      git-hooks = lib.mkIf (config.git.root == config.core.workspace.root) {
        hooks = {
          # Conventional Commits gate (commit-msg stage)
          commitizen.enable = true;

          # Git-convention gates via git-guard (docs/conventions/git/).
          # Stricter than commitizen: closed type set + subject style.
          git-guard-commit-msg = {
            enable = true;
            name = "git-guard: commit message";
            entry = "${lib.getExe gitGuardPkg} commit-msg";
            language = "system";
            stages = [ "commit-msg" ];
          };
          # Block direct commits to protected branches (main, release/*).
          git-guard-branch-protect = {
            enable = true;
            name = "git-guard: no direct commits to protected branches";
            entry = "${lib.getExe gitGuardPkg} branch-protect";
            language = "system";
            stages = [ "pre-commit" ];
            pass_filenames = false;
            always_run = true;
          };
          # Enforce branch naming on push.
          git-guard-branch-name = {
            enable = true;
            name = "git-guard: branch name";
            entry = "${lib.getExe gitGuardPkg} branch-name";
            language = "system";
            stages = [ "pre-push" ];
            pass_filenames = false;
            always_run = true;
          };

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
