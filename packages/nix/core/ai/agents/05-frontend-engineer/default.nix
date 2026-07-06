{ lib, ... }:
{
  config.core.ai.agents.frontend-engineer = {
    mode = "subagent";
    role = "Frontend-Engineer";
    lane = "Frontend / UI";
    description = "The Frontend-Engineer agent implements and refactors apps/ UI and drives browser-verified polish. Aspirational for now: apps/ is still a scaffold.";
    capabilities = [
      "Implementing and refactoring UI"
      "Browser-verified polish and QA"
    ];
    delegateWhen = [
      "Implementing or refactoring apps/ UI"
      "Browser-verified polish of a feature"
    ];
    avoidWhen = [
      "Go backend or domain logic (use backend-engineer)"
      "Design decisions or ADRs (use architect)"
    ];
    successCriteria = [
      "UI builds and renders"
      "Browser QA (playwright) passes"
      "Matches the design; tests green"
    ];
    posture = {
      edit = {
        "*" = "deny";
        ".sdlc/*/evidence/*" = "allow";
        ".sdlc/*/learnings/*" = "allow";
        "apps/*" = "allow";
      };
      bash = "allow";
      task = "deny";
      webfetch = "deny";
      websearch = "deny";
    };
    instructions = lib.mkDefault (builtins.readFile ./PROMPT.md);
  };
}
