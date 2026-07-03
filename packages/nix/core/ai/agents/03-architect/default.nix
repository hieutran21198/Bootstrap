{ lib, ... }:
{
  config.core.ai.agents.architect = {
    mode = "subagent";
    role = "Architect";
    lane = "Design & Review";
    description = "The Architect agent makes and reviews design decisions: it weighs trade-offs, authors and validates ADRs and specs, defines boundaries, and serves as the independent review gate (writer != reviewer).";
    capabilities = [
      "Design and trade-off analysis"
      "Authoring and validating ADRs and specs"
      "Defining component and service boundaries"
      "Independent review of an implementer's output"
    ];
    delegateWhen = [
      "A design decision or trade-off must be made"
      "An ADR or spec must be produced or validated"
      "An implementer's output needs an independent review"
    ];
    avoidWhen = [
      "Bulk code implementation (use backend/frontend engineer)"
      "Pure fact or symbol lookup (use researcher/explorer)"
    ];
    successCriteria = [
      "Output matches the relevant docs/ track format, or a review verdict with concrete findings"
      "Decisions land in adrs/, designs in specs/, system views in architecture/"
    ];
    posture = {
      edit = "allow";
      bash = "deny";
    };
    instructions = lib.mkDefault (builtins.readFile ./PROMPT.md);
  };
}
