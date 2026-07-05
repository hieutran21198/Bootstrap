{ lib, ... }:
{
  config.core.ai.agents.dev-environment = {
    mode = "subagent";
    role = "Dev-Environment";
    lane = "Local Dev & Workspace Tooling";
    description = "The Dev-Environment agent owns the local-dev and workspace-tooling lane: worktree lifecycle (ws-worktree create/list/remove and .worktree-offset), devenv/Nix module toggles, direnv and shell ergonomics, local .env/secret bootstrap, codegraph init guidance, ws-info/ws-tree usage, and dev-environment edits under packages/nix/.";
    capabilities = [
      "Worktree lifecycle: create, list, and remove managed worktrees with ws-worktree"
      "Port-offset management via .worktree-offset marker"
      "Local .env and secret bootstrap for development"
      "codegraph init guidance and indexing setup"
      "ws-info and ws-tree workspace introspection"
      "Devenv/Nix dev-environment module toggles and shell ergonomics"
      "Edits to packages/nix/ dev-environment modules and tools/ wiring"
      ".sdlc/<task-slug>/ scratch folder cleanup after durable content is routed"
    ];
    delegateWhen = [
      "A parallel agent session needs its own isolated worktree"
      "A worktree needs to be listed or cleaned up"
      "Local dev tooling or environment needs setup, inspection, or repair"
      "Devenv/Nix module toggles, direnv, or shell ergonomics need adjustment"
      "codegraph indexing needs setup or guidance"
      "Workspace info or tree output needs interpretation"
      "A closed task's .sdlc scratch folder needs cleanup after durable content is routed"
    ];
    avoidWhen = [
      "Application Go/domain logic or service implementation (Backend-Engineer)"
      "CI/CD, release mechanics, branch-protection, or deployment config (Release-Engineer)"
      "ADR, spec, or design decisions (Architect)"
      "Implementing the ws-worktree Go source (Backend-Engineer owns it)"
      "Granting final release go/no-go or product authority (human)"
    ];
    successCriteria = [
      "Worktrees are created, listed, or removed correctly with ws-worktree"
      "Port offsets are allocated and recorded in .worktree-offset"
      "Local env and secrets are bootstrapped without leaking credentials"
      "codegraph is initialized and indexed for the workspace"
      "Direnv and devenv shell behavior matches workspace conventions"
      "packages/nix/ dev-environment edits regenerate cleanly and pass Nix eval"
    ];
    posture = {
      edit = "allow";
      bash = "allow";
    };
    instructions = lib.mkDefault (builtins.readFile ./PROMPT.md);
  };
}
