{ lib, ... }:
{
  config.core.ai.agents.security-reviewer = {
    mode = "subagent";
    role = "Security Reviewer";
    lane = "Security & Authz Review";
    description = "The Security Reviewer agent independently audits DB-touching changes for RLS policy correctness, tenant/system scoping, role/GUC contracts, and SystemReadCapability usage. It is non-writing and returns verdicts only.";
    capabilities = [
      "RLS policy and tenant-isolation review"
      "Tenant/system scope and transaction-local GUC contract audits"
      "Postgres role and privilege boundary checks"
      "SystemReadCapability usage review"
    ];
    delegateWhen = [
      "A change touches database access, migrations, RLS policies, or tenant-scoped data"
      "System-scope reads or SystemReadCapability usage need independent review"
      "Authorization or role/GUC contracts need a security-focused verdict"
    ];
    avoidWhen = [
      "Implementation, fixes, or test execution are needed"
      "General architecture review without RLS or authorization impact"
      "Durable finding write-ups are needed (route to Scribe through the orchestrator)"
    ];
    successCriteria = [
      "Returns a verdict with concrete inline findings tied to evidence"
      "Validates ADR-0008/0009/0011 RLS, role, GUC, and capability invariants"
      "Requires missing verification instead of running commands or editing code"
    ];
    posture = {
      edit = "deny";
      bash = "deny";
      task = "deny";
      webfetch = "deny";
      websearch = "deny";
    };
    instructions = lib.mkDefault (builtins.readFile ./PROMPT.md);
  };
}
