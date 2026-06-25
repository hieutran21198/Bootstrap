{
  config,
  lib,
  ...
}:
{
  options.core.docs = {
    enable = lib.mkEnableOption "Enable documentation conventions and the docs/ track structure.";

    tracks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Path relative to the workspace root, without trailing slash.";
            };
            description = lib.mkOption {
              type = lib.types.str;
              description = "Short description of what the track is for.";
            };
          };
        }
      );
      default = {
        adrs = {
          path = "docs/adrs";
          description = "Architecture Decision Records (append-only, numbered `NNNN-kebab-title.md`).";
        };
        specs = {
          path = "docs/specs";
          description = "Feature and system specifications (living per spec, kebab-case `<feature>.md`).";
        };
        conventions = {
          path = "docs/conventions";
          description = "Living workspace conventions and rules (edit-in-place, by topic).";
        };
        glossary = {
          path = "docs/glossary";
          description = "Canonical term meanings (living, atomic per term).";
        };
        findings = {
          path = "docs/findings";
          description = "Investigation records (append-only, dated `YYYY-MM-DD-<title>.md`).";
        };
        debt = {
          path = "docs/debt";
          description = "Known shortcomings with an append-only *Encounters* ledger.";
        };
      };
      description = ''
        Documentation tracks declared by the workspace. Each track is a folder
        under `docs/` with its own `TEMPLATE.md` for new entries and a
        `README.md` describing lifecycle, naming, and conventions. AI agents
        read this registry to know where to look for context and where to
        write evidence; each track's `README.md` is the source of truth for
        per-track naming and status lifecycle (which differ by track).
      '';
    };

    heavyEvidenceConvention = lib.mkOption {
      type = lib.types.str;
      default = "<filename>.assets/";
      description = ''
        Sibling directory pattern used to store heavy evidence (logs, traces,
        diagrams, metric dumps, screenshots) next to a document. Module
        contributions reference this convention by name; agents quote the
        literal pattern in their prompt.
      '';
    };
  };

  config =
    let
      opts = config.core.docs;

      renderTrack = _name: track: "- `${track.path}/` — ${track.description}";
      tracksList = lib.concatStringsSep "\n" (lib.mapAttrsToList renderTrack opts.tracks);

      heavyEvidence = opts.heavyEvidenceConvention;

      findingsTrack = opts.tracks.findings or null;
      debtTrack = opts.tracks.debt or null;
      specsTrack = opts.tracks.specs or null;

      # Universal docs knowledge: track listing for `inputs`, generic
      # TEMPLATE-and-README rule for `outputFormat`, heavy-evidence pattern.
      # Applies to every agent that reads or writes documentation.
      universalContribution = {
        sections = {
          inputs = ''
            ### Documentation tracks

            Documentation lives under `docs/`. Each track has a `TEMPLATE.md` for new entries and a `README.md` describing its lifecycle, filename pattern, and status transitions (which differ by track). Cross-reference the relevant track for every claim:

            ${tracksList}
          '';
          outputFormat = ''
            - When writing into any `docs/<track>/` directory, follow that track's `TEMPLATE.md` strictly and obey that track's `README.md` for filename pattern, required sections, and status lifecycle. Each track has its own naming rule (ADRs are numbered, findings are date-prefixed, specs are kebab-case without numbering, debt has no dates or numbers); read the README before committing a filename.
            - Heavy artefacts (logs, traces, profiles, diagrams, raw dumps) live in a sibling `${heavyEvidence}` directory next to the document, never inlined into the document body.
          '';
        };
        order = 15;
      };

      # Per-write-target contributions. Each one is scoped to the agent whose
      # role includes writing to that track via `targetAgents`. Adding a new
      # write-target = adding a new entry here; deleting a track's contribution
      # makes that responsibility vanish from every agent's prompt.
      findingsContribution = lib.mkIf (findingsTrack != null) {
        sections.responsibilities = ''
          ### Documentation output (findings)

          - Write substantial investigations as findings under `${findingsTrack.path}/` using `${findingsTrack.path}/TEMPLATE.md`. Front matter: `Status: Open`, `Authors`, `Investigated`, `Tracks`. Required sections in order: *Symptom*, *Reproduction*, *Hypotheses considered*, *Investigation*, *Root cause* (if confirmed), *Resolution* (if applicable), *References*.
          - Heavy evidence (logs, profiles, traces) goes under `${heavyEvidence}` next to the finding, never inlined into the finding body.
          - For lightweight context-gathering that does not warrant a full finding, return the evidence inline to the orchestrator with paths / URLs / commands cited.
          - Findings are **append-only after `Resolved`** — supersede with a new dated finding instead of editing a resolved one.
        '';
        targetAgents = [ "explorer" ];
        order = 16;
      };

      debtContribution = lib.mkIf (debtTrack != null) {
        sections.responsibilities = ''
          ### Documentation output (debt)

          - If the investigation surfaces architectural debt, append a row to the matching `${debtTrack.path}/<topic>-<desc>.md` *Encounters* ledger — or create the debt item from `${debtTrack.path}/TEMPLATE.md` if none exists. Front matter: `Status`, `Priority`, `Hits`, `Owner`, `Created`, `Last reviewed`.
          - The *Encounters* table is **append-only**: corrections add a new row, never rewrite an existing row.
          - Do not log routine `TODO` / `FIXME` nits as debt; debt is for shape-of-the-system shortcomings that recur.
        '';
        targetAgents = [ "explorer" ];
        order = 17;
      };

      specsContribution = lib.mkIf (specsTrack != null) {
        sections.responsibilities = ''
          ### Documentation output (specs)

          - Write **one** spec at `${specsTrack.path}/<feature>.md` (top-level) or `${specsTrack.path}/<area>/<feature>.md` (grouped by area) using `${specsTrack.path}/TEMPLATE.md` as the skeleton. Kebab-case filename, no numbering, no date prefix.
          - Front matter: `Status: Draft`, `Authors`, `Last reviewed: <today YYYY-MM-DD>`, `Tracks: <ADR-NNNN link or ticket URL or "—" if standalone>`. Do not advance status past `Draft` — only the orchestrator transitions to `Accepted` / `Implemented`.
          - Required sections in order: *Problem*, *Goals*, *Non-goals*, *Background*, *Design*, *Alternatives considered*, *Open questions*, *Implementation plan*, *References*.
          - The `Tracks` field cites the ADR or ticket that authorised the work; if the orchestrator did not provide one, surface that as an *Open question* item.
          - Cite Explorer findings by their canonical path or URL inside the spec body; quote user statements verbatim where they constrain the design.
          - Mark unresolved decisions as `Open question:` and gaps you filled (where Explorer did not cover and the user did not specify) as `Assumption:` so the reviewer can challenge each one.
          - List in *Alternatives considered* only options you seriously weighed — one or two — with one-line rationale for each rejection. Skip strawmen.
          - Add the spec to the *Index* table at the bottom of `${specsTrack.path}/README.md` (filename, status, tracks).
        '';
        targetAgents = [ "spec-writer" ];
        order = 18;
      };
    in
    lib.mkIf opts.enable {
      core.ai.tools.docs = universalContribution;
      core.ai.tools.docs-findings = findingsContribution;
      core.ai.tools.docs-debt = debtContribution;
      core.ai.tools.docs-specs = specsContribution;
    };
}
