{ lib, config, ... }:
let
  inherit (config.core) utils;

  # ---- pure render helpers ------------------------------------------------
  bullets = xs: lib.concatMapStringsSep "\n" (x: "- ${x}") xs;

  delegationBrief = ''
    ```markdown
    # Delegation brief

    ## Task
    What the agent must do.

    ## Context
    Relevant background, constraints, files, decisions.

    ## Boundaries
    What the agent must not touch or decide.
    ```
  '';

  completionReport = ''
    ```markdown
    # Completion report

    ## Summary
    Short result.

    ## Work done
    Concrete actions taken.

    ## Verification
    Raw command output (tests / lint) proving the result.
    ```
  '';
in
{
  imports = [
    ./agents/default.nix
    ./skills/default.nix
    ./mcps/default.nix
    ./commands/default.nix
    ./opencode/default.nix
    (lib.mkAliasOptionModule [ "core" "ai" "claude" ] [ "claude" "code" ])
  ];

  # Unified agent submodule. Agents own identity, posture, and prose only.
  # Skills and MCPs are NOT set here — each capability module declares which
  # agents it is wired to (`core.ai.{skills,mcps}.<name>.agents`), and the
  # renderer below inverts those allow-lists into per-agent permission.
  options.core.ai = {
    agents = utils.makeAttrsOption {
      default = { };
      ofType = lib.types.submodule (
        { name, ... }:
        {
          options = {
            enable = lib.mkEnableOption "the ${name} agent";
            mode = utils.makeEnumOption {
              acceptedList = [
                "primary"
                "subagent"
              ];
              default = "subagent";
            };
            model = utils.makeStrOption { default = ""; };

            role = utils.makeStrOption { default = ""; };
            lane = utils.makeStrOption { default = ""; };
            description = utils.makeStrOption { default = ""; };
            capabilities = utils.makeListOption {
              ofType = lib.types.str;
              default = [ ];
            };
            delegateWhen = utils.makeListOption {
              ofType = lib.types.str;
              default = [ ];
            };
            avoidWhen = utils.makeListOption {
              ofType = lib.types.str;
              default = [ ];
            };
            successCriteria = utils.makeListOption {
              ofType = lib.types.str;
              default = [ ];
            };

            instructions = utils.makeStrOption { default = ""; };

            # Intrinsic safety baseline over built-in tools (edit/bash/task/…).
            posture = utils.makeAttrsOption {
              ofType = lib.types.str;
              default = { };
            };
          };
        }
      );
    };
  };

  config =
    let
      opencodeOpts = config.core.ai.opencode;
      claudeOpts = config.core.ai.claude;

      agents = config.core.ai.agents;
      skills = config.core.ai.skills;
      mcps = config.core.ai.mcps;

      enabledAgents = lib.filterAttrs (_: a: a.enable) agents;
      enabledSkills = lib.filterAttrs (_: s: s.enable or false) skills;
      enabledMcps = lib.filterAttrs (_: m: m.enable or false) mcps;

      # ---- global skill catalog (content on disk for both tools) ----------
      skillFiles = lib.concatMapAttrs (
        name: value:
        { }
        // lib.optionalAttrs claudeOpts.enable {
          ".claude/skills/${name}/SKILL.md".text = value.content;
        }
        // lib.optionalAttrs opencodeOpts.enable {
          ".opencode/skills/${name}/SKILL.md".text = value.content;
        }
      ) enabledSkills;

      # ---- invert capability allow-lists into per-agent views -------------
      agentMcps = name: lib.filterAttrs (_: m: lib.elem name m.agents) enabledMcps; # mcpName -> mcp
      agentToolDefs = name: lib.mapAttrs (_: m: m.toolDef) (agentMcps name); # mcpName -> desc
      agentSkillNames =
        name: lib.filter (n: lib.elem name enabledSkills.${n}.agents) (lib.attrNames enabledSkills);

      # ---- per-agent permission: posture + default-deny over managed caps --
      # A managed MCP/skill is denied for every agent NOT in its allow-list;
      # non-managed tools/skills keep opencode's default. No `*` catch-all.
      mcpPermission =
        name:
        lib.listToAttrs (
          lib.mapAttrsToList (
            _: m: lib.nameValuePair m.toolGlob (if lib.elem name m.agents then "allow" else "deny")
          ) enabledMcps
        );

      skillPermission =
        name:
        lib.listToAttrs (
          lib.mapAttrsToList (
            n: s: lib.nameValuePair n (if lib.elem name s.agents then "allow" else "deny")
          ) enabledSkills
        );

      agentPermission =
        name: a:
        a.posture
        // (mcpPermission name)
        // (lib.optionalAttrs (enabledSkills != { }) { skill = skillPermission name; });

      # ---- body sections --------------------------------------------------
      toolsSection =
        name:
        let
          td = agentToolDefs name;
        in
        lib.optionalString (td != { }) ''

          ## Tools

          ${lib.concatStringsSep "\n" (lib.mapAttrsToList (n: d: "- `${n}` — ${d}") td)}
        '';

      renderCard = name: a: ''
        ### ${a.role}

        Lane: ${a.lane}
        Description: ${a.description}

        Capabilities:
        ${bullets a.capabilities}

        Delegate when:
        ${bullets a.delegateWhen}

        Avoid when:
        ${bullets a.avoidWhen}

        Success criteria:
        ${bullets a.successCriteria}

        Tools:
        ${bullets (lib.attrNames (agentToolDefs name))}

        Skills:
        ${bullets (agentSkillNames name)}
      '';

      registeredAgents = lib.concatStringsSep "\n\n" (
        lib.mapAttrsToList renderCard (lib.filterAttrs (_: a: a.mode == "subagent") enabledAgents)
      );

      primarySection = ''

        ## Registered Agents

        ${registeredAgents}

        ## Communication Protocols

        When delegating work to another agent, always send a structured Delegation Brief.
        The receiving agent must return a structured Completion Report.

        Delegation Brief:

        ${delegationBrief}
      '';

      subagentSection = ''

        ## Communication Protocols

        When completing delegated work, always return a structured Completion Report.

        Completion Report:

        ${completionReport}
      '';

      frontmatter =
        name: a:
        let
          base = {
            description = a.description;
            mode = a.mode;
            permission = agentPermission name a;
          }
          // lib.optionalAttrs (a.model != "") { model = a.model; };
        in
        lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}: ${builtins.toJSON v}") base);

      agentFiles = lib.optionalAttrs opencodeOpts.enable (
        lib.concatMapAttrs (name: a: {
          ".opencode/agents/${name}.md".text = ''
            ---
            ${frontmatter name a}
            ---
            # ${a.role}

            ${a.instructions}
            ${toolsSection name}${if a.mode == "primary" then primarySection else subagentSection}
          '';
        }) enabledAgents
      );
    in
    {
      core.ai.claude = {
        settingsPath = config.core.workspace.root + "/.claude/settings.json";
      };

      files = (
        lib.optionalAttrs claudeOpts.enable {
          ".claude/settings.json".json = {
            env = {
              CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
            };
          };
          "CLAUDE.md" = {
            text = "@AGENTS.md";
          };
        }
        // skillFiles
        // agentFiles
      );
    };
}
