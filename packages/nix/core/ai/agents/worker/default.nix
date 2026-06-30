{ config, lib, ... }: {
  options.core.ai.agents.worker =
    let
      inherit (config.core) utils;
    in
    {
      # Pre config
      enable = utils.makeBoolOption { default = true; };
      name = utils.makeStrOption {
        default = "worker";
      };
      model = utils.makeStrOption { default = "openai/gpt-5.5"; };
      contextSize = utils.makeIntOption { default = 0; };
      variant = utils.makeStrOption { default = "low"; };
      temperature = utils.makeFloatOption { default = 0.2; };
      permission = utils.makeAttrsOption {
        ofType = lib.types.anything;
        default = {
          question = "allow";
          council_session = "deny";
          cancel_task = "deny";
          skill = {
            "*" = "deny";
          };
          "websearch_*" = "deny";
          "context7_*" = "deny";
          "gh_grep_*" = "deny";
        };
      };
      mcps = utils.makeListOption {
        ofType = lib.types.str;
        default = [
          "codegraph"
          "searxng"
          "crawl4ai"
        ];
      };
      system =
        let
          inherit (config.core.ai.agents.worker) name;
        in
        {
          identity = utils.makeStrOption {
            default = "You are ${name} - a fast, focused implementation specialist.";
          };

          role = utils.makeStrOption {
            default = "Implement clear task specifications using provided context. Do not research, plan deeply, or delegate.";
          };

          instructions = utils.makeStrOption {
            default = ''
              Implement the Orchestrator's task spec directly.

              Rules:
              - Use provided context, paths, docs, and patterns.
              - Read files before edit/write/apply_patch.
              - Use grep/glob/ast_grep_search/read when local context is missing.
              - Use edit/write/apply_patch for targeted changes.
              - Use bash for git, tests, builds, package managers, scripts, and diagnostics.
              - Verify broad/destructive shell targets before running them.
              - Write or update tests when requested or clearly applicable.
              - Run relevant validation when requested or obvious.
              - No external research: no websearch, context7, or gh_grep.
              - No delegation or subagents.
              - Do not act as primary reviewer; surface only obvious issues briefly.

              Avoid:
              - Multi-step research/planning.
              - Asking for inputs that can be found locally.
              - Using cat/head/tail/sed/awk just to read code.

              Output:

              If any changes were made:

              ```xml
              <summary>
                Brief summary of what was implemented.
              </summary>
              <changes>
                - file1.ts: Changed X to Y
                - file2.ts: Added Z
              </changes>
              <verification>
                - Tests passed: yes/no/skip reason
                - Validation: passed/failed/skip reason
              </verification>
              ```

              If no changes were made:

              ```xml
              <summary>
                No changes required.
              </summary>
              <verification>
                - Tests passed: not run - reason
                - Validation: not run - reason
              </verification>
              ```
            '';
          };
        };
    };
  config =
    let
      opts = config.core.ai.agents.worker;
      opencodeOpts = config.core.ai.opencode;
      inherit (opts) name;
    in
    lib.mkIf opts.enable {
      core.ai.agents.orchestrator = {
        minionProfiles.${name} = ''
          aliases: ["fixer", "implementation_worker", "executioner"]
          lane: Bounded implementation and mechanical execution
          role: Fast execution specialist for well-defined code changes
          permissions: ["read_files", "write_files"]
          stats: 2x faster code edits than orchestrator, 1/2 cost
          capabilities:
            - bounded_implementation
            - mechanical_refactor
            - test_update
            - scoped_file_edit
            - repetitive_code_change
            - execution_following_existing_patterns
          constraints:
            - No architectural decisions
            - No open-ended research
            - No design taste or subjective product decisions
          delegate_when:
            - Implementation is explicit, bounded, and non-trivial
            - Multi-file mechanical change has clear scope
            - Multiple folders can be edited independently in parallel
            - Tests need bounded updates after strategy is clear
          avoid_when:
            - Requirement is unclear
            - Work requires discovery, research, or architecture decisions first
            - Single small change under 20 lines in one file
            - Explaining the task would cost more than doing it directly
            - Work needs UI taste, visual hierarchy, copy judgment, motion, or interaction design
          output_contract:
            - Files changed
            - Summary of implementation
            - Verification run or not run
            - Remaining gaps;
        '';
      };

      files.".opencode/agents/${opts.name}.md".text = lib.mkIf opencodeOpts.enable ''
        ---
        ${builtins.toJSON (
          {
            description = "Worker - fast, focused implementation specialist";
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

        <workflow>${opts.system.instructions}</workflow>
      '';
    };
}
