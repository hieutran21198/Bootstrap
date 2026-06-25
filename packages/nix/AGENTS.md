# packages/nix/

## OVERVIEW
Nix devenv modules for the workspace. `core/` provides mandatory tooling; `extra/` provides optional add-ons. Imported by root `devenv.yaml`.

## STRUCTURE
```
packages/nix/
├── core/                     # mandatory workspace tooling
│   ├── workspace/            # enterShell scripts, mandatoryFolders enforcement
│   ├── git/                  # pre-commit hooks, secret scanners
│   ├── secrets/              # secret scanning config
│   └── toolchains/
│       ├── go/               # Go toolchain, golangci-lint, go-work
│       │   ├── go-work/      # go.work generation
│       │   └── golangci-lint/ # linter config generation
│       ├── markdown/         # markdown linting
│       └── terraform/        # Terraform toolchain (optional core)
└── extra/                    # opt-in extensions
    ├── ai/                   # AI agent tooling
    └── dev-container/        # devcontainer support
```

## CONVENTIONS
- **Import in `devenv.yaml`**: modules are imported via `packages/nix/core/devenv.yaml`; each submodule exports options via `options.<name>.*`
- **Module ordering**: use descriptive directory names; no numeric prefix (that was the `_nixenv` convention — retired)
- **Generated artifacts**: `workspace/default.nix` generates `.editorconfig`, `.info`; `toolchains/go/golangci-lint/default.nix` generates `.golangci.yml` — these are gitignored symlinks into Nix store; do not hand-edit
- **`extra/` modules**: not imported by default; add to root `devenv.yaml` manually when needed

## ANTI-PATTERNS
- ✗ Place Nix module logic outside `packages/nix/core/` or `packages/nix/extra/`
- ✗ Hand-edit generated artifacts (`.golangci.yml`, `.editorconfig`, `.info`) — Nix regenerates them on `direnv reload`
- ✗ Use numeric prefixes for module dirs (`_nixenv` pattern is retired)
- ✗ Import `extra/` modules from `core/` — `extra/` is opt-in, not forced
