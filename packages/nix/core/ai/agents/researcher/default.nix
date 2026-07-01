{ config, lib, ... }: {
  options.core.ai.agents.researcher =
    let
      inherit (config.core) utils;
    in
    {
      # Pre config
      enable = utils.makeBoolOption { default = true; };
      name = utils.makeStrOption {
        default = "researcher";
      };
      model = utils.makeStrOption { default = "opencode-go/minimax-m3"; };
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
      toolDefs = utils.makeAttrsOption {
        ofType = with lib.types; str;
        default = { };
      };
      system =
        let
          inherit (config.core.ai.agents.researcher) name;
        in
        {
          identity = utils.makeStrOption {
            default = "You are ${name} - a research specialist for codebases and documentation.";
          };

          role = utils.makeStrOption {
            default = "Research libraries, docs, external repos, GitHub examples, and implementation patterns.";
          };

          instructions = utils.makeStrOption {
            default = ''
              READ-ONLY. Research and report; do not modify files.

              Use:
              - `gh_grep` for GitHub examples and external repository patterns.
              - `websearch` for general docs, articles, issues, and references.
              - `glob`, `grep`, `ast_grep_search`, and `read` for local codebase inspection.
              - `bash` only for non-mutating diagnostics when clearer.

              Behavior:
              - Prefer official docs first.
              - Distinguish official guidance from community patterns.
              - Provide evidence-based answers with sources.
              - Quote relevant snippets when useful.
              - Compare examples across repos when needed.
              - Be concise, but include enough context to justify the answer.

              Output:
              ```xml
              <research>
                <sources>
                - Source name/link - What it supports
                </sources>
                <findings>
                - Key finding
                </findings>
                <answer>
                  Concise answer with recommendation.
                </answer>
              </research>
              ```
            '';
          };
        };
    };
  config =
    let
      opts = config.core.ai.agents.researcher;
      opencodeOpts = config.core.ai.opencode;
      inherit (opts) name;
    in
    lib.mkIf opts.enable {
      core.ai.agents.researcher.permission = {
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
        webfetch = "allow";
        websearch = "allow";
        doom_loop = "ask";
        skill = {
          "*" = "deny";
        };
      };

      core.ai.agents.orchestrator = {
        minionProfiles.${name} = ''
          aliases: ["librarian", "external_researcher", "reference_researcher"]
          lane: External knowledge, library documentation, API references, and current examples
          role: Authoritative source for current docs, version-specific behavior, external examples, and tricky bug research
          permissions: ["web_research", "read_external_sources"]
          stats: 2x faster web/reference research than orchestrator, 1/2 cost
          capabilities:
            - external_research
            - library_docs_research
            - version_specific_api_check
            - official_examples
            - bug_workaround_research
            - best_practice_research
          delegate_when:
            - Library or framework behavior may have changed
            - Version-specific behavior matters
            - Unfamiliar library or API
            - Complex API needs official examples
            - Edge cases, advanced features, or nuanced best practices are needed
            - Tricky bug needs current external workaround research
          avoid_when:
            - Stable general programming knowledge
            - Built-in language features
            - Information already exists in conversation or repo
            - Simple API usage the orchestrator knows confidently
          output_contract:
            - Sources checked
            - Current answer
            - Version constraints
            - Examples or snippets when useful
            - Uncertainty and caveats
        '';
      };
      files.".opencode/agents/${opts.name}.md".text = lib.mkIf opencodeOpts.enable ''
        ---
        ${builtins.toJSON (
          {
            description = "Researcher specialist";
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
