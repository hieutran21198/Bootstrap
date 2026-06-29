{
  config,
  lib,
  ...
}:
{
  options.core.ai.skills.dbRLSPatterns = {
    enable = lib.mkEnableOption "Row Level Security patterns for database operation.";
  };
  config =
    let
      aiOpts = config.core.ai;
      opts = aiOpts.skills.dbRLSPatterns;
      skillName = "rls-patterns";
      # Project-specific skill: the body is authored as plain markdown under
      # tools/ai/skills/<name>/SKILL.md (lintable, reviewable, version-controlled
      # next to the code it documents), and read verbatim here. Nix only links
      # it into the per-agent skill dirs — it does not own the prose. Generic,
      # reusable skills may instead inline their body in Nix.
      skillContent = builtins.readFile (
        config.core.workspace.root + "/tools/ai/skills/${skillName}/SKILL.md"
      );
    in
    lib.mkIf opts.enable {
      # Materialize the skill as a project-level SKILL.md per enabled agent.
      # devenv `files."<path>".text` writes a gitignored Nix-store symlink at
      # that path; `lib.optionalAttrs` keeps the entry absent (no empty file)
      # when the corresponding agent is disabled.
      #   - Claude Code scans `.claude/skills/<name>/SKILL.md` (plural only).
      #   - opencode scans `.opencode/skills/<name>/SKILL.md` (plural).
      files =
        (lib.optionalAttrs aiOpts.claude.enable {
          ".claude/skills/${skillName}/SKILL.md".text = skillContent;
        })
        // (lib.optionalAttrs aiOpts.opencode.enable {
          ".opencode/skills/${skillName}/SKILL.md".text = skillContent;
        });
    };
}
