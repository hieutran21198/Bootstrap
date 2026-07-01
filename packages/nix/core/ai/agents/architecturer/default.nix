{ config, lib, ... }: {
  options.core.ai.agents.architecturer =
    let
      inherit (config.core) utils;
    in
    {
      # Pre config
      enable = utils.makeBoolOption { default = true; };
      model = utils.makeStrOption { default = "openai/gpt-5.5"; };
      name = utils.makeStrOption {
        default = "architecturer";
        readOnly = true;
      };
      contextSize = utils.makeIntOption { default = 0; };
      variant = utils.makeStrOption { default = ""; };
      temperature = utils.makeFloatOption { default = 0.1; };
      permission = utils.makeAttrsOption {
        ofType = lib.types.anything;
        default = { };
      };
      mcps = utils.makeListOption {
        ofType = lib.types.str;
        default = [ ];
      };
      # Per-tool, one-line descriptions advertised in the agent's <tools> prompt
      # section. MCP modules populate this (e.g. mcps/codegraph pushes
      # `toolDefs."codegraph"`), mirroring how context7 populates researcher.toolDefs.
      toolDefs = utils.makeAttrsOption {
        ofType = lib.types.str;
        default = { };
      };
      system =
        let
          inherit (config.core.ai.agents.architecturer) name;
        in
        {
          identity = utils.makeStrOption {
            default = "You are ${name} - a strategic technical advisor and code reviewer.";
          };

          role = utils.makeStrOption {
            default = "Advise on debugging, architecture, code review, simplification, and engineering tradeoffs.";
          };

          instructions = utils.makeStrOption {
            default = ''
              READ-ONLY. Advise and report; do not modify files.

              Focus:
              - Root-cause analysis.
              - Architecture decisions and tradeoffs.
              - Code review for correctness, performance, maintainability, and complexity.
              - YAGNI: prefer simpler designs unless complexity clearly pays for itself.
              - Debugging guidance when normal approaches fail.

              Use:
              - `glob`, `grep`, `ast_grep_search`, and `read` for codebase inspection.
              - `bash` only for non-mutating diagnostics when clearer.

              Avoid:
              - Implementation work.
              - Delegation.
              - Over-engineered recommendations.
              - Using cat/head/tail/sed/awk just to read code.

              Behavior:
              - Be direct, concise, and actionable.
              - Explain reasoning briefly.
              - Acknowledge uncertainty.
              - Point to specific files/lines when relevant.

              Output:
              <review>
              <findings>
              - Finding with file:line when relevant
              </findings>
              <recommendation>
              Concise recommendation with tradeoffs.
              </recommendation>
              </review>
            '';
          };
        };
    };
  config =
    let
      opts = config.core.ai.agents.architecturer;
      opencodeOpts = config.core.ai.opencode;
      inherit (opts) name;
    in
    lib.mkIf opts.enable {
      core.ai.agents.architecturer.permission = {
        question = "allow";
        cancel_task = "deny";
        council_session = "deny";
        read = "allow";
        glob = "allow";
        grep = "allow";
        list = "allow";
        lsp = "allow";
        edit = "deny";
        bash = "deny";
        task = "deny";
        todowrite = "deny";
        external_directory = "deny";
        webfetch = "deny";
        websearch = "deny";
        doom_loop = "ask";
        skill = {
          "*" = "deny";
          "ce-code-review" = "allow";
          "ce-doc-review" = "allow";
          "ce-pov" = "allow";
          "go-pattern" = "allow";
          "rls-patterns" = "allow";
        };
      };

      core.ai.agents.orchestrator = {
        minionProfiles."${name}" = ''
          aliases: ["reviewer", "architecture_reviewer"]
          lane: Architecture, risk, debugging strategy, and review
          role: Strategic advisor for high-stakes decisions, persistent problems, code review, simplification, and maintainability review
          permissions: ["read_files"]
          stats: 5x better decision maker/problem solver/investigator than orchestrator, 0.8x speed, same cost
          capabilities:
            - architecture_decision
            - system_tradeoff_analysis
            - complex_debugging_strategy
            - security_scalability_data_integrity_review
            - code_review
            - maintainability_review
            - simplification_review
            - yagni_review
          delegate_when:
            - Major architectural decision with long-term impact
            - Problem persists after 2 or more fix attempts
            - High-risk multi-system refactor
            - Costly trade-off such as performance versus maintainability
            - Complex debugging with unclear root cause
            - Security, scalability, or data integrity risk
            - Workflow requires a reviewer, senior architect, simplification review, or maintainability review
          avoid_when:
            - Routine decision the orchestrator can make confidently
            - First bug-fix attempt
            - Straightforward tactical "how" decision
            - Time-sensitive good-enough decision
            - Quick search or test can answer the question
          output_contract:
            - Findings
            - Risk assessment
            - Recommendation
            - Trade-offs
            - Required follow-up checks
        '';
      };
      files.".opencode/agents/${opts.name}.md".text = lib.mkIf opencodeOpts.enable ''
        ---
        ${builtins.toJSON (
          {
            description = "Strategic technical advisor and code reviewer";
            mode = "subagent";
            inherit (opts)
              model
              permission
              temperature
              mcps
              ;
          }
          // (lib.optionalAttrs (opts.contextSize != 0) {
            maxTokens = opts.contextSize;
          })
          // (lib.optionalAttrs (opts.variant != "") {
            variant = opts.variant;
          })
        )}
        ---
        <identity>${opts.system.identity}</identity>

        <role>${opts.system.role}</role>

        ${
          lib.optionalString (opts.toolDefs != { }) (
            "<tools>\n"
            + lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "- ${k}: ${v}") opts.toolDefs)
            + "\n</tools>\n\n"
          )
        }<workflow>${opts.system.instructions}</workflow>
      '';
    };
}
