{
  extra = {
    dev-container = {
      enable = true;
    };
  };
  core = {
    ai = {
      agents = {
        explorer = {
          enable = true;
        };
        spec-writer = {
          enable = true;
        };
      };
      claude = {
        enable = true;
      };
    };
    workspace = {
      enable = true;
      name = "Bootstrap";
      treeInfos = {
        "README.md" = "Look at me first!";

        "docs" = "Documentation for ADRs, specs, conventions, glossary, findings, debt...";
        "docs/adrs" = "Architecture Decision Records";
        "docs/specs" = "Feature and system design documents";
        "docs/conventions" = "Workspace-wide rules and guidelines";
        "docs/glossary" = "Canonical terms and definitions";
        "docs/findings" = "Debugging investigations and research findings";
        "docs/debt" = "Technical debt register with encounter ledger";

        "packages" = "Public shared packages for the workspace";

        "services" = "Backend deployable services";
        "apps" = "User-facing applications by platform";

        "deploy" = "Deployment and infrastructure definitions";

        "tools" = "Workspace-wide development tools, generators, validators, and AI agent utilities";
        "tools/ai" = "AI agent prompts, presets, evals, and orchestration helpers";
        "tools/ai/skills" = "AI agent skills for specific tasks and workflows";
        "tools/generators" = "Code and document generators";
        "tools/validators" = "Workspace structure, documentation, and architecture validators";
        "tools/scripts" = "Development helper scripts not tied to deployment";
      };
    };
    docs = {
      enable = true;
    };
    git = {
      enable = true;
    };
    secrets = {
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
