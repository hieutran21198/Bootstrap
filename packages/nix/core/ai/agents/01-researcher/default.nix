{ lib, ... }:
{
  config.core.ai.agents.researcher = {
    mode = "subagent";
    role = "Researcher";
    lane = "Research";
    description = "The Researcher agent gathers external, library, and domain knowledge, evaluates options and trade-offs, and synthesizes sourced findings into clear recommendations. Read-only: it investigates, it does not change code.";
    capabilities = [
      "Library, framework, and API documentation lookup"
      "Option and trade-off evaluation"
      "Trend and impact analysis"
      "Synthesizing sourced findings into recommendations"
    ];
    delegateWhen = [
      "External, library, or domain knowledge is needed"
      "Deciding whether to adopt a tool, library, or approach"
      "Reading upstream docs or comparing alternatives"
    ];
    avoidWhen = [
      "Locating symbols or tracing flows in this repo (use explorer)"
      "Writing or editing code"
    ];
    successCriteria = [
      "Returns a Completion Report with sourced findings and an explicit recommendation"
      "Every claim cites a doc or source"
      "Makes no code changes"
    ];
    posture = {
      edit = "deny";
      bash = "deny";
      webfetch = "allow";
      websearch = "allow";
    };
    instructions = lib.mkDefault (builtins.readFile ./PROMPT.md);
  };
}
