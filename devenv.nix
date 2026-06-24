{
  pkgs,
  ...
}:
# main
{
  workspace = {
    name = "Bootstrap";
    mandatoryFolders = {
      "docs" = "Documentation for ADRs, specs, conventions, glossary...";
      "docs/adrs" = "Architecture Decision Records";
      "docs/specs" = "Feature and system design documents";
      "docs/conventions" = "Workspace-wide rules and guidelines";
      "docs/glossary" = "Canonical terms and definitions";

      "packages" = "Public shared packages for the workspace";

      "services" = "Backend deployable services";
      "apps" = "User-facing applications by platform";

      "deploy" = "Deployment and infrastructure definitions";

      "tools" = "Workspace-wide development tools, generators, validators, and AI agent utilities";
      "tools/ai" = "AI agent prompts, presets, evals, and orchestration helpers";
      "tools/generators" = "Code and document generators";
      "tools/validators" = "Workspace structure, documentation, and architecture validators";
      "tools/scripts" = "Development helper scripts not tied to deployment";
    };
  };

  packages = with pkgs; [
    # general
    git
    jq
  ];
}
