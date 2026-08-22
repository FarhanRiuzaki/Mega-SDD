---
name: emit-prd
version: 1.1.3
description: Generate a PRD from mega-sdd state — forward (vault to PRD prose) or REVERSE (KB, no vault) with [VERIFIED]/[INFERRED]/[OPEN] markers carried verbatim; journeys as Mermaid; reviewed/final maturity human-set. Triggers — "generate PRD", "emit PRD", "buat PRD", "PRD dari knowledge base", "reverse PRD", "PRD dari legacy", or paraphrases.
---

# Emit-PRD — Product Requirements Document Generator

**Announce at start:** "I'm using the emit-prd skill to generate the PRD (mode: <forward|reverse>)."

> **Output language (Tier-3 artifact):** PRD body prose + headings the plugin authors → **Indonesian + English technical terms by default** (precedence: explicit request > the language the user writes in > Indonesian). **Quoted / flattened source content — KB claim text, vault excerpts, constitution clauses — and every `[Source: sha256:…]` citation are reproduced in their source language, never translated** (citation discipline, moat invariant #3). Terse/technical source notation is quoted verbatim in code spans with an Indonesian gloss — never translated in place. Tier-1 structural tokens stay English — including the `[VERIFIED]/[INFERRED]/[OPEN]` markers. Full rules → `plugins/mega-sdd/references/output-language.md`.

> **Doc-pack contract:** emit-prd is the PRD **doc-pack** of the shared emission engine — `plugins/mega-sdd/references/emission-engine.md` owns the doc-agnostic spine; this skill + `references/prd-sections.md` + `references/prd-template.md` bind it to every PRD-specific rule. The PRD is a **document the team reads — an OUTPUT, never a decision surface**: OQ resolution stays in-skill (resolve-oq); open items surface in §6 read-only.

## When to use

- "generate PRD" / "emit PRD" / "buat PRD" / "PRD dari knowledge base" / "reverse PRD"
- **Reverse mode** — a legacy codebase was extracted (`.mega-sdd/knowledge-base/` exists) but no vault yet: draft the PRD the team never had, marker-grounded from the KB
- **Forward mode** — a vault exists: render the team-readable PRD view of vault intent
- Re-emission after diff-vault / resolve-oq updated the sources

## Inputs

- `<vault-path>` (positional, optional — forward mode; defaults to first vault detected via `plugins/mega-sdd/references/paths.md`)
- `--kb=<path>` (reverse mode KB root; default `.mega-sdd/knowledge-base` → legacy paths)
- `--mode={forward|reverse|auto}` (default `auto`: vault present → forward; KB present + no vault → reverse; neither → halt `dep_missing`)
- `--no-pdf` · `--auto` (handoff YAML per `orchestrate-flow/references/handoff-contract.md`)

## Outputs

```
<out-root>/prd/
├── PRD.md                      # 6-section PRD (see references/prd-template.md)
├── PRD.pdf                     # GitHub-style PDF via scripts/md2pdf.sh (Chrome; PRD.html fallback)
└── .citation-map.json          # script-written by build-citation-map.sh --doc=prd
```

**`<out-root>`** = the vault path in forward mode (`<vault>/prd/` — sibling of `fsd/`/`sit/`); `<project>/.mega-sdd` in reverse mode (no vault exists yet → `<project>/.mega-sdd/prd/PRD.md`; the shared scripts take `--vault=<project>/.mega-sdd`, under which KB citations like `knowledge-base/…` resolve naturally). When generate-intent later creates a vault, the next forward emission moves the PRD home to `<vault>/prd/` (the old draft stays as an inert file).

## Pre-flight checks

1. **source_present**: vault (`vault.json` or `0[0-6]-*.md` docs) OR KB (`knowledge-base/README.md`) — neither → halt `dep_missing`
2. **pandoc_installed** / **chrome_present** / **mmdc_present** — warn-only (PDF via Chrome else GitHub-styled HTML; mmdc→mermaid diagrams else code; never LaTeX) — pandoc/mmdc can be installed via `/mega-sdd:install-deps` (Chrome is detect-only; install it manually)

## Procedure

### Step 0: Mode detection

Per `references/prd-sections.md §Mode determination`: vault present → **forward**; KB present + no vault → **reverse**; `--mode` overrides. Announce mode + evidence. Maturity at emit time is ALWAYS `draft-from-legacy` (the machine-draft rung) — `reviewed`/`final` are HUMAN-set later via `refresh-doc-stamps.sh`; the model never stamps them.

### Steps 1–3: Drift check + mechanical body (ONE script call), then fill ONLY the model slots

1. Run `bash <plugin-root>/scripts/build-prd-core.sh --out-root=<out-root> --cwd=<project-root> --mode=<forward|reverse> [--vault=<vault>] [--kb=<kb-root>]`. It writes `<out-root>/prd/PRD.md` with every MECHANICAL slot pre-filled per `references/prd-sections.md` — journeys carried VERBATIM (never redrawn when a diagram exists), the reverse-mode per-domain claim harvest with `[VERIFIED]/[INFERRED]/[OPEN]` markers VERBATIM, forward §3 = FR id/title + the FR body's FIRST paragraph verbatim, §5 NFR categories + constitution `[LOCKED]` clauses, §6 open-items table, the `[Pending — …]` discipline, the LITERAL `(sha256: pending)` stamps, and drift callouts (it runs `build-citation-map.sh --check-drift --doc=prd` itself; the drift lines it prints feed Step 6's change-note — do not run the drift script again). Exit 2 → fix the invocation; nothing written.
2. The summary line reports `model_slots=<n> (<names>)` — fill EXACTLY those `{{…}}` slots via targeted Edits, nothing else: `section-1-background` + `section-1-purpose` (narasi Indonesia yang menganyam klaim sumber — reverse mode: claim lines keep their markers), `section-2-actors-table` when listed (one row per actor actually NAMED in a source — never invent an actor; no actor found → `[Pending — belum ada aktor teridentifikasi di sumber]`), and any `journey-<slug>` slot (a KB workflow with NO diagram: draw a NEW Mermaid flowchart STRICTLY from the quoted recorded steps above the slot — steps not in the KB may not appear).
3. **Editing authority over builder-derived content is DELETE/REFORMAT-only** — the reverse harvest is over-complete by design; prune rows that are not requirement-shaped, never ADD an uncited row (fabrication — caught by Steps 4.6/4.7). An `[INFERRED]`/`[OPEN]` claim may NOT be rephrased as established fact; markers are never dropped, merged, or upgraded.

