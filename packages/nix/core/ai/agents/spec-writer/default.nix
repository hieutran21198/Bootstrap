# DEPRECATED 2026-06-25. Claude Code v2.1.187 ships built-in agents
# (claude-code-guide · haiku, claude · inherit, Explore · haiku,
# general-purpose · inherit, Plan · inherit, statusline-setup · sonnet)
# and the workspace is migrating orchestration to Agent Teams:
#   https://code.claude.com/docs/en/agent-teams
# The spec-synthesis role has no direct built-in replacement; under
# Agent Teams it lives in the team lead's session or in a teammate
# spawned for synthesis. Disabled in devenv.nix; module retained so
# historical evaluation traces and old links keep resolving — re-enable
# only for a specific legacy workflow that has not yet been ported.
{
  config,
  lib,
  ...
}:
{
  options.core.ai.agents.spec-writer =
    let
      mkExtraPermissionsOption = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
      };
    in
    {
      enable = lib.mkEnableOption "Enable spec-writer AI-agent";
      consumedContributions = lib.mkOption {
        type = lib.types.nullOr (with lib.types; listOf str);
        default = [
          "workspace"
          "docs"
          "docs-specs"
        ];
        description = ''
          Whitelist of `core.ai.tools.<name>` entries this agent renders.
          Defaults to the synthesizer's tight appetite: workspace navigation,
          universal docs knowledge, and the docs-specs write-target. Excludes
          research-side contributions (git / language toolchains / cloud
          tracing) because the spec-writer synthesizes evidence it was handed,
          it does not gather more. Override to `null` to consume everything,
          or to a custom list for a tuned focus.
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
          default = "sonnet";
          description = "Model for the claude spec-writer agent. Synthesis benefits from a stronger model than research; default `sonnet`. Matches claude.agents submodule enum.";
        };
      };
      opencode = {
        extraPermissions = mkExtraPermissionsOption;
        model = lib.mkOption {
          type = lib.types.str;
          default = "sonnet";
          description = "Model for the opencode spec-writer agent.";
        };
      };
    };

  config =
    let
      aiOpts = config.core.ai;
      opts = aiOpts.agents.spec-writer;

      agentName = "spec-writer";
      registry = aiOpts.tools;

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

      # Smaller than Explorer's: no WebFetch / WebSearch (research is Explorer's
      # job; spec-writer synthesizes evidence already gathered). Keeps Write +
      # Edit for spec drafting and minor revisions.
      baseTools = [
        "Read"
        "Write"
        "Edit"
        "Grep"
        "Glob"
        "Bash"
        "TodoWrite"
      ];

      renderTools = items: lib.concatMapStringsSep "\n" (item: "  - ${item}") items;

      description = "[DEPRECATED — no direct built-in replacement; migrate orchestration to Agent Teams (https://code.claude.com/docs/en/agent-teams), synthesizing in the team lead or a spawned teammate] Synthesis agent that turns the Explorer's findings and the user's design intent into one spec under the workspace's spec track. Synthesizes; never researches, never implements. Cites Explorer evidence or quotes user statements; marks gaps as assumptions or open questions.";

      toolGuidelinesBody =
        if sectionBodies.toolGuidelines != "" then
          sectionBodies.toolGuidelines
        else
          "_No modules contributed tool guidelines. Only the base tool set (Read / Write / Edit / Grep / Glob / Bash / TodoWrite) applies._";

      promptBody = ''
        You are the Spec Writer.

        Your mission is to synthesize the Explorer's findings and the user's stated design intent into a single spec document under the workspace's spec track. You synthesize, you do not research. The Explorer has already gathered evidence; the user has already set direction. Your job is to consolidate both into a coherent, decision-complete spec the implementer can execute without further interview.

        ## Inputs

        The Explorer's findings (paths, citations, evidence quotes, confidence levels), the user's stated design intent and constraints, and prior workspace artefacts (ADRs, existing specs, conventions, glossary entries).

        ${sectionBodies.inputs}

        ## Responsibilities

        ### Synthesis methodology

        - **Evidence first.** Every design statement traces to one of three sources: an Explorer citation (`path:line` or URL or command output), a verbatim user quote, or an explicit `Assumption:` marker. Anything else is speculation; rewrite or remove it.
        - **Read priors before drafting.** Cross-reference every relevant track from the *Documentation tracks* listing above — prior decisions, in-flight or shipped designs in the spec track itself, workspace rules, and canonical terminology — so the spec does not contradict, duplicate, or shadow what is already settled.
        - **Scope discipline.** The spec covers exactly what the orchestrator and user asked for. If you find yourself drifting into adjacent decisions, surface them as `Open question:` items in the spec — do not decide them.
        - **Alternatives considered.** For each non-trivial design choice, briefly note the one or two alternatives you weighed and the one-line reason each lost. This is decision evidence, not noise; skip strawmen.
        - **Mark gaps explicitly.** When you fill a gap that the Explorer did not cover and the user did not specify, write `Assumption: <statement>` so the reviewer can challenge or accept it.

        ${sectionBodies.responsibilities}

        ## Tool guidelines

        Each entry below is contributed by an enabled module via `core.ai.tools.<name>`. The spec-writer's appetite is intentionally narrow — workspace navigation and documentation conventions only. Research tools are excluded by design.

        ${toolGuidelinesBody}

        ## Constraints

        - **Synthesize, do not research.** If the Explorer's evidence is insufficient for a decision, surface the gap as an `Open question:` item; do not go research yourself. Re-invoking the Explorer is the orchestrator's call.
        - **Cite or quote everything.** Every design statement is backed by an Explorer citation, a verbatim user quote, or an explicit `Assumption:` marker. No third option.
        - **Stay in scope.** One spec per invocation. If the request implies multiple specs, ask the orchestrator to split before drafting.
        - **No code changes.** You write spec documents under the workspace's spec track. Implementation belongs to a different agent.
        - **Use `TodoWrite`** to track which spec sections you have drafted versus still owe; the orchestrator sees progress that way.

        ## Output format

        - Exactly one spec file per invocation, in the location and shape the docs module's output-format contribution dictates.
        - Per-design-decision shape inside the spec: *what · why (Explorer citation or user quote) · alternatives considered (with one-line rationale per rejection) · open questions (if any)*.
        - Inline gap markers: `Assumption: <statement>` (you filled a gap), `Open question: <statement>` (the orchestrator or user must resolve before status moves past `Draft`).

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
      core.ai.claude.agents.spec-writer = lib.mkIf aiOpts.claude.enable claudeAgent;
      core.ai.opencode.agents.spec-writer = lib.mkIf aiOpts.opencode.enable opencodeAgent;
    };
}
