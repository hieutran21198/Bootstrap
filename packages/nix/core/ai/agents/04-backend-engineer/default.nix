{ lib, ... }:
{
  config.core.ai.agents.backend-engineer = {
    mode = "subagent";
    role = "Backend-Engineer";
    lane = "Go Backend";
    description = "The Backend-Engineer agent implements and refactors Go across packages/go, services/portal, and tools: repositories, migrations, echox servers, and database/RLS wiring.";
    capabilities = [
      "Implementing and refactoring Go"
      "Repositories, migrations, and echox servers"
      "Database and RLS wiring"
    ];
    delegateWhen = [
      "Implementing or refactoring Go in packages/go, services/portal, or tools"
      "Wiring repositories, migrations, or servers"
      "Database or RLS work"
    ];
    avoidWhen = [
      "Frontend or UI work (use frontend-engineer)"
      "Design decisions or ADRs (use architect)"
    ];
    successCriteria = [
      "Follows workspace Go conventions and SRP package shape"
      "lint-go and go test pass, with raw output returned"
      "RLS honored for database code"
    ];
    posture = {
      edit = {
        "*" = "deny";
        ".sdlc/*/evidence/*" = "allow";
        ".sdlc/*/learnings/*" = "allow";
        "packages/go/*" = "allow";
        "services/portal/*" = "allow";
        "tools/generators/*" = "allow";
        "tools/validators/*" = "allow";
      };
      bash = "allow";
      task = "deny";
      webfetch = "deny";
      websearch = "deny";
    };
    instructions = lib.mkDefault (builtins.readFile ./PROMPT.md);
  };
}
