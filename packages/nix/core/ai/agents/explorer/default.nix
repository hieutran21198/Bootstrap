{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.core.ai.agents.explorer =
    let
      inherit (config.core) utils;
    in
    {
      # Pre config
      enable = utils.makeBoolOption { default = true; };
      name = utils.makeStrOption {
        default = "explorer";
      };
      model = utils.makeStrOption { default = "opencode-go/minimax-m3"; };
      contextSize = utils.makeIntOption { default = 0; };
      variant = utils.makeStrOption { default = ""; };
      temperature = utils.makeFloatOption { default = 0.1; };
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
        default = [ ];
      };
      system =
        let
          inherit (config.core.ai.agents.explorer) name;
        in
        {
          identity = utils.makeStrOption {
            default = "You are ${name} - a fast codebase navigation specialist.";
          };
          role = utils.makeStrOption {
            default = ''
              ''\nQuick contextual codebase navigation specialist.

              Use this agent to answer questions like:
              - Where is X?
              - Find Y.
              - Which file has Z?
              - Where is this behavior implemented?
              - What files define or reference this symbol?
            '';
          };
          instructions = utils.makeStrOption {
            default = ''
              ''\nREAD-ONLY. Search and report; do not modify files.

              Use:
              - `grep` for text, regex, strings, comments, variable names, errors.
              - `ast_grep_search` for structural code patterns.
              - `glob` for file names, extensions, and folders.
              - `read` only after discovery for needed context.
              - `bash` only for non-mutating diagnostics when clearer.

              Behavior:
              - Be fast, thorough, and concise.
              - Run multiple searches when useful.
              - Return paths, line numbers, and short snippets/descriptions.
              - Say clearly when nothing relevant is found.

              Output:
              ```xml
                <results>
                  <files>
                  - /path/to/file.ts:42 - Brief description
                  </files>
                  <answer>
                    Concise answer.
                  </answer>
                </results>
              ```
            '';
          };
        };
    };
  config =
    let
      opts = config.core.ai.agents.explorer;
      opencodeOpts = config.core.ai.opencode;
      inherit (opts) name;
    in
    lib.mkIf opts.enable {
      core.ai.agents.orchestrator = {
        minionProfiles.${name} = ''
          aliases: ["codebase_recon", "discoverer"]
          lane: Fast codebase reconnaissance returning compressed context
          role: Read-only codebase search and pattern discovery
          permissions: ["read_files"]
          stats: 2x faster codebase search than orchestrator, 1/2 cost
          capabilities:
            - codebase_discovery
            - file_map
            - symbol_search
            - pattern_search
            - ast_query
            - compressed_context_summary
          delegate_when:
            - Need to discover what exists before planning
            - Broad or uncertain codebase scope
            - Parallel searches can speed discovery
            - Need summarized map instead of full file contents
          avoid_when:
            - Exact path is already known and full contents are needed
            - Single specific lookup is faster directly
            - About to edit the target file
          output_contract:
            - Relevant paths
            - Symbols or patterns found
            - Short map of where logic lives
            - Gaps or uncertainty
        '';
      };

      packages = with pkgs; [ ast-grep ];

      files.".opencode/agents/${opts.name}.md".text = lib.mkIf opencodeOpts.enable ''
        ---
        ${builtins.toJSON (
          {
            description = "Codebase explorer";
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
