{
  extra = {
    dev-container = {
      enable = true;
    };
  };
  core = {
    ai = {
      agents = {
        # DEPRECATED 2026-06-25. Migrating orchestration to Claude Code
        # Agent Teams (https://code.claude.com/docs/en/agent-teams). The
        # built-ins shipped in v2.1.187 cover Explore / Plan / general
        # purpose; the spec-synthesis role lives in the team lead or a
        # spawned teammate. Modules retained; flip to `true` only for a
        # specific legacy workflow that has not yet been ported.
        coder = {
          enable = false;
        };
        explorer = {
          enable = false;
        };
        spec-writer = {
          enable = false;
        };
      };
      claude = {
        enable = true;
      };
      opencode = {
        enable = true;
        profile = "slim-go-openai";
      };

    };
    workspace = {
      enable = true;
      name = "Bootstrap";
      wsInfoDeepLevel = 2;
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
        "services/portal" = "Portal backend";
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
