{
  extra = {
    dev-container = {
      enable = true;
    };
  };
  core = {
    ai = {
      claude = {
        enable = true;
      };
      opencode = {
        enable = true;
        profile = "max";
      };
      skills = {
        dbRLSPatterns = {
          enable = true;
          statements = {
            whenInvocation = [
              "Creating or modifying API routes that access the database"
              "Writing new/raw SQL scripts"
              "Working with user data, payments, subscriptions, or enrollments"
            ];
          };
        };
      };
    };
    workspace = {
      enable = true;
      name = "Bootstrap";
      wsInfoDeepLevel = 2;
      treeInfos = {
        "README.md" = "Look at me first!";

        "docs" =
          "Workspace-wide docs shared across services, packages, and deployment — ADRs, specs, conventions, glossary, findings, debt (service-specific docs live under services/<name>/docs/)";
        "docs/adrs" = "Architecture Decision Records";
        "docs/specs" = "Feature and system design documents";
        "docs/conventions" = "Workspace-wide rules and guidelines";
        "docs/glossary" = "Canonical terms and definitions";
        "docs/findings" = "Debugging investigations and research findings";
        "docs/debt" = "Technical debt register with encounter ledger";

        "packages" = "Public shared packages for the workspace";

        "services" = "Backend deployable services (each may carry its own docs/)";
        "services/portal" = "Portal backend";
        "apps" = "User-facing applications by platform";
        "apps/workspace-docs" = "Docusaurus site rendering workspace + service docs (public, read-only)";

        "deploy" = "Deployment and infrastructure definitions";

        "tools" = "Workspace-wide development tools, generators, validators, and AI agent utilities";
        "tools/ai" = "AI agent prompts, presets, evals, and orchestration helpers";
        "tools/ai/skills" = "AI agent skills for specific tasks and workflows";
        "tools/generators" = "Code and document generators";
        "tools/validators" = "Workspace structure, documentation, and architecture validators";
        "tools/scripts" = "Development helper scripts not tied to deployment";
      };
    };
    git = {
      enable = true;
    };
    toolchains = {
      aws = {
        enable = true;
      };
      markdown = {
        enable = true;
      };
      go = {
        enable = true;
        golangci-lint = {
          enable = true;
        };
        go-work = {
          enable = true;
          mods = [
            "./packages/go"
            "./services/portal"
            "./tools"
          ];
        };
      };
    };
  };
}
