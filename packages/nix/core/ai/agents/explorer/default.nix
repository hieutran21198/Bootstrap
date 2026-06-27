# DEPRECATED 2026-06-25. Claude Code v2.1.187 ships built-in agents
# (claude-code-guide · haiku, claude · inherit, Explore · haiku,
# general-purpose · inherit, Plan · inherit, statusline-setup · sonnet)
# and the workspace is migrating orchestration to Agent Teams:
#   https://code.claude.com/docs/en/agent-teams
# The explorer role is superseded by the built-in `Explore · haiku`.
# Disabled in devenv.nix; module retained so historical evaluation
# traces and old links keep resolving — re-enable only for a specific
# legacy workflow that has not yet been ported.
{
  config,
  lib,
  ...
}:
{
  options.core.ai.agents.explorer =
    let
      mkExtraPermissionsOption = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
      };
    in
    {
      enable = lib.mkEnableOption "Enable explorer AI-agent";
      consumedContributions = lib.mkOption {
        type = lib.types.nullOr (with lib.types; listOf str);
        default = null;
        description = ''
          Whitelist of `core.ai.tools.<name>` entries this agent renders.
          `null` (default) consumes every contribution whose `targetAgents`
          matches (which is the explorer's full-research appetite). A list
          restricts the agent to a subset — useful for focused agents that
          want only a slice of the workspace's contribution catalog.
        '';
      };
      claude = {
        extraPermissions = mkExtraPermissionsOption;
        model = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "opus"
              "sonnet"
              "haiku"
            ]
          );
          default = "haiku";
          description = "Model for the claude explorer agent. Matches claude.agents submodule enum.";
        };
      };
      opencode = {
        extraPermissions = mkExtraPermissionsOption;
        model = lib.mkOption {
          type = lib.types.str;
          default = "haiku";
          description = "Model for the opencode explorer agent.";
        };
      };
    };

  config =
    let
      aiOpts = config.core.ai;
      opts = aiOpts.agents.explorer;

      agentName = "explorer";
      registry = aiOpts.tools;

      # Agent owns identity, methodology, discipline. Modules own knowledge.
      # The agent declares which named section keys it consumes; each contribution
      # populates a subset of them. Anything not consumed by the agent is dead
      # weight at zero cost.
      consumedSections = [
        "inputs"
        "responsibilities"
        "toolGuidelines"
        "outputFormat"
      ];

      # Two-stage filter:
      #   1. Whitelist by name if `consumedContributions` is set (agent's appetite).
      #   2. Filter by `targetAgents` (contribution's audience).
      selectedRegistry =
        if opts.consumedContributions == null then
          registry
        else
          lib.filterAttrs (n: _: lib.elem n opts.consumedContributions) registry;

      applicable = lib.filter (c: c.targetAgents == [ ] || lib.elem agentName c.targetAgents) (
        lib.attrValues selectedRegistry
      );

      sortedContributions = lib.sort (a: b: a.order < b.order) applicable;

      # Strip trailing newlines so joining with "\n\n" yields a single blank
      # line between contributions instead of multiplying the trailing "\n"
      # that Nix multiline strings keep at their tail.
      stripTrailingNewlines =
        s: if s != "" && lib.hasSuffix "\n" s then stripTrailingNewlines (lib.removeSuffix "\n" s) else s;

      gatherSection =
        key:
        let
          nonEmpty = lib.filter (s: s != "") (
            map (c: stripTrailingNewlines (c.sections.${key} or "")) sortedContributions
          );
        in
        lib.concatStringsSep "\n\n" nonEmpty;

      sectionBodies = lib.genAttrs consumedSections gatherSection;

      contributedPermissions = lib.concatLists (map (c: c.permissions) sortedContributions);

      baseTools = [
        "Read"
        "Write"
        "Edit"
        "Grep"
        "Glob"
        "Bash"
        "TodoWrite"
        "WebFetch"
        "WebSearch"
      ];

      renderTools = items: lib.concatMapStringsSep "\n" (item: "  - ${item}") items;

      description = "[DEPRECATED — superseded by built-in `Explore · haiku`; migrate orchestration to Agent Teams (https://code.claude.com/docs/en/agent-teams)] Research agent that gathers task context and evidence across the codebase, the internet, available tools, MCP servers, and registered toolchains. Read-only: investigates and reports; never decides, never implements.";

      toolGuidelinesBody =
        if sectionBodies.toolGuidelines != "" then
          sectionBodies.toolGuidelines
        else
          "_No modules contributed tool guidelines. Only the base tool set (Read / Write / Edit / Grep / Glob / Bash / TodoWrite / WebFetch / WebSearch) applies._";

      promptBody = ''
        You are the Explorer.

        Your mission is to gather **task context and evidence** by researching across the codebase, the internet, available tooling and MCP servers, and any toolchains registered in the workspace AI registry. You return findings — never decisions, never implementations. The orchestrator decides; you investigate and report.

        ## Inputs

        The orchestrator's task description, the workspace, the internet, available CLIs and MCP servers, and the per-module contributions below.

        ${sectionBodies.inputs}

        ## Responsibilities

        ### Research methodology

        - **Codebase research.** Use `Read`, `Grep`, `Glob` to locate symbols, configs, and patterns. Cite paths and line numbers with quoted snippets in every claim.
        - **Tool & MCP research.** Inspect available CLIs (`which <tool>`, `<tool> --help`, `<tool> --version`). Document MCP server inputs / outputs when the task depends on them. Report tool / version information when relevant.
        - **Internet research.** Use `WebSearch` for "how do people solve X" patterns; `WebFetch` for the exact text of an authoritative document. Prefer official documentation → high-quality OSS → community articles → forums. Capture URLs verbatim with publication date when visible. **Never** paste API keys, credentials, internal hostnames, or PII into a search query.

        ${sectionBodies.responsibilities}

        ## Tool guidelines

        Each entry below is contributed by an enabled module via `core.ai.tools.<name>`. Use the listed commands in **read-only** mode unless the section explicitly says otherwise.

        ${toolGuidelinesBody}

        ## Constraints

        - **Read-only stance.** Investigate and report; never decide, never implement.
        - **Cite everything.** A claim without a `Read` / `Grep` / `Bash` / `Web` result (or a contributed command from *Tool guidelines*) behind it is speculation; flag it as `unconfirmed` if you must mention it.
        - **Stay in scope.** Don't branch into adjacent topics unless the orchestrator asks. Stop once sufficient evidence is gathered — over-exploration is failure, not diligence.
        - **Use `TodoWrite`** to track multi-step investigations so the orchestrator sees progress.

        ## Output format

        - Per finding: *claim · source (`path:line`, URL, or command) · short quoted evidence · confidence (`confirmed` / `likely` / `unconfirmed`)*.
        - For inline returns: bulleted list of findings with source links; group by responsibility area.

        ${sectionBodies.outputFormat}
      '';

      mkToolList = extraPermissions: lib.unique (baseTools ++ contributedPermissions ++ extraPermissions);

      # claude.agents takes a submodule with structured fields.
      claudeAgent = {
        inherit description;
        proactive = true;
        model = opts.claude.model;
        tools = mkToolList opts.claude.extraPermissions;
        prompt = promptBody;
        permissionMode = "default";
      };

      # opencode.agents takes a markdown string with YAML frontmatter.
      opencodeAgent = ''
        ---
        name: ${agentName}
        description: ${description}
        model: ${opts.opencode.model}
        tools:
        ${renderTools (mkToolList opts.opencode.extraPermissions)}
        ---

        ${promptBody}
      '';
    in
    lib.mkIf opts.enable {
      core.ai.claude.agents.explorer = lib.mkIf aiOpts.claude.enable claudeAgent;
      core.ai.opencode.agents.explorer = lib.mkIf aiOpts.opencode.enable opencodeAgent;
    };
}
