{ config, ... }: {
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
        settings = {
          agent = {
            orchestrator = {
              model = "anthropic/claude-fable-5";
              variant = "high";
            };
            researcher = {
              model = "opencode-go/minimax-m3";
            };
            explorer = {
              model = "opencode-go/minimax-m3";
            };
            architect = {
              model = "openai/gpt-5.5";
              variant = "xhigh";
            };
            backend-engineer = {
              model = "openai/gpt-5.5";
              variant = "low";
            };
            release-engineer = {
              model = "openai/gpt-5.5";
              variant = "low";
            };
            frontend-engineer = {
              model = "openai/gpt-5.5";
              variant = "low";
            };
            scrible = {
              model = "anthropic/claude-sonnet-5";
              variant = "high";
            };
          };
        };
      };
      skills = {
        init-deep.enable = true;
        go-pattern.enable = true;
        git-workflow.enable = true;
      };
      mcps = {
        context7.apiKey = config.secretspec.secrets.CONTEXT_SEVEN_API_KEY;
      };
      agents = {
        orchestrator.enable = true;
        researcher.enable = true;
        explorer.enable = true;
        architect.enable = true;
        backend-engineer.enable = true;
        release-engineer.enable = true;
        frontend-engineer.enable = true;
        scribe.enable = true;
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
        "docs/prds" =
          "Product Requirement Documents — product and domain intent (WHAT/WHY), upstream of ADRs and specs";
        "docs/adrs" = "Architecture Decision Records";
        "docs/specs" = "Feature and system design documents";
        "docs/conventions" = "Workspace-wide rules and guidelines";
        "docs/glossary" = "Canonical terms and definitions";
        "docs/findings" = "Debugging investigations and research findings";
        "docs/debt" = "Technical debt register with encounter ledger";
        "docs/wiki" =
          "Informal quick-reference notes (agent team, cheatsheets) outside the 8 formal doc tracks";

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
