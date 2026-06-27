{ lib, config, ... }: {
  options.core.ai.opencode.agents =
    let
      inherit (config.core) utils;
      makeAgentSettings =
        {
          models,
          defaultModel,
          mcps ? [ ],
          skills ? [ ],
          variant ? null,
          description ? "AI Agent",
          ...
        }:
        lib.mkOption {
          type =
            with lib.types;
            nullOr (submodule {
              options = {
                model = utils.makeEnumOption {
                  default = defaultModel;
                  acceptedList = models;
                };
                fallbacks = utils.makeListOption {
                  ofType = with types; attrsOf anything;
                  default = map (x: { model = x; }) models;
                };
                variant = utils.makeStrOption {
                  default = variant;
                  nullable = true;
                };
                skills = utils.makeListOption {
                  ofType = lib.types.str;
                  default = skills;
                };
                mcps = utils.makeListOption {
                  ofType = lib.types.str;
                  default = mcps;
                };
              };
            });
          inherit description;
          default = {
            model = defaultModel;
            fallbacks = map (x: { model = x; }) models;
            mcps = mcps;
            skills = skills;
          };
        };
    in
    {
      orchestrator = makeAgentSettings {
        defaultModel = "opencode-go/glm-5.2";
        models = [
          "anthropic/claude-opus-4-8"
          "opencode-go/glm-5.2"
          "opencode-go/kimi-k2.7-code"
          "opencode-go/kimi-k2.6"
          "opencode-go/glm-5.1"
        ];
      };
      orchestrator-minion = makeAgentSettings {
        defaultModel = "anthropic/claude-sonnet-4-6";
        models = [
          "anthropic/claude-sonnet-4-6"
          "opencode-go/kimi-k2.6"
          "openai/gpt-5.5"
          "opencode-go/minimax-m3"
        ];
      };
      looker = makeAgentSettings {
        defaultModel = "opencode-go/kimi-k2.6";
        models = [
          "opencode-go/kimi-k2.6"
          "openai/gpt-5.5"
        ];
      };
      architecturer = makeAgentSettings {
        defaultModel = "openai/gpt-5.5";
        variant = "xhigh";
        models = [
          "openai/gpt-5.5"
          "anthropic/claude-opus-4-8"
        ];
        skills = [
          "ce-brainstorm"
          "workers-best-practices"
          "web-perf"
        ];
        mcps = [
          "codegraph"
          "searxng"
          "crawl4ai"
        ];
      };
      researcher = makeAgentSettings {
        defaultModel = "opencode-go/minimax-m3";
        skills = [ "customer-research" ];
        mcps = [
          "websearch"
          "context7"
          "gh_app"
          "searxng"
          "crawl4ai"
        ];
        models = [
          "opencode-go/minimax-m3"
          "anthropic/claude-haiku-4-5"
          "openai/gpt-5.4-mini"
        ];
      };
      codeExplorer = makeAgentSettings {
        defaultModel = "opencode-go/minimax-m3";
        models = [
          "opencode-go/minimax-m3"
          "anthropic/claude-haiku-4-5"
        ];
        mcps = [ "codegraph" ];
      };
      designer = makeAgentSettings {
        defaultModel = "opencode-go/kimi-k2.6";
        models = [
          "opencode-go/kimi-k2.6"
          "opencode-go/glm-5.2"
        ];
        skills = [
          "make-interfaces-feel-better"
          "better-icons"
          "motion"
          "image"
          "video"
          "marketing-psychology"
        ];
        mcps = [ "codegraph" ];
      };
      worker = makeAgentSettings {
        defaultModel = "openai/gpt-5.5";
        models = [
          "openai/gpt-5.5"
          "openai/gpt-5.4"
          "anthropic/sonnet-4-6"
        ];
        variant = "low";
        skills = [ ];
        mcps = [
          "codegraph"
          "searxng"
          "crawl4ai"
        ];
      };
    };
}
