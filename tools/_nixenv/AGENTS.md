# tools/_nixenv/

## OVERVIEW

Workspace-internal Nix devenv modules. The leading **underscore** marks the directory as not-a-Go-package and not-a-product-folder — it is consumed exclusively by the root [`devenv.yaml`](../../devenv.yaml).

## STRUCTURE

```
_nixenv/
├── 001-workspace/      # workspace options + better-tree + ws-info + .editorconfig/.info generation
├── 002-git-hooks/      # commitizen + secret scanning + repo hygiene via git-hooks.nix
├── 003-go-toolchain/   # languages.go + delve + LSP + golangci-lint + go-info script
├── 010-aws/            # (placeholder, empty)
└── 010-terraform/      # (placeholder, empty)
```

Each populated module ships three files: `devenv.nix` (the module), `devenv.yaml` (its own inputs), `.gitignore`.

## CONVENTIONS

- **Naming**: `NNN-kebab-name`. **NNN is load order and dependency ordering**.
  - `001-009` → **core** (loaded by every shell entry; depended on by everything else).
  - `010+`    → **optional** add-ons (e.g. cloud toolchains). Two modules may share the same `010-` prefix when they are alternates, not stacked.
- **Composition**: a module becomes active only when listed in the **root** [`../../devenv.yaml`](../../devenv.yaml) `imports:` block. Adding files alone does nothing.
- **Options pattern**: modules expose configuration via `options.<namespace> = { ... }` and consume their own outputs via `config.<namespace>`. Example: `options.workspace = { ... }` in `001-workspace/devenv.nix`, consumed in `devenv.nix` at the repo root.
- **`lib.mkDefault` for seeds**: files like `.editorconfig` are emitted with `lib.mkDefault` so the user can override per-repo without forking the module.
- **`copyMode = "seed"`**: generated files (`.gitkeep`, `.editorconfig`) are written once and then owned by the repo — devenv will not overwrite later edits.
- **Each module declares its own `nixpkgs` input** (`devenv.yaml`) and follows the same channel (`cachix/devenv-nixpkgs/rolling`) for consistency.

## ANTI-PATTERNS

- **Do not** rename or re-number an existing module — downstream modules and the root `devenv.yaml` reference the path. Add a new number instead.
- **Do not** introduce a module that re-declares `options.workspace.*` — it is owned by `001-workspace`.
- **Do not** put product code or Go sources here. This tree is configuration only.
- **Do not** import a `010+` module unconditionally from the root — keep optional toolchains optional.
- **Do not** edit `.pre-commit-config.yaml` at the repo root; change [`002-git-hooks/devenv.nix`](002-git-hooks/devenv.nix) instead. The yaml is generated.
