{ config, ... }: {
  extra = {
    dev-container = {
      enable = true;
    };
  };
  core = {
    worktree = {
      enable = true;
    };
    ai = {
      claude = {
        enable = true;
      };
      opencode = {
        enable = true;
        plugins = {
          handoff-audit-log = {
            enable = true;
          };
        };
        settings = {
          # Sonnet 5 high is the project manager nearly opus 4.8 with 1/2 price.
          agent = {
            explore = {
              disable = true;
            };
            plan = {
              disable = true;
            };
            build = {
              disable = true;
            };

            # Opus 4.8, Fable 5 - hell level, more slower, over-kill for daily
            # tasks.
            # Turns it on when making redesign system - reviewing gorvernance.
            orchestrator = {
              # claude > kimi > glm
              model = "anthropic/claude-opus-4-8";
              variant = "xhigh";
            };

            researcher = {
              model = "opencode-go/qwen3.7-plus";
            };
            explorer = {
              model = "opencode-go/deepseek-v4-flash";
            };

            # GPT 5.5 xhigh, Opus 4.8 xhigh/Fable 5 high is the supreme
            # commander you call in when the construction site is on fire.
            #
            # For daily work: gpt-5.5/Opus 4.8/Fable 5 high
            architect = {
              model = "openai/gpt-5.5";
              variant = "high";
            };
            security-reviewer = {
              model = "anthropic/claude-fable-5";
              variant = "high";
            };

            backend-engineer = {
              model = "openai/gpt-5.3-codex-spark";
              variant = "high";
            };
            frontend-engineer = {
              model = "openai/gpt-5.3-codex-spark";
              variant = "high";
            };

            scribe = {
              model = "anthropic/claude-sonnet-5";
              variant = "high";
            };
            dev-environment = {
              model = "opencode-go/deepseek-v4-pro";
              variant = "high";
            };
            release-engineer = {
              model = "opencode-go/deepseek-v4-pro";
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
        linear = {
          enable = true;
        };
        context7.apiKey = config.secretspec.secrets.CONTEXT_SEVEN_API_KEY;
        github.apiKey = config.secretspec.secrets.GITHUB_API_KEY;
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
        security-reviewer.enable = true;
        dev-environment.enable = true;
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
        "tools/ai/skills" =
          "Project-specific AI skill bodies (plain SKILL.md; generic/reusable skills are inlined in their Nix module under packages/nix/core/ai/skills/)";
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
        govulncheck = {
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
