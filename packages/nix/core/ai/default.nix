{ lib, config, ... }:
{
  imports = [
    ./agents/default.nix
    (lib.mkAliasOptionModule [ "core" "ai" "claude" ] [ "claude" "code" ])
    (lib.mkAliasOptionModule [ "core" "ai" "opencode" ] [ "opencode" ])
  ];

  options.core.ai.tools = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          permissions = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ ];
            description = ''
              Strings appended to AI agents' tool list. May be plain tool names
              ("Read", "WebFetch") or granular permission specifiers
              ("Bash(aws:*)", "WebFetch(domain:example.com)") understood by the
              claude-code / opencode agent format.
            '';
            example = [
              "Bash(ws-info:*)"
              "Bash(aws:*)"
            ];
          };

          sections = lib.mkOption {
            type = with lib.types; attrsOf lines;
            default = { };
            description = ''
              Named markdown contributions to agent prompt sections. Each agent
              under `core/ai/agents/` declares which section keys it consumes
              (conventional keys: `inputs`, `responsibilities`, `toolGuidelines`,
              `outputFormat`); for each key the agent assembles all non-empty
              contributions from enabled modules in `order` ascending.

              Each section value should be terse markdown beginning with a
              `### <heading>` so multiple contributions render with stable
              structure. Empty values are skipped — contributors only declare
              keys they have something to say about.

              The set of legal keys is intentionally open: agents pick what
              they consume, and modules contribute what they own. Anything not
              consumed by any active agent is dead weight at zero cost.
            '';
            example = lib.literalExpression ''
              {
                inputs = '''
                  ### Workspace context
                  - `ws-info` prints workspace overview, layout, commands.
                ''';
                toolGuidelines = '''
                  ### Workspace tools
                  - `ws-tree` — directory tree with `.info` descriptions.
                ''';
              }
            '';
          };

          targetAgents = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ ];
            description = ''
              Agent names this contribution applies to. Empty list (default)
              means it applies to ALL agents that read the registry.
            '';
            example = [ "explorer" ];
          };

          order = lib.mkOption {
            type = lib.types.int;
            default = 100;
            description = ''
              Sort key for ordering contributions in the rendered prompt. Lower
              numbers render first. Conventional bands:
                0-29   foundation (workspace, git, docs)
                30-69  languages and standard toolchains
                70-99  specialised / cloud-side toolchains
                100+   ad-hoc additions
            '';
          };
        };
      }
    );
    default = { };
    description = ''
      Registry of tool permissions and prompt contributions that any workspace
      module can populate. Agents in `core/ai/agents/` consume this registry to
      assemble their final tool list and the contributed sections of their
      prompts. Each contribution is keyed by a descriptive name (e.g.
      "workspace", "docs", "aws", "go") so the source of each entry stays
      visible in evaluation traces.

      The registry is declarative only — populating it costs nothing for
      workspaces with no AI agent enabled. Modules contribute from inside
      their own `lib.mkIf cfg.enable { ... }` block; when a contributing
      module is disabled, its registry entry vanishes and dependent prompt
      sections shrink accordingly. This is the lego seam: agents own role,
      modules own knowledge, and the agent prompt is assembled at evaluation
      time from whatever modules are enabled.
    '';
  };
  config = {
    files."CLAUDE.md" = lib.mkIf config.core.ai.claude.enable {
      text = "@AGENTS.md";
    };
  };
}
