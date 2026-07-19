---
name: emit-prd
version: 1.0.0
description: Generate a PRD (Product Requirements Document) from mega-sdd state — forward mode (vault exists) renders PRD prose from vault/KB sources; REVERSE mode (knowledge base present, no vault) drafts a team-readable PRD from an extract-intelligence KB with [VERIFIED]/[INFERRED]/[OPEN] confidence markers carried VERBATIM into the PRD text (an inferred claim is never presented as fact — deterministically checked by scripts/check-prd-markers.sh). User journeys emit as Mermaid. Citation discipline via build-citation-map.sh --doc=prd. Maturity draft-from-legacy → reviewed → final where reviewed/final are human-set slots the model never fills. Triggers — "generate PRD", "emit PRD", "buat PRD", "PRD dari knowledge base", "reverse PRD", "PRD dari legacy", or paraphrases.
---

# Emit-PRD — Product Requirements Document Generator

**Announce at start:** "I'm using the emit-prd skill to generate the PRD (mode: <forward|reverse>)."

> **Output language (Tier-3 artifact):** PRD body prose + headings the plugin authors → **Indonesian + English technical terms by default** (precedence: explicit request > the language the user writes in > Indonesian). **Quoted / flattened source content — KB claim text, vault excerpts, constitution clauses — and every `[Source: sha256:…]` citation are reproduced in their source language, never translated** (citation discipline, moat invariant #3). Terse/technical source notation is quoted verbatim in code spans with an Indonesian gloss — never translated in place (decision 4). Tier-1 structural tokens stay English — including the `[VERIFIED]/[INFERRED]/[OPEN]` markers. Full rules → `plugins/mega-sdd/references/output-language.md`.

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
├── PRD.pdf                     # via pandoc when available
└── .citation-map.json          # script-written by build-citation-map.sh --doc=prd
```

**`<out-root>`** = the vault path in forward mode (`<vault>/prd/` — decision 6 sibling of `fsd/`/`sit/`); `<project>/.mega-sdd` in reverse mode (no vault exists yet → `<project>/.mega-sdd/prd/PRD.md`; the shared scripts take `--vault=<project>/.mega-sdd`, under which KB citations like `knowledge-base/…` resolve naturally). When generate-intent later creates a vault, the next forward emission moves the PRD home to `<vault>/prd/` (the old draft stays as an inert file).

## Pre-flight checks

1. **source_present**: vault (`vault.json` or `0[0-6]-*.md` docs) OR KB (`knowledge-base/README.md`) — neither → halt `dep_missing`
2. **pandoc_installed** / **pandoc_latex_engine_present** — warn-only degradations (same lane as emit-fsd)

## Procedure

### Step 0: Mode detection

Per `references/prd-sections.md §Mode determination`: vault present → **forward**; KB present + no vault → **reverse**; `--mode` overrides. Announce mode + evidence. Maturity at emit time is ALWAYS `draft-from-legacy` (the machine-draft rung) — `reviewed`/`final` are HUMAN-set later via `refresh-doc-stamps.sh`; the model never stamps them.

### Step 1: Prior-emit drift check (script-run)

Run `bash <plugin-root>/scripts/check-citation-drift.sh --vault=<out-root> --cwd=<project-root> --doc=prd`; consume ONLY its output lines; flagged sections get drift callouts with the script's `old12`/`new12` verbatim. NEVER read `.citation-map.json` directly.

### Step 2: Per-section emission loop

For each section 1–6 follow `references/prd-sections.md §Section N` (sources + extraction per mode):

- **MARKER PRESERVATION (reverse mode, binding):** every claim taken from the KB carries its `[VERIFIED]` / `[INFERRED]` / `[OPEN]` marker VERBATIM into the PRD line, next to the claim text, with the KB citation. An `[INFERRED]` or `[OPEN]` claim may NOT be rephrased as established fact; markers are never dropped, merged, or upgraded. (Deterministically checked in Step 4.7.)
- User journeys (§4) emit **Mermaid** (from vault 04-flows verbatim in forward mode; from KB workflow diagrams verbatim in reverse mode — never redrawn when a diagram exists, drawn fresh from KB steps ONLY when the KB has no diagram, cited to the KB workflow file).
- Absent source → `[Pending — <source> not yet generated]` — NEVER fabricate.
- **Stamp rule:** every citation stamp is the LITERAL `(sha256: pending)`.

### Step 3: Assemble PRD.md

Fill `references/prd-template.md` slots; write `<out-root>/prd/PRD.md`.

### Step 4.5: Unfilled-slot scan

`grep -oE '\{\{[a-z0-9_-]+\}\}' <out-root>/prd/PRD.md` — ANY hit → halt `quality_gate_failed:template_slot_unfilled`; STOP. (In-skill scan — `validate-fsd-slots.sh` stays FSD-scoped per `plugins/mega-sdd/references/emission-engine.md §P5 seams`.)

### Step 4.6: Stamp citations + write the map (script-run)

Run `bash <plugin-root>/scripts/build-citation-map.sh --vault=<out-root> --cwd=<project-root> --mode=<forward|reverse> --doc=prd`. Exit 0 → proceed; exit 1 → halt `quality_gate_failed:citation_unresolvable` with the script's `UNRESOLVED`/`LEFTOVER` lines, do NOT render; exit 2 → internal bug.

### Step 4.7: Marker-preservation check (script-run, reverse mode MANDATORY)

Run `bash <plugin-root>/scripts/check-prd-markers.sh --prd=<out-root>/prd/PRD.md --cwd=<project-root> [--kb=<kb-root>]`.

- Exit 0 → markers preserved verbatim. Proceed.
- Exit 1 → halt `quality_gate_failed` subtype `marker_stripped` carrying the script's `MARKER_STRIPPED`/`MARKER_UPGRADED`/`MARKER_MISSING` lines + keterangan verbatim; STOP — an inferred claim presented as fact must never ship.
- (Forward mode with no KB: the script exits 0 with a note — harmless to always run.)

### Step 5: Render PDF via pandoc (optional)

Same lane as emit-fsd Step 5 (skip/HTML-fallback/halt `pdf_render_failed`). `--no-pdf` skips.

### Step 6: Doc-control stamp (script-run)

Run `bash <plugin-root>/scripts/refresh-doc-stamps.sh --vault=<out-root> --doc=prd --maturity=draft-from-legacy --position="<mode> emit; <pipeline digest>" --generated-at=<now ISO8601>`. The block is SCRIPT-OWNED; `reviewed`/`final` bumps are HUMAN actions (the user runs the same script by hand or asks explicitly) — the model NEVER passes those rungs.

### Step 7: Handoff (when --auto) + summary (always)

```
PRD generated (<forward|reverse>, maturity: draft-from-legacy):
  Sections: 6 · Citations: <N> · Markers carried: <V> [VERIFIED] / <I> [INFERRED] / <O> [OPEN]
  Open items (§6): <K> — resolve via /mega-sdd:resolve-oq (PRD is an output, not a decision surface)
  Next: review → human sets maturity 'reviewed' · reverse mode: lanjut /mega-sdd:generate-intent --kb=<kb>
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
