{
  opencode = {
    settings = {
      plugin = [
        "oh-my-opencode-slim@latest"
      ];
    };
  };
  core.ai.opencode.slimPresets = {
    openai = {
      orchestrator = {
        model = "openai/gpt-5.5-fast";
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
        model = "openai/gpt-5.5-fast";
        variant = "high";
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
        model = "openai/gpt-5.3-codex-spark";
        variant = "low";
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
        model = "openai/gpt-5.3-codex-spark";
        variant = "low";
        skills = [

        ];
        mcps = [
          "codegraph"
        ];
      };
      designer = {
        model = "openai/gpt-5.4-mini";
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
}