### Step 4.5: Unfilled-slot scan

`grep -oE '\{\{[a-z0-9_-]+\}\}' <out-root>/prd/PRD.md` — ANY hit → halt `quality_gate_failed:template_slot_unfilled`; STOP. (In-skill scan — `validate-fsd-slots.sh` stays FSD-scoped per `plugins/mega-sdd/references/emission-engine.md §P5 seams`.)

### Step 4.6: Stamp citations + write the map (script-run)

Run `bash <plugin-root>/scripts/build-citation-map.sh --vault=<out-root> --cwd=<project-root> --mode=<forward|reverse> --doc=prd`. Exit 0 → proceed; exit 1 → halt `quality_gate_failed:citation_unresolvable` with the script's `UNRESOLVED`/`LEFTOVER` lines, do NOT render; exit 2 → internal bug.

### Step 4.7: Marker-preservation check (script-run, reverse mode MANDATORY)

Run `bash <plugin-root>/scripts/check-prd-markers.sh --prd=<out-root>/prd/PRD.md --cwd=<project-root> [--kb=<kb-root>]`.

- Exit 0 → markers preserved verbatim. Proceed.
- Exit 1 → halt `quality_gate_failed` subtype `marker_stripped` carrying the script's `MARKER_STRIPPED`/`MARKER_UPGRADED`/`MARKER_MISSING` lines + keterangan verbatim; STOP — an inferred claim presented as fact must never ship.
- (Forward mode with no KB: the script exits 0 with a note — harmless to always run.)

### Step 5: Render PDF via md2pdf (optional)

