{ lib, ... }:
{
  config.core.ai.agents.explorer = {
    mode = "subagent";
    role = "Explorer";
    lane = "Exploration";
    description = "The Explorer agent maps this codebase: it locates files and symbols, traces call paths and data flow, and answers 'where/how does X work' within the repo. It may write only repo maps/traces in its allowed .sdlc research paths; it never edits code or durable docs.";
    capabilities = [
      "Locating files, symbols, and definitions"
      "Tracing call paths and data flow"
      "Surveying an area and summarizing its structure"
    ];
    delegateWhen = [
      "Answering 'where' or 'how does X work' within this repo"
      "Finding the blast radius of a change before editing"
      "Mapping an unfamiliar area of the codebase"
    ];
    avoidWhen = [
      "External or library research (use researcher)"
      "Making code edits"
    ];
    successCriteria = [
      "Returns exact file:line locations and call paths"
      "Provides a concise map of the relevant area"
      "Makes no edits"
    ];
    posture = {
      edit = {
        "*" = "deny";
        ".sdlc/*/research/*" = "allow";
        ".sdlc/*/learnings/*" = "allow";
      };
      bash = "deny";
      task = "deny";
      webfetch = "deny";
      websearch = "deny";
    };
    instructions = lib.mkDefault (builtins.readFile ./PROMPT.md);
  };
}
