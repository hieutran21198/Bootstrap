{
  config,
  lib,
  ...
}:
{
  imports = [ ./package/default.nix ];
  options.core.ai.mcps.codegraph =
    let
      inherit (config.core) utils;
    in
    {
      enable = utils.makeBoolOption {
        default = true;
      };
      agents = utils.makeListOption {
        ofType = lib.types.str;
        default = [
          "orchestrator"
          "explorer"
          "architect"
          "backend-engineer"
          "release-engineer"
          "frontend-engineer"
        ];
        description = "Agents this MCP is wired to (allowed); every other agent is denied.";
      };
      # One-line description advertised to agents via their `toolDefs` → <tools>
      # prompt section. Subagents don't receive codegraph's MCP `initialize`
      # guidance, so this is how they learn the tool exists and when to use it.
      toolDef = utils.makeStrOption {
        default = "pre-indexed code graph — call codegraph_explore to get the relevant symbols' verbatim source, call paths, and change blast-radius in one shot; prefer it over grep/glob/read for understanding structure, callers/callees, and impact.";
      };
      toolGlob = utils.makeStrOption {
        default = "codegraph_*";
      };
    };
  config =
    let
      opts = config.core.ai.mcps.codegraph;
      opencodeOpts = config.core.ai.opencode;
    in
    lib.mkIf opts.enable {
      opencode = lib.mkIf opencodeOpts.enable {
        settings.mcp.codegraph = {
          type = "local";
          command = [
            "codegraph"
            "serve"
            "--mcp"
          ];
        };
      };
    };
}