Same lane as emit-fsd Step 5 — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/md2pdf.sh" <vault>/prd/PRD.md <vault>/prd/PRD.pdf --toc` (GitHub/VS Code style, NEVER LaTeX; transforms on a throwaway copy so `PRD.md`'s citation sha stays intact). Exit 0 → `PRD.pdf`; exit 3 → Chrome absent, `PRD.html` fallback (accepted, not a halt); exit 2 → pandoc absent (skip); exit 1 → halt `pdf_render_failed`. `--no-pdf` skips.

### Step 6: Doc-control stamp (script-run)

Run `bash <plugin-root>/scripts/refresh-doc-stamps.sh --vault=<out-root> --doc=prd --maturity=draft-from-legacy --position="<mode> emit; <pipeline digest>" --generated-at=<now ISO8601> --bump --change-note="<derived>"`. The block, the `version`/`status` fields, and the **Riwayat Revisi** region are SCRIPT-OWNED; `reviewed`/`final` maturity bumps are HUMAN actions (the user runs the same script by hand or asks explicitly) — the model NEVER passes those rungs.

**Change-note derivation (mandatory, never free prose):** build the note from the drift lines the BUILDER printed (Steps 1–3 — never a second drift run) — `NO_PRIOR` → `Emisi awal`; otherwise `Regenerasi §<list of DRIFT/GONE sections> — <n> sumber berubah` (e.g. `Regenerasi §2, §4 — 3 sumber berubah`); no drift lines at all → `Re-emisi tanpa perubahan sumber`. Version `1.0`/`2.0` + `status: approved` are minted ONLY by a human running `--approve --approver="Nama, Peran"` — the model NEVER passes `--approve`.

### Step 7: Handoff (when --auto) + summary (always)

```
PRD generated (<forward|reverse>, maturity: draft-from-legacy):
  Sections: 6 · Citations: <N> · Markers carried: <V> [VERIFIED] / <I> [INFERRED] / <O> [OPEN]
  Open items (§6): <K> — resolve via resolve-oq (PRD is an output, not a decision surface)
  Next: review → human sets maturity 'reviewed' · reverse mode: lanjut generate-intent --kb=<kb>
```

## Halt protocol

Per `plugins/mega-sdd/references/halt-protocol.md`. emit-prd emits: `dep_missing` (no vault AND no KB), `quality_gate_failed` with subtypes `template_slot_unfilled`, `citation_unresolvable`, `pdf_render_failed`, and **`marker_stripped`** (a KB confidence marker was dropped/upgraded in the PRD — detected deterministically by `scripts/check-prd-markers.sh`; details carry the script's `MARKER_*` lines; keterangan frames it as dugaan-disajikan-sebagai-fakta). All subtypes of the existing `quality_gate_failed` — no new halt types.

## Handoff emission

When invoked with `--auto`:

```yaml
handoff:
  emitted_by: emit-prd
  emitted_at: <ISO8601>
  status: completed | halted
  artifacts:
    - <abs path to PRD.md>
    - <abs path to PRD.pdf>            # when rendered
    - <abs path to .citation-map.json>
  next_action:
    suggested_skill: <null | "generate-intent">
    suggested_args: ["--kb=<kb-root>"]   # reverse mode only
    rationale: "PRD draft emitted; reverse lane continues via generate-intent --kb (the PRD is an output, not the pipeline input)."
  blockers: []
  metrics:
    mode: <"forward" | "reverse">
    maturity: "draft-from-legacy"
    citations_count: <int>
    markers_verified: <int>
    markers_inferred: <int>
    markers_open: <int>
    open_items_count: <int>
```

## Memory layer

Out of scope: emit-prd does NOT participate in the memory layer.

## Anti-hallucination rails

1. Every section traces to sources via the SCRIPT-COMPUTED citation map (`--doc=prd`); missing source → `[Pending — X]`, never fabrication.
2. **Markers ride verbatim:** `[VERIFIED]/[INFERRED]/[OPEN]` from KB claims appear unchanged in the PRD text — dropping or upgrading one is a deterministic `marker_stripped` halt (`check-prd-markers.sh`), never a prose-trusted rule.
3. User journeys are Mermaid; existing diagrams (vault/KB) are carried verbatim, never redrawn.
4. sha256 stamps are script-computed; the model emits only the literal `(sha256: pending)`.
5. Maturity: the model stamps ONLY `draft-from-legacy`; `reviewed`/`final` are human-set slots.
