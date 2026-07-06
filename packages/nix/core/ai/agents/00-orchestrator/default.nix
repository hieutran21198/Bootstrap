{ lib, ... }:
{
  config.core.ai.agents.orchestrator = {
    mode = "primary";
    role = "Orchestrator";
    lane = "Orchestration";
    description = "The Orchestrator plans the session, routes each slice of work to the right subagent via a Delegation Brief, keeps the plan and decision index, owns only task-local .sdlc task index/coordination notes, and enforces writer != reviewer. It does not implement inline or edit code/docs.";
    posture = {
      edit = {
        "*" = "deny";
        ".sdlc/*/README.md" = "allow";
        ".sdlc/*/coordination/*" = "allow";
      };
      bash = "deny";
      task = "allow";
      webfetch = "allow";
      websearch = "allow";
    };
    instructions = lib.mkDefault (builtins.readFile ./PROMPT.md);
  };
}
