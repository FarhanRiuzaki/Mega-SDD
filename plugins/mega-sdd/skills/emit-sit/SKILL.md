---
name: emit-sit
version: 1.0.2
description: Generate a bank-style SIT — TS scenarios from F-* flows (Mermaid verbatim), TC traceability matrix, script-derived executed-evidence tables, sign-off rows as placeholder literals; maturity computed from evidence. Triggers — "generate SIT", "emit SIT", "buat SIT", "dokumen SIT", "SIT untuk UAT", "bukti eksekusi test", or paraphrases.
---

# Emit-SIT — System Integration Test Document Generator

**Announce at start:** "I'm using the emit-sit skill to generate the SIT from the current vault + bolt evidence. `mega-sdd-trace:emit-sit`"

> **Output language (Tier-3 artifact):** SIT body prose + headings the plugin authors → **Indonesian + English technical terms by default** (precedence: explicit request > the language the user writes in > Indonesian). **Quoted / flattened source content — flow titles, DoD items, raw runner output in evidence cells — and every `[Source: sha256:…]` citation are reproduced in their source language / raw bytes, never translated** (citation discipline, moat invariant #3). Terse/technical source notation is quoted verbatim in code spans with an Indonesian gloss — never translated in place. Tier-1 structural tokens stay English. Full rules → `plugins/mega-sdd/references/output-language.md`.

> **Doc-pack contract:** emit-sit is the SIT **doc-pack** of the shared emission engine — `plugins/mega-sdd/references/emission-engine.md` owns the doc-agnostic spine; this skill + `references/sit-sections.md` + `references/sit-template.md` bind that spine to every SIT-specific rule. The SIT is a **document the team reads — an OUTPUT, never a decision surface**: OQ resolution and analysis stay in-skill; resolutions flow into the next emission.

## When to use

- "generate SIT" / "emit SIT" / "buat SIT" / "dokumen SIT" / "SIT untuk UAT"
- After execute-bolts produced acceptance evidence (`bolts/U-*/acceptance.json`) — the §4 executed column reads it
- Before bolts run: a *planned*-maturity SIT (scenarios + matrix; evidence rows all `[Pending]`) is valid for test-plan review
- Re-emission after new bolt runs / resolved OQs (maturity climbs planned → partial → executed)

## Inputs

- `<vault-path>` (positional, optional — defaults to first vault detected via `plugins/mega-sdd/references/paths.md` priority order)
- `--vaults=<comma-list>` (multi-scope merge — ONE SIT, per-scope sections, ids `TS-<SCOPE>-NNN`; scope id from each vault's `vault.json scope_metadata.id`)
- `--no-pdf` (markdown-only; skip the md2pdf render)
- `--auto` (orchestrator-invoked; emit handoff YAML in chat per `mega-sdd:orchestrate-flow/references/handoff-contract.md`)

## Outputs

```
<vault-path>/sit/
├── SIT.md                      # 5-section SIT (see references/sit-template.md)
├── SIT.pdf                     # GitHub-style PDF via scripts/md2pdf.sh (Chrome; SIT.html fallback if Chrome absent)
├── .sit-evidence.md            # script-written fragment (build-sit-evidence.sh) — the §1–§5 tables
└── .citation-map.json          # script-written by build-citation-map.sh --doc=sit
```

## Pre-flight checks

1. **vault_present_for_sit**: `test -f <vault-path>/vault.json` OR vault docs `0[0-6]-*.md` present — required (halt `dep_missing` if absent)
2. **pandoc_installed**: `command -v pandoc` — warn if absent (degraded to markdown-only — or run `/mega-sdd:install-deps` to install automatically)
3. **chrome_present** / **mmdc_present**: warn-only (Chrome → PDF else GitHub-styled HTML; mmdc → mermaid diagrams else code). PDF style is github.css, never LaTeX.

## Procedure

### Step 0: Maturity/mode detection (script-run)

Run `bash <plugin-root>/scripts/build-sit-evidence.sh --vault=<vault> [--vault=<vault2> …] --cwd=<project-root>` FIRST. It writes `<vault>/sit/.sit-evidence.md` (the §1–§5 tables, script-derived) and prints ONE line including `maturity=<planned|partial|executed>` — that verdict IS the doc's maturity; the model never computes it.

- Exit 1 → an EXISTING `SIT.md` has a filled sign-off row: halt `quality_gate_failed` with subtype `signoff_fabricated` (see §Halt protocol) carrying the script's `SIGNOFF_*` lines + keterangan verbatim. STOP — never re-emit over a forged record.
- Exit 2 → usage/vault problem; re-check the vault path.

Announce: `"SIT maturity: <verdict> (script-derived — <executed>/<units> units carry acceptance evidence)"`.

### Step 1: Prior-emit drift check (script-run)

Run `bash <plugin-root>/scripts/check-citation-drift.sh --vault=<vault> --cwd=<project-root> --doc=sit` and consume ONLY its output lines (`DRIFT` / `GONE` / `UNVERIFIED` / `NO_PRIOR` / `PRIOR_UNREADABLE`). Flagged sections get a drift callout block quote on re-emit using the script's `old12`/`new12` prefixes verbatim. NEVER read `.citation-map.json` directly.

### Step 2: Per-section emission loop

For each section 1–5, follow `references/sit-sections.md §Section N`:

- **The §1–§5 tables, TS scenario blocks (Mermaid + DoD), evidence rows, and sign-off tables come VERBATIM from `.sit-evidence.md`** (between its `<!-- sit-evidence:§N -->` delimiters). The model writes ONLY the surrounding Indonesian narrative (one short paragraph per section — apa yang diuji, bagaimana membaca tabelnya). Never edit a fragment cell; never add/remove a row; never redraw a Mermaid diagram.
- Absent source → the fragment already carries the `[Pending — …]` placeholder; keep it — NEVER replace a Pending marker with invented content (per decision 9, unknown/absent runner evidence is recorded raw or Pending, counts never fabricated).
- **§5 Sign-off body rows stay placeholder LITERALS** (`__________` / `[ ] Diterima · [ ] Ditolak`). Filling one = fabricated record (deterministically blocked in Step 4.7).

**Stamp rule (engine-invariant):** every citation stamp is the LITERAL `(sha256: pending)` — the model MUST NOT write hash characters (Step 4.6's script stamps real prefixes).

### Step 3: Assemble SIT.md

Fill `references/sit-template.md` slots (frontmatter header + per-section narrative slots + verbatim fragment blocks) and write `<vault>/sit/SIT.md`.

### Step 4.5: Unfilled-slot scan

`grep -oE '\{\{[a-z0-9_-]+\}\}' <vault>/sit/SIT.md` — ANY hit → halt `quality_gate_failed` with subtype `template_slot_unfilled`; STOP before render. (SIT/PRD lanes use this in-skill scan — `validate-fsd-slots.sh` stays FSD-scoped per `plugins/mega-sdd/references/emission-engine.md §P5 seams`.)

### Step 4.6: Stamp citations + write the map (script-run, BEFORE render)

Run `bash <plugin-root>/scripts/build-citation-map.sh --vault=<vault> --cwd=<project-root> --mode=<maturity> --doc=sit`.

- Exit 0 → stamps real, `<vault>/sit/.citation-map.json` written (incl. script-derived `missing_sources[]`). Proceed.
- Exit 1 → halt `quality_gate_failed:citation_unresolvable` carrying the script's `UNRESOLVED`/`LEFTOVER` lines; do NOT render.
- Exit 2 → internal bug (SIT.md missing) — re-check Step 3.

### Step 4.7: Sign-off slot-grammar gate (script-run, MANDATORY)

Run `bash <plugin-root>/scripts/build-sit-evidence.sh --check-signoff --vault=<vault>`.

- Exit 0 → sign-off rows are still placeholder literals. Proceed.
- Exit 1 → halt `quality_gate_failed` subtype `signoff_fabricated` with the script's `SIGNOFF_*` lines + keterangan verbatim; STOP — a model-filled sign-off row is a fabricated approval record (decision 5) and must never render.

### Step 5: Render PDF via md2pdf (optional)

Same lane as emit-fsd Step 5 — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/md2pdf.sh" <vault>/sit/SIT.md <vault>/sit/SIT.pdf --toc` (GitHub/VS Code style, NEVER LaTeX; throwaway-copy transforms keep `SIT.md`'s citation sha intact). Exit 0 → `SIT.pdf`; exit 3 → Chrome absent, `SIT.html` fallback (accepted); exit 2 → pandoc absent (skip); exit 1 → halt `quality_gate_failed:pdf_render_failed`. `--no-pdf` skips.

### Step 6: Doc-control stamp (script-run)

Run `bash <plugin-root>/scripts/refresh-doc-stamps.sh --vault=<vault> --doc=sit --maturity=<Step 0 verdict> --position="<pipeline digest, e.g. bolts 3/7 executed>" --generated-at=<now ISO8601> --bump --change-note="<derived>"`. The doc-control block, the `version`/`status` fields, and the **Riwayat Revisi** region are SCRIPT-OWNED — the model never types any of them.

**Change-note derivation (mandatory, never free prose):** build the note from Step 1's drift output — `NO_PRIOR` → `Emisi awal`; otherwise `Regenerasi §<list of DRIFT/GONE sections> — <n> sumber berubah` (e.g. `Regenerasi §2, §4 — 3 sumber berubah`); no drift lines at all → `Re-emisi tanpa perubahan sumber`. Version `1.0`/`2.0` + `status: approved` are minted ONLY by a human running `--approve --approver="Nama, Peran"` — the model NEVER passes `--approve`.

### Step 7: Handoff (when --auto) + summary (always)

Handoff YAML per §Handoff emission below. Chat summary:

```
SIT generated (maturity: <planned|partial|executed>):
  Skenario: <N> TS (1:1 dari F-* flows) · Test case: <M> TC
  Bukti eksekusi: <E>/<U> units (acceptance) · manual menunggu: <K>
  Sign-off: placeholder literal (paper-out — diisi manusia di dokumen cetak)
  PDF: <path OR fallback note>
```

## Halt protocol

Per `plugins/mega-sdd/references/halt-protocol.md`. emit-sit emits: `dep_missing` (no vault), `quality_gate_failed` with subtypes `template_slot_unfilled`, `citation_unresolvable`, `pdf_render_failed`, and **`signoff_fabricated`** (a §5 body row carries non-placeholder text — detected deterministically by `build-sit-evidence.sh --check-signoff`; details carry the script's `SIGNOFF_*` lines; keterangan frames it as a fabricated record). All are subtypes of the existing `quality_gate_failed` — no new halt types.

## Handoff emission

When invoked with `--auto`, emit handoff YAML in chat (base schema per `orchestrate-flow/references/handoff-contract.md`):

```yaml
handoff:
  emitted_by: emit-sit
  emitted_at: <ISO8601>
  status: completed | halted
  artifacts:
    - <abs path to <vault>/sit/SIT.md>
    - <abs path to <vault>/sit/SIT.pdf>          # when rendered
    - <abs path to <vault>/sit/.citation-map.json>
  next_action:
    suggested_skill: null
    suggested_args: []
    rationale: "SIT emitted at maturity <verdict>; sign-off dilakukan manusia di dokumen cetak."
  blockers: []
  metrics:
    maturity: <"planned" | "partial" | "executed">
    ts_count: <int>
    tc_count: <int>
    units_with_evidence: <int>
    units_total: <int>
    pending_manual_count: <int>
    scopes: <csv or "-">
```

## Memory layer

Out of scope: emit-sit does NOT participate in the memory layer. SIT generation is deterministic from vault + evidence state.

## Anti-hallucination rails

1. §4 evidence is SCRIPT-DERIVED (`build-sit-evidence.sh` reading the hook-guarded `acceptance.json`/`postflight.json`/`_batch-suite.json`) — the model NEVER authors an evidence cell; absent evidence stays `[Pending — bolt U-XXX belum dieksekusi]`, counts never fabricated (decision 9: unknown runner output recorded raw).
2. TS scenarios carry the vault flow's Mermaid VERBATIM — never redrawn, never summarized into prose (the Mermaid-flows hard rule extends to SIT).
3. §5 sign-off body rows are placeholder LITERALS; a filled row = fabricated record → deterministic `signoff_fabricated` halt (Step 4.7) — never a prose-trusted check.
4. Every section traces to sources via the SCRIPT-COMPUTED citation map (`--doc=sit`); the model emits only the literal `(sha256: pending)`.
5. Maturity is the script's verdict — the model never claims `executed` without full evidence coverage.
