{ ... }:
{
  # --------------------------------------------------------------------------
  # Git hooks (via cachix/git-hooks.nix - auto-installed on `devenv shell`)
  #   - Conventional Commits enforced on commit-msg
  #   - Secret / credential scanning on pre-commit
  #   - Basic repo hygiene
  # --------------------------------------------------------------------------
  git-hooks.hooks = {
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
      # Preserve markdown line breaks (matches .editorconfig).
      args = [ "--markdown-linebreak-ext=md" ];
    };
    mixed-line-endings.enable = true;
  };
}
