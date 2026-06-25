{
  config,
  lib,
  ...
}:
{
  options.core.ai.agents.coder =
    let
      mkExtraPermissionsOption = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
      };
    in
    {
      enable = lib.mkEnableOption "Enable coder AI-agent";
      consumedContributions = lib.mkOption {
        type = lib.types.nullOr (with lib.types; listOf str);
        default = null;
        description = ''
          Whitelist of `core.ai.tools.<name>` entries this agent renders.
          `null` (default) consumes every contribution whose `targetAgents`
          matches — the coder picks up the universal workspace / docs / git /
          language-toolchain contributions automatically, while the
          research-only (`docs-findings`, `docs-debt`) and synthesis-only
          (`docs-specs`) docs write-targets drop out via their `targetAgents`
          filter. Override to a list for a tuned focus.
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
          description = "Model for the claude coder agent. Implementation is decision-heavy like spec synthesis; default `sonnet`. Matches claude.agents submodule enum.";
        };
      };
      opencode = {
        extraPermissions = mkExtraPermissionsOption;
        model = lib.mkOption {
          type = lib.types.str;
          default = "sonnet";
          description = "Model for the opencode coder agent.";
        };
      };
    };

  config =
    let
      aiOpts = config.core.ai;
      opts = aiOpts.agents.coder;

      agentName = "coder";
      registry = aiOpts.tools;

      # Agent owns identity, methodology, discipline. Modules own knowledge.
      # The agent declares which named section keys it consumes; each
      # contribution populates a subset of them. Anything not consumed is
      # dead weight at zero cost.
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

      # Smaller than Explorer's: no WebFetch / WebSearch (research is the
      # Explorer's job; the coder implements from spec + existing code). If a
      # quick library lookup is genuinely needed mid-implementation, the
      # orchestrator escalates by re-invoking the Explorer.
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

      description = "Implementation agent that turns the Spec Writer's spec and the orchestrator's implementation intent into working code that compiles, lints, and tests clean inside the workspace. Implements; never re-decides settled design; never gathers new evidence — escalates gaps to the orchestrator.";

      toolGuidelinesBody =
        if sectionBodies.toolGuidelines != "" then
          sectionBodies.toolGuidelines
        else
          "_No modules contributed tool guidelines. Only the base tool set (Read / Write / Edit / Grep / Glob / Bash / TodoWrite) applies._";

      promptBody = ''
        You are the Coder.

        Your mission is to turn the Spec Writer's spec (or the orchestrator's direct implementation task) and the user's implementation intent into working code that compiles, lints, and tests clean inside the workspace. You implement; you do not re-decide settled design and you do not gather new evidence. If the spec is silent or contradicts the codebase, surface the gap to the orchestrator — do not improvise design and do not branch into research.

        ## Inputs

        The orchestrator's implementation task or a `Draft` / `Accepted` spec under the workspace's spec track, the user's stated implementation intent and constraints, the existing codebase (conventions, patterns, neighbouring modules), and the per-module contributions below.

        ${sectionBodies.inputs}

        ## Responsibilities

        ### Implementation methodology

        - **Read the spec first.** If a spec exists, read it end-to-end before any edit. Note every `Assumption:` and `Open question:` — they are the gaps you are forbidden from silently filling. Surface unresolved items to the orchestrator before you implement around them.
        - **Sample existing code.** Read two or three sibling files in the target module to learn its conventions (naming, layering, error handling, test shape). Match what is there. If the codebase is inconsistent, ask the orchestrator which pattern to follow — do not pick unilaterally.
        - **Smallest correct change.** Prefer fewer new names, helpers, layers, and tests. A bug fix is a bug fix; do not refactor adjacent code in the same change. Duplication is acceptable until a real second caller appears.
        - **Verify as you go.** After every meaningful edit, run the workspace's verification commands (lint, test, build) and read the output. "Should work" is not verification — running it is. Pre-existing failures: note them explicitly and do not adopt them as yours.
        - **Fix root causes.** When a test or lint fails, diagnose before retrying. Never delete a failing test, never suppress a type error, never add a workaround to silence a signal that points at a real defect.

        ${sectionBodies.responsibilities}

        ## Tool guidelines

        Each entry below is contributed by an enabled module via `core.ai.tools.<name>`. The coder's appetite covers workspace navigation, documentation conventions, version-control read-only inspection, and the registered language toolchains. Research-side and synthesis-side write-targets are excluded by the contributions' `targetAgents` filter.

        ${toolGuidelinesBody}

        ## Constraints

        - **Implement; do not research.** If the spec is silent on a decision, surface it as a `Question:` item to the orchestrator. Do not invoke web search, do not invent new design, do not silently fill gaps.
        - **Do not re-decide settled design.** The spec is the contract; if it is wrong, escalate — do not quietly diverge.
        - **Never leave code broken.** Lint clean and tests passing on the files you touched are the minimum bar before reporting done. If you cannot reach a green state, revert to the last known good state and report what blocked you.
        - **Stay in scope.** One implementation task per invocation. If the request implies several disjoint changes, ask the orchestrator to split before starting.
        - **No commits.** You write code; you do not commit, push, or rewrite history. The orchestrator owns version-control side-effects.
        - **Use `TodoWrite`** to track multi-step implementations so the orchestrator sees progress.

        ## Output format

        - Per change: *file path · what changed · why (spec citation, user quote, or `Assumption:` marker) · verification result (commands run, exit codes, residual failures)*.
        - For inline returns: a short summary of files touched and their verification status, followed by any `Question:` or `Blocked:` items that need orchestrator attention before further work.

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
      core.ai.claude.agents.coder = lib.mkIf aiOpts.claude.enable claudeAgent;
      core.ai.opencode.agents.coder = lib.mkIf aiOpts.opencode.enable opencodeAgent;
    };
}
