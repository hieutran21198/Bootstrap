{ config, lib, ... }: {
  options.core.ai.agents.designer =
    let
      inherit (config.core) utils;
    in
    {
      # Pre config
      enable = utils.makeBoolOption { default = true; };
      model = utils.makeStrOption { default = "opencode-go/kimi-k2.6"; };
      name = utils.makeStrOption {
        default = "designer";
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
          inherit (config.core.ai.agents.designer) name;
        in
        {
          identity = utils.makeStrOption {
            default = "You are ${name} - a frontend UI/UX specialist who creates and reviews polished user experiences.";
          };

          role = utils.makeStrOption {
            default = "Design, implement, and review cohesive UI/UX with strong visual direction and good usability.";
          };

          instructions = utils.makeStrOption {
            default = ''
              Create and review polished frontend experiences.

              Principles:
              - Respect existing design systems and component libraries.
              - Prefer Tailwind utilities when available.
              - Use custom CSS only when needed for stronger visual execution.
              - Choose a clear visual direction and commit to it.
              - Use distinctive typography, cohesive colors, strong spacing, depth, and focused motion.
              - Prefer one strong interaction over many scattered effects.
              - Keep wording grounded and normal; avoid jargon.

              Review:
              - Check usability, responsiveness, consistency, hierarchy, spacing, and polish.
              - Call out concrete UX issues and fixes.
              - Focus on what users actually see and feel.

              File work:
              - Use glob/grep/ast_grep_search for discovery.
              - Use read before edit/write/apply_patch.
              - Use bash for builds, tests, diagnostics, and safe automation.
              - Verify broad or destructive shell targets first.
              - Do not use cat/head/tail/sed/awk just to read code.

              Output:
              <design>
                <summary>
                  Brief summary of design work or review.
                </summary>
                <changes>
                  - file.tsx: Changed X to improve Y
                </changes>
                <notes>
                  Concrete UX/design notes.
                </notes>
                <verification>
                  - Validation: passed/failed/skip reason
                </verification>
              </design>
            '';
          };
        };
    };
  config =
    let
      opts = config.core.ai.agents.designer;
      opencodeOpts = config.core.ai.opencode;
      inherit (opts) name;
    in
    lib.mkIf opts.enable {
      core.ai.agents.designer.permission = {
        question = "allow";
        cancel_task = "deny";
        council_session = "deny";
        read = "allow";
        glob = "allow";
        grep = "allow";
        list = "allow";
        lsp = "allow";
        edit = "allow";
        bash = "ask";
        task = "deny";
        todowrite = "allow";
        external_directory = "ask";
        webfetch = "deny";
        websearch = "deny";
        doom_loop = "ask";
        skill = {
          "*" = "deny";
          "ce-polish" = "allow";
          "ce-dogfood" = "allow";
        };
      };

      core.ai.agents.orchestrator = {
        minionProfiles."${name}" = ''
          aliases: ["ui_designer", "ux_designer", "design_reviewer"]
          lane: UI/UX design, related edits, design polish, and design review
          role: UI/UX specialist for user-facing interfaces, visual polish, interaction quality, responsive layouts, and design-system consistency
          permissions: ["read_files", "write_files"]
          stats: 10x better UI/UX design quality than orchestrator
          capabilities:
            - ui_ux_design
            - ui_ux_review
            - visual_polish
            - interaction_design
            - responsive_layout
            - design_system_consistency
            - user_facing_component_design
            - animation_microinteraction
            - landing_marketing_page_design
            - design_intent_preserving_implementation
          owns:
            - layout
            - hierarchy
            - spacing
            - motion
            - affordances
            - responsive behavior
            - overall feel
          constraints:
            - Weak at copywriting
            - Must use grounded, normal wording for UI copy
            - Should not own backend or headless logic decisions
            - Should not be asked only for advice when the required result is a visual implementation
          routing_note:
            - Do not ask this profile only how the UI should look and then implement it yourself when the task needs polished UI/UX execution.
            - Ask this profile to design and implement the UI/UX changes within its write scope.
            - After design work returns, orchestrator may review and improve copy without changing visual or interaction intent.
          delegate_when:
            - User-facing interface needs polish
            - Responsive layout work is required
            - UX-critical component such as form, navigation, dashboard, onboarding, or settings is affected
            - Visual consistency or design system quality matters
            - Animation or micro-interaction quality matters
            - Landing page or marketing page needs aesthetic judgment
            - Functional UI needs to become polished and coherent
            - Existing UI/UX quality needs review
          avoid_when:
            - Backend or business logic with no visual surface
            - Headless or purely functional implementation
            - Quick prototype where design quality does not matter yet
            - Copy-only change with no visual or interaction impact
          output_contract:
            - Files changed or reviewed
            - Design intent
            - Visual/interaction decisions made
            - Responsive behavior considered
            - Copy caveats, if any
            - Verification run or not run
        '';
      };
      files.".opencode/agents/${opts.name}.md".text = lib.mkIf opencodeOpts.enable ''
        ---
        ${builtins.toJSON (
          {
            description = "Frontend UI/UX specialist";
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
