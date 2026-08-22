---
name: emit-fsd
version: 1.7.2
description: Generate a Hybrid Confluence FSD (Markdown + PDF) from vault/units/bolts with sha256-stamped citations per .citation-map.json; pre/post-development mode auto-detect; missing source emits [Pending — X], never fabrication. Triggers — "generate FSD", "emit FSD", "buat FSD", "FSD untuk confluence", or paraphrases.
---

# Emit-FSD — Functional Specification Document Generator

**Announce at start:** "I'm using the emit-fsd skill to generate the FSD from the current vault."

> **Output language (Tier-3 artifact):** FSD body prose + headings the plugin authors → **Indonesian + English technical terms by default** (precedence: explicit request > the language the user writes in > Indonesian). **But quoted / flattened source content — PRD excerpts, constitution clauses, binding quotes copied into a slot — and every `[Source: sha256:…]` citation are reproduced in their source language, never translated** (citation discipline, moat invariant #3). Tier-1 structural tokens stay English. Full rules → `plugins/mega-sdd/references/output-language.md`.

> **Doc-pack contract:** emit-fsd is the FSD **doc-pack** of the shared emission engine — `plugins/mega-sdd/references/emission-engine.md` owns the doc-agnostic spine (mode detect → drift-check script → per-section loop with `[Pending — X]` discipline → unfilled-slot scan → script citation-stamping → optional render → doc-control stamping); this skill + `references/section-mapping.md` + `references/fsd-template.md` bind that spine to every FSD-specific rule. The Steps below remain the OPERATIVE wording for the FSD lane (behavior byte-parity-pinned by `tests/derived-artifacts/test-p3-emission-parity.sh`); P5's emit-prd/emit-sit consume the same engine via the shared scripts' `--doc` flag.

## When to use

- "generate FSD" / "emit FSD" / "buat FSD" / "FSD untuk confluence"
- Pre-development sign-off: after generate-intent stabilizes the vault, before bolts run
- Post-development as-built record: after execute-bolts completes
- Re-emission on PRD revision (diff-vault) or OQ resolution (resolve-oq)

## Inputs

- `<vault-path>` (positional, optional — defaults to first vault detected via `plugins/mega-sdd/references/paths.md` priority order)
- `--mode={pre-dev|post-dev|auto}` (default: `auto` — detect from CWD state)
- `--styling=<path-to-yaml>` (override `FSD.styling.yaml` doc-metadata; PDF look is `github.css`, see Step 1)
- `--no-pdf` (emit `FSD.md` only — skip the md2pdf render)
- `--sections=<comma-list>` (emit subset; e.g., `--sections=1,2,5,7,8,10`)
- `--auto` (orchestrator-invoked; emit handoff YAML in chat per `mega-sdd:orchestrate-flow/references/handoff-contract.md`)

## Outputs

```
<vault-path>/fsd/
├── FSD.md                      # source markdown (10-section Hybrid Confluence template) — the moat-cited artifact
├── FSD.pdf                     # GitHub/VS Code-style PDF via scripts/md2pdf.sh (Chrome print)
├── FSD.html                    # GitHub-styled HTML fallback when Chrome absent (print from a browser)
├── github.css                  # OPTIONAL per-vault styling override (else the shipped default is used)
├── FSD.styling.yaml            # doc-metadata (project_name / version / date) — NOT PDF styling
└── .citation-map.json          # vault-section → FSD-section citation trace (script-written by build-citation-map.sh)
```

## Pre-flight checks

1. **vault_present_for_fsd**: `test -f <vault-path>/vault.json` — required (halt `dep_missing` if absent)
2. **pandoc_installed**: `command -v pandoc` — warn if absent (degraded to markdown-only; PDF/HTML both need pandoc)
3. **chrome_present**: `md2pdf.sh` probes Google Chrome / Chromium — warn-only if absent (degraded to GitHub-styled HTML; `FSD.md` + `.citation-map.json` are the source of truth, so a no-Chrome CI/headless run is fine by design)
4. **mmdc_present**: `command -v mmdc` — warn-only if absent (mermaid blocks render as code, not diagrams — a quality drop, since mermaid-flows is a hard rule; install `npm install -g @mermaid-js/mermaid-cli` — or run `/mega-sdd:install-deps` to install automatically)

Full preflight catalog: `mega-sdd:orchestrate-flow/references/predictive-checks.md` §emit-fsd preflight checks.

## Procedure

### Steps 0–4: Build the document body — SCRIPT-RUN, one call

Run `bash <plugin-root>/scripts/build-fsd-core.sh --vault=<vault> --cwd=<project-root> [--mode=pre-dev|post-dev] [--sections=<csv>]` — the deterministic builder that executes `references/section-mapping.md` §1–§10 end-to-end and writes `<vault>/fsd/FSD.md` with EVERY slot pre-filled (`model_slots=0` — the FSD lane is fully mechanical). It performs, in one spawn: mode detection (§Mode determination; `--mode` forwards the user override), doc-metadata resolution (`FSD.styling.yaml` seeded from `references/styling-config.yaml` when absent; PDF look stays `md2pdf.sh` + `github.css`, never LaTeX), the prior-emit drift check (it runs `build-citation-map.sh --check-drift` itself and INSERTS the drift callout block quotes with the script's `old12`/`new12` verbatim), per-section extraction with the `[Pending — <source> not yet generated]` discipline, the LITERAL `(sha256: pending)` stamps, and template assembly (the fenced skeletons are parsed from `references/fsd-template.md` at run time — single source of truth).

- **Exit 0:** FSD.md written. The summary line reports `mode=… sections=… pending=… drift=…`; announce the mode to chat (`"FSD mode: <mode> (script-detected)"`). The drift lines printed after the summary are the input to Step 6.5's change-note derivation — do NOT run the drift script a second time. A `LEFTOVER_SLOTS=` field on the summary line is an internal bug — treat as Step 4.5's halt.
- **Exit 2:** usage / vault / template problem — fix the invocation; nothing was written.
- The model NEVER edits builder-derived section content except to DELETE a row that is provably wrong (delete/reformat-only authority — a RULE, not a gate: Step 4.6 catches an unresolvable PATH, not a plausibly-cited invented row; adding one is fabrication regardless). NEVER replace a `[Pending — …]` marker with invented content.
- NEVER Read `.citation-map.json` directly — `build-citation-map.sh --check-drift` (inside the builder) is its only sanctioned reader.

### Step 4.5: Post-emission unfilled-slot scan

After Step 4 writes `<vault>/fsd/FSD.md`, scan the file for any remaining `{{...}}` slot markers (defensive check — the builder fills every slot; a leftover is an internal bug, surfaced on its summary line as LEFTOVER_SLOTS).

```bash
# Defensive scan:
grep -oE '\{\{[a-z0-9_-]+\}\}' <vault>/fsd/FSD.md
```

If ANY match found → emit halt `quality_gate_failed` with `subtype: template_slot_unfilled` per `plugins/mega-sdd/references/halt-protocol.md` §quality_gate_failed subtypes:

```yaml
type: quality_gate_failed
source_skill: emit-fsd
details:
  subtype: template_slot_unfilled
  unfilled_slots: ["{{section-3-stakeholders-table}}", "{{section-7-binding-confirmed-content}}"]
  fsd_path: <vault>/fsd/FSD.md
next_action: "Internal bug: fsd-template.md has slot marker(s) that section-mapping.md has no extraction rule for. File plugin bug at scm.bankmegadev.com/ai-rnd/mega-sdd/issues. Meanwhile, skip affected section via --sections=<csv> excluding the failing section."
```

STOP — do NOT proceed to Step 5 (pandoc render). Shipping unfilled `{{...}}` literals to PDF OR allowing pandoc to interpret them as template variables would be an anti-hallucination rail break.

### Step 4.6: Stamp citations + write the map (script-run, BEFORE pandoc)

Run `bash <plugin-root>/scripts/build-citation-map.sh --vault=<vault> --cwd=<project-root> --mode=<mode>`.

- **Exit 0:** `pending` stamps in FSD.md are now real 12-char hashes (computed by the script from file bytes) and `<vault>/fsd/.citation-map.json` (schema 2.0) is written — including `missing_sources[]`, script-derived from the `[Pending — …]` markers (consumer contract unchanged: orchestrate-flow final summary). Proceed to Step 5.
- **Exit 1:** halt `quality_gate_failed` with `subtype: citation_unresolvable`, details carrying the script's `UNRESOLVED`/`LEFTOVER` lines; STOP — do NOT render PDF (a fabricated or stale citation must never ship in a stamped document).
- **Exit 2:** usage error / FSD.md missing — internal bug; re-check Step 4 wrote `<vault>/fsd/FSD.md`.

### Step 5: Render PDF via md2pdf (GitHub/VS Code style — NEVER LaTeX)

The PDF is rendered by the shared pipeline `scripts/md2pdf.sh` (frontmatter → visible ```yaml block; ```mermaid → SVG via `mmdc`; pandoc `-f markdown-implicit_figures` → HTML with `github.css`; Chrome `--print-to-pdf`). LaTeX/`xelatex`/`tectonic` is NOT used — its academic-paper output (borderless tables, float "Figure N" diagrams, page-break-cut diagrams) is banned by `docs/superpowers/specs/2026-07-20-md2pdf-render-engine.md`.

1. **Run** (skip only if `--no-pdf`):
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/md2pdf.sh" <vault>/fsd/FSD.md <vault>/fsd/FSD.pdf --toc
   ```
   The transforms run on a throwaway copy — **`FSD.md` is never modified**, so its citation sha256 stamps (Step 4.6) stay intact.
2. Interpret the exit code:
   - **0** → `FSD.pdf` written. Log `"✓ FSD.pdf rendered (GitHub style)"`. Proceed to Step 6.
   - **3** → Chrome absent (or print failed): `FSD.html` was written (same `github.css`). Log `"⚠ Chrome absent — emitted GitHub-styled FSD.html; print-to-PDF from a browser, or install Chrome. (FSD.md is the source of truth.)"`. Proceed to Step 6 — this is an accepted fallback, NOT a halt.
   - **2** → pandoc absent: log `"⚠ pandoc not installed — skipped render (FSD.md is complete). Run: brew install pandoc"`. Proceed to Step 6.
   - **1** → real render error: emit halt `quality_gate_failed` subtype `pdf_render_failed`, details `{md2pdf_stderr_tail: <last 500 chars>}`; STOP.
3. If any `mmdc absent`/`mmdc failed` warning appeared, surface it: `"⚠ mermaid rendered as code (mmdc absent) — install npm i -g @mermaid-js/mermaid-cli for diagrams."`

### Step 6: Verify citation map exists

Citation map already written by Step 4.6 (`missing_sources[]` included — script-derived from the `[Pending — …]` markers) — verify `<vault>/fsd/.citation-map.json` exists; if absent, re-run Step 4.6.

### Step 6.5: Doc-control stamp (script-run)

Run `bash <plugin-root>/scripts/refresh-doc-stamps.sh --vault=<vault> --doc=fsd --maturity=<pre-development|post-development per Step 0 mode> --position="<pipeline digest, e.g. bolts 3/7 complete>" --generated-at=<now ISO8601> --bump --change-note="<derived>"`.

The doc-control block, the `version`/`status` fields, and the **Riwayat Revisi** region are SCRIPT-OWNED — the model never types any of them. Exit 2 → internal bug (FSD.md missing; re-check Step 4). Between full emissions, orchestrate-flow refreshes the `position` field at chain boundaries via the same script (~0 tokens — no re-emission needed for a state refresh).

**Change-note derivation (mandatory, never free prose):** build the note from the drift lines the BUILDER printed (Steps 0–4 — never a second drift run) — `NO_PRIOR` → `Emisi awal`; otherwise `Regenerasi §<list of DRIFT/GONE sections> — <n> sumber berubah` (e.g. `Regenerasi §2, §4 — 3 sumber berubah`); no drift lines at all → `Re-emisi tanpa perubahan sumber`. Version `1.0`/`2.0` + `status: approved` are minted ONLY by a human running `--approve --approver="Nama, Peran"` — the model NEVER passes `--approve`.

### Step 7: Emit handoff (when --auto flag)

Emit handoff YAML in chat (NOT to file — chat-block semantics), per the local template in §Handoff emission below (operative; `orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index).

See §Handoff emission below for template.

### Step 8: Summary to user (always)

Emit chat summary:

```
FSD generated (<mode>):
  Sections: <N>/<10> emitted (<excluded_count> excluded per --sections OR include_sections)
  Citations: <N> source-grounded entries
  Drift callouts: <N> sections changed since last emit
  PDF: <path OR "skipped (pandoc absent)" OR "fallback HTML (Chrome absent)">
  Suggested next: <Confluence upload OR re-emit after diff-vault OR no action>
```

## Halt protocol

Per `plugins/mega-sdd/references/halt-protocol.md §halt-protocol`. emit-fsd emits these halts:

- `dep_missing` — `vault_present_for_fsd` predictive check fails (no vault.json found)
- `quality_gate_failed` with subtype `pdf_render_failed` — pandoc exits non-zero in Step 5.3
- `quality_gate_failed` with subtype `template_slot_unfilled` — internal bug: a `{{slot}}` marker in fsd-template.md has no extraction rule in section-mapping.md (impossible if reference files are consistent; defensive check)
- `quality_gate_failed` with subtype `citation_unresolvable` — Step 4.6: FSD.md cites a source path that resolves to no existing file (fabricated or stale citation), detected deterministically by `scripts/build-citation-map.sh` exit 1; details carry the script's `UNRESOLVED`/`LEFTOVER` lines

No new halt types added by emit-fsd; all halts reuse existing taxonomy (`citation_unresolvable` is a SUBTYPE of the existing `quality_gate_failed`, per `plugins/mega-sdd/references/halt-protocol.md`).

## Handoff emission

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd`), emit handoff YAML at end of skill output per the local template below — the OPERATIVE spec (`orchestrate-flow/references/handoff-contract.md` owns only the base schema + routing index):

```yaml
handoff:
  emitted_by: emit-fsd
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:
    - <absolute path to <vault>/fsd/FSD.md>
    - <absolute path to <vault>/fsd/FSD.pdf>     # OR FSD.html if Chrome absent; OR absent line if pandoc absent
    - <absolute path to <vault>/fsd/.citation-map.json>
    - <absolute path to <vault>/fsd/FSD.styling.yaml>
  next_action:
    suggested_skill: null
    suggested_args: []
    rationale: "FSD emitted; upload <vault>/fsd/FSD.pdf to Confluence per corporate workflow."
  blockers: []   # populated on quality_gate_failed
  metrics:
    sections_emitted: <int>          # ≥0, ≤10 — count of FSD sections rendered
    sections_excluded: <int>         # ≥0, ≤10 — per --sections / include_sections filter
    citations_count: <int>           # ≥0 — total citations in .citation-map.json
    drift_callouts_count: <int>      # ≥0 — sections changed since last emit; 0 on first emit
    mode: <"pre-dev" | "post-dev">   #
    pdf_emitted: <true | false>      #
    fallback_format: <null | "html" | "markdown">  # when pandoc/Chrome absent
  scope:                             # OPTIONAL — when vault has scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256>
```

Status `halted` on `quality_gate_failed`. Required ONLY under `--auto`.

## Anti-hallucination rails

1. EVERY section text MUST trace to a source artifact via `.citation-map.json` entry — the map is SCRIPT-COMPUTED by `scripts/build-citation-map.sh` (Step 4.6); the model never writes the map
2. Missing source MUST emit `[Pending — <source> not yet generated]` — NEVER fabricate content
3. Slot markers `{{slot_name}}` MUST all be filled OR explicitly placeholdered — empty slot = halt `quality_gate_failed:template_slot_unfilled`
4. sha256 stamps are computed at emit-time by `build-citation-map.sh` from file bytes — the model never writes a hash string (it emits the literal `(sha256: pending)`); a citation to a nonexistent path is a deterministic halt (`citation_unresolvable`), not a guess
5. Drift callouts MUST surface in PDF — silent regeneration would hide content changes from reviewers (drift list produced by `scripts/build-citation-map.sh (--check-drift mode)`, the map's only sanctioned reader)
