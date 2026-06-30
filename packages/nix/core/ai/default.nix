{ lib, config, ... }:
{
  imports = [
    ./agents/default.nix
    ./skills/default.nix
    ./opencode/default.nix
    (lib.mkAliasOptionModule [ "core" "ai" "claude" ] [ "claude" "code" ])
  ];
  config = {
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
    };
  };
}
