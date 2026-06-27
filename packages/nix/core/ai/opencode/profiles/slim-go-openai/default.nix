{
  config = {
    core.ai.opencode.slimPresets = {
      slim-go-openai = {
        orchestrator = {
          model = "opencode-go/glm-5.2";
          skills = [
            "*"
            "!make-interfaces-feel-better"
          ];
          mcps = [
            "*"
            "!context7"
            "!gh_app"
            "!websearch"
          ];
        };
        oracle = {
          model = "openai/gpt-5.5";
          variant = "xhigh";
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
        librarian = {
          model = "opencode-go/minimax-m2.7";
          skills = [
            "customer-research"
          ];
          mcps = [
            "websearch"
            "context7"
            "gh_app"
            "searxng"
            "crawl4ai"
          ];
        };
        explorer = {
          model = "opencode-go/minimax-m2.7";
          skills = [
          ];
          mcps = [
            "codegraph"
          ];
        };
        designer = {
          model = "opencode-go/kimi-k2.6";
          skills = [
            "make-interfaces-feel-better"
            "better-icons"
            "vue"
            "nuxt"
            "motion"
            "image"
            "marketing-psychology"
            "video"
          ];
          mcps = [
            "codegraph"
          ];
        };
        fixer = {
          model = "openai/gpt-5.5";
          variant = "low";
          skills = [
            "vitest"
            "pnpm"
            "vite"
            "tsdown"
          ];
          mcps = [
            "codegraph"
            "searxng"
            "crawl4ai"
          ];
        };
      };
    };
  };
}
