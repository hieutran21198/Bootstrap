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
    };
  config =
    let
      opts = config.core.ai.mcps.codegraph;
      opencodeOpts = config.core.ai.opencode;

      # One-line description advertised to agents via their `toolDefs` → <tools>
      # prompt section. Subagents don't receive codegraph's MCP `initialize`
      # guidance, so this is how they learn the tool exists and when to use it.
      codegraphToolDef = "pre-indexed code graph — call codegraph_explore to get the relevant symbols' verbatim source, call paths, and change blast-radius in one shot; prefer it over grep/glob/read for understanding structure, callers/callees, and impact.";
    in
    lib.mkIf opts.enable {
      core.ai.agents = {
        # Code-intelligence tool: grant codegraph_explore to the code-focused agents,
        # advertise it via each agent's toolDefs -> <tools> prompt section, and ensure
        # `mcps` membership. orchestrator + explorer have an empty `mcps` default, so
        # push membership here.
        orchestrator = {
          permission."codegraph_*" = "allow";
          mcps = [ "codegraph" ];
          toolDefs."codegraph" = codegraphToolDef;
        };
        explorer = {
          permission."codegraph_*" = "allow";
          mcps = [ "codegraph" ];
          toolDefs."codegraph" = codegraphToolDef;
        };
        # All code-focused agents get codegraph membership pushed here; agent mcps
        # defaults are empty so explicit MCP-module definitions are the source of truth.
        architecturer = {
          permission."codegraph_*" = "allow";
          mcps = [ "codegraph" ];
          toolDefs."codegraph" = codegraphToolDef;
        };
        worker = {
          permission."codegraph_*" = "allow";
          mcps = [ "codegraph" ];
          toolDefs."codegraph" = codegraphToolDef;
        };
        designer = {
          permission."codegraph_*" = "allow";
          mcps = [ "codegraph" ];
          toolDefs."codegraph" = codegraphToolDef;
        };
        # researcher is external-docs / web focused — deny the local-code tool.
        researcher.permission."codegraph_*" = "deny";
      };
      opencode = lib.mkIf opencodeOpts.enable {
        settings = {
          mcp = {
            "codegraph" = {
              type = "local";
              command = [
                "codegraph"
                "serve"
                "--mcp"
              ];
            };
          };
        };
      };
    };
}
