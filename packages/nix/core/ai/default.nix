{ lib, config, ... }:
{
  imports = [
    ./agents/default.nix
    ./skills/default.nix
    ./mcps/default.nix
    ./commands/default.nix
    ./opencode/default.nix
    (lib.mkAliasOptionModule [ "core" "ai" "claude" ] [ "claude" "code" ])
  ];
  config =
    let
      inherit (config.core.ai) skills;
      opencodeOpts = config.core.ai.opencode;
      claudeOpts = config.core.ai.claude;
      enabledSkills = lib.filterAttrs (_: value: value.enable or false) skills;
      skillFiles = lib.concatMapAttrs (name: value: {
        ".claude/skills/${name}/SKILL.md".text = lib.mkIf claudeOpts.enable value.content;
        ".opencode/skills/${name}/SKILL.md".text = lib.mkIf opencodeOpts.enable value.content;
      }) enabledSkills;
    in
    {
      core.ai.claude = {
        settingsPath = config.core.workspace.root + "/.claude/settings.json";
      };
      files = {
        ".claude/settings.json".json = lib.mkIf config.core.ai.claude.enable {
          env = {
            CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
          };
        };
        "CLAUDE.md" = lib.mkIf config.core.ai.claude.enable {
          text = "@AGENTS.md";
        };
      }
      // skillFiles;
    };
}
