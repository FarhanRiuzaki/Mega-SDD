---
name: emit-uat
version: 1.0.1
description: Generate a UAT test-script document for the business UAT team — business-language scenarios 1:1 per F-* flow (aligned to SIT TS ids), step tables with placeholder execution columns, compact RTM, berita acara UAT page (SEOJK 21/2017), plus a zero-dep xlsx workbook for testers. Triggers — "generate UAT", "emit UAT", "buat UAT", "dokumen UAT", "test script UAT", "skrip uji UAT", "UAT script", "berita acara UAT", or paraphrases.
---

# Emit-UAT — User Acceptance Test Script Generator

**Announce at start:** "I'm using the emit-uat skill to generate the UAT test-script from the current vault flows + DoD. `mega-sdd-trace:emit-uat`"

> **Output language (Tier-3 artifact):** UAT body prose + headings the plugin authors → **Indonesian + English technical terms by default** (precedence: explicit request > the language the user writes in > Indonesian). **Quoted / flattened source content — flow titles, DoD items — and every `[Source: sha256:…]` citation are reproduced in their source language / raw bytes, never translated** (citation discipline, moat invariant #3). Tier-1 structural tokens stay English. Full rules → `plugins/mega-sdd/references/output-language.md`.

> **Doc-pack contract:** emit-uat is the UAT **doc-pack** of the shared emission engine — `plugins/mega-sdd/references/emission-engine.md` owns the doc-agnostic spine; this skill + `references/uat-sections.md` + `references/uat-template.md` bind that spine to every UAT-specific rule. The UAT is a **document the business team reads and executes by hand — an OUTPUT, never a decision surface**: OQ resolution and analysis stay in-skill; execution results are captured by HUMANS in the xlsx workbook / berita acara, never by the model.

## When to use

- "generate UAT" / "emit UAT" / "buat UAT" / "dokumen UAT" / "test script UAT" / "berita acara UAT"
- After a SIT exists and its berita acara is received (ideal — SEOJK 21/2017 §2.3.1.5 entry gate)
- Earlier, for UAT prep: the script may be PREPARED before SIT is executed (warn-only — see §1 callout)
- Re-emission after flow / unit changes (scenarios + RTM regenerate; existing execution results are guarded)

## Inputs

- `<vault-path>` (positional, optional — defaults to first vault detected via `plugins/mega-sdd/references/paths.md` priority order)
- `--vaults=<comma-list>` (multi-scope merge — ONE UAT, per-scope sections, ids `UAT-<SCOPE>-NNN` aligned 1:1 with `TS-<SCOPE>-NNN`; SIT decision-10 semantics)
- `--no-pdf` (markdown-only; skip the md2pdf render)
- `--no-xlsx` (skip the tester workbook render)
- `--auto` (orchestrator-invoked; emit handoff YAML in chat per `mega-sdd:orchestrate-flow/references/handoff-contract.md`)

## Outputs

```
<vault-path>/uat/
├── UAT.md                      # 4-section UAT script (see references/uat-template.md)
├── UAT.pdf                     # GitHub-style PDF via scripts/md2pdf.sh (Chrome; UAT.html fallback if Chrome absent)
├── UAT-v<version>.xlsx         # tester fill-in workbook (build-uat-xlsx.sh; version from .doc-history.json)
├── .uat-scaffold.md            # script-written fragment (build-uat-scaffold.sh) — the §1–§4 tables/scaffold
└── .citation-map.json          # script-written by build-citation-map.sh --doc=uat
```

## Pre-flight checks

1. **vault_present_for_uat**: `test -f <vault-path>/vault.json` OR vault docs `0[0-6]-*.md` present — required (halt `dep_missing` if absent)
2. **pandoc_installed**: `command -v pandoc` — warn if absent (degraded to markdown-only — or run `/mega-sdd:install-deps` to install automatically)
3. **chrome_present** / **mmdc_present**: warn-only (Chrome → PDF else GitHub-styled HTML; mmdc → mermaid diagrams else code). PDF style is github.css, never LaTeX.

## Procedure

### Step 0: Scaffold build + execution-fabrication re-emit guard (script-run)

Run `bash <plugin-root>/scripts/build-uat-scaffold.sh --vault=<vault> [--vault=<vault2> …] --cwd=<project-root>` FIRST (translate the user's `--vaults=v1,v2` into repeated `--vault=` — the script only accepts `--vault=`). It writes `<vault>/uat/.uat-scaffold.md` (the §1–§4 tables + step-table skeletons, script-derived) and prints `uat-scaffold: maturity=draft scenarios=<N> units=<M> sit=<probe> …`.

- **Maturity is ALWAYS `draft`** — the model never self-promotes. Ladder `draft → ready-for-uat → signed-off`; the upper rungs are HUMAN-set via `refresh-doc-stamps.sh --maturity=…` (PRD precedent — self-promotion fabricates an approval state), and the model NEVER passes them.
- Exit 1 → an EXISTING `UAT.md` carries a filled execution / sign-off cell: halt `quality_gate_failed:execution_fabricated` (see §Halt protocol) with the script's violation lines + keterangan verbatim. STOP — never re-emit over a forged record.
- Exit 2 → usage / vault problem; re-check the vault path.
- **`WARN_SIT` line printed** → surface it as the §1 warning callout (warn-only — the SEOJK berita-acara-SIT entry gate is a checklist reality, not an emission blocker; preparing UAT scripts early is legitimate).

Announce: `"UAT maturity: draft (script-stamped — rung atas di-set manusia); SIT entry-gate: <sit probe>"`.

### Step 1: Prior-emit drift check (script-run)

Run `bash <plugin-root>/scripts/check-citation-drift.sh --vault=<vault> --cwd=<project-root> --doc=uat` and consume ONLY its output lines (`DRIFT` / `GONE` / `UNVERIFIED` / `NO_PRIOR` / `PRIOR_UNREADABLE`). Flagged sections get a drift callout block quote on re-emit using the script's `old12`/`new12` prefixes verbatim. NEVER read `.citation-map.json` directly.

### Step 2: Per-section emission loop

For each section 1–4, follow `references/uat-sections.md §N`:

- **The §1–§4 tables, RTM rows, berita acara, and sign-off table come VERBATIM from `.uat-scaffold.md`** (between its `<!-- uat-scaffold:§N -->` delimiters). The model writes the surrounding Indonesian narrative AND — the ONE sanctioned in-fragment edit — replaces each `<!-- uat-steps:UAT-NNN -->` marker with step rows.
- **Step-row derivation (§2 only):** Aksi = business language derived 1:1 from the flow's Mermaid nodes/edges (one step per meaningful node — NEVER an invented step); Expected Result = the DoD items VERBATIM; the execution cells are the EXACT placeholder literals (Actual Result / Defect / Bukti = `__________`, Status = `[ ] Pass · [ ] Fail · [ ] Blocked`). A flow with no derivable steps → ONE row whose Aksi cell is `[Pending — flow <F-id> belum punya diagram/DoD untuk diturunkan]` (execution cells still the exact placeholders).
- Never edit a fragment cell; never add/remove an RTM/berita-acara/sign-off row; never redraw a Mermaid diagram; never fill an execution or sign-off cell (that is a fabricated record, blocked in Step 4.7).

**Stamp rule (engine-invariant):** every citation stamp is the LITERAL `(sha256: pending)` — the model MUST NOT write hash characters (Step 4.6's script stamps real prefixes).

### Step 3: Assemble UAT.md

Fill `references/uat-template.md` slots (frontmatter header + per-section narrative slots + verbatim fragment blocks) and write `<vault>/uat/UAT.md`.

### Step 4.5: Unfilled-slot scan

`grep -oE '\{\{[a-z0-9_-]+\}\}' <vault>/uat/UAT.md` — ANY hit → halt `quality_gate_failed:template_slot_unfilled`; STOP before render. (UAT lane uses this in-skill scan, mirroring SIT/PRD; `validate-fsd-slots.sh` stays FSD-scoped.)

### Step 4.6: Stamp citations + write the map (script-run, BEFORE render)

Run `bash <plugin-root>/scripts/build-citation-map.sh --vault=<vault> --cwd=<project-root> --mode=draft --doc=uat`.

- Exit 0 → stamps real, `<vault>/uat/.citation-map.json` written (incl. script-derived `missing_sources[]`). Proceed.
- Exit 1 → halt `quality_gate_failed:citation_unresolvable` carrying the script's `UNRESOLVED`/`LEFTOVER` lines; do NOT render.
- Exit 2 → internal bug (UAT.md missing) — re-check Step 3.

### Step 4.7: Execution-fabrication gate (script-run, MANDATORY)

Run `bash <plugin-root>/scripts/build-uat-scaffold.sh --check-execution --vault=<vault>`.

- Exit 0 → every execution / sign-off cell is still a placeholder literal. Proceed.
- Exit 1 → halt `quality_gate_failed:execution_fabricated` with the script's violation lines (`EXECUTION_FILLED` / `EXECUTION_SHAPE` / `STEPS_MISSING` / `RTM_FILLED` / `BA_FILLED` / `SIGNOFF_FILLED` / `SIGNOFF_SHAPE` / `BA_SECTION_MISSING`) + keterangan verbatim; STOP — a model-filled execution or sign-off cell is a fabricated test record (SEOJK context) and must never render. The model restores the placeholder literals; it NEVER "completes" a result.

### Step 5: Render PDF via md2pdf (optional)

Same lane as emit-sit Step 5 — `bash "${CLAUDE_PLUGIN_ROOT}/scripts/md2pdf.sh" <vault>/uat/UAT.md <vault>/uat/UAT.pdf --toc` (GitHub/VS Code style, NEVER LaTeX; throwaway-copy transforms keep `UAT.md`'s citation sha intact). Exit 0 → `UAT.pdf`; exit 3 → Chrome absent, `UAT.html` fallback (accepted); exit 2 → pandoc absent (skip); exit 1 → halt `quality_gate_failed:pdf_render_failed`. `--no-pdf` skips.

### Step 6: Doc-control stamp + version bump (script-run)

Run `bash <plugin-root>/scripts/refresh-doc-stamps.sh --vault=<vault> --doc=uat --maturity=draft --position="<pipeline digest, e.g. scenarios 5, sit=executed>" --generated-at=<now ISO8601> --bump --change-note="<derived>"`. The doc-control block, the `version`/`status` fields, and the **Riwayat Revisi** region are SCRIPT-OWNED — the model never types any of them. Maturity is ALWAYS `draft` at emit.

**Change-note derivation (mandatory, never free prose):** build the note from Step 1's drift output — `NO_PRIOR` → `Emisi awal`; otherwise `Regenerasi §<list of DRIFT/GONE sections> — <n> sumber berubah` (e.g. `Regenerasi §2, §3 — 2 sumber berubah`); no drift lines at all → `Re-emisi tanpa perubahan sumber`. Version `1.0`/`2.0` + `status: approved` and the `ready-for-uat`/`signed-off` maturity rungs are minted ONLY by a human running `--approve --approver="Nama, Peran"` / `--maturity=…` — the model NEVER passes `--approve`.

### Step 6.6: Render tester workbook (script-run, WARN-ONLY)

Run `bash <plugin-root>/scripts/build-uat-xlsx.sh --vault=<vault>` → `<vault>/uat/UAT-v<version>.xlsx`. Every nonzero exit is WARN-ONLY (surface the line; `UAT.md` stays canonical, never a halt): exit 3 = target `UAT-v<version>.xlsx` already exists → REFUSE (a tester may have filled it — never overwritten); exit 1/2 = parse/usage. `--no-xlsx` skips.

### Step 7: Handoff (when --auto) + summary (always)

Handoff YAML per §Handoff emission below. Chat summary:

```
UAT generated (maturity: draft):
  Skenario: <N> UAT (1:1 dari F-* flows, sejajar TS-* SIT) · Langkah total: <S>
  SIT entry-gate: <absent|unset|planned|partial|executed> (SEOJK §2.3.1.5)
  Workbook: <path OR "REFUSE — sudah ada" OR "dilewati (--no-xlsx)">
  Berita acara UAT: placeholder literal — Go/No-Go + sign-off diisi MANUSIA saat pelaksanaan
  PDF: <path OR fallback note>
```

## Halt protocol

Per `plugins/mega-sdd/references/halt-protocol.md`. emit-uat emits: `dep_missing` (no vault), `quality_gate_failed` with subtypes `template_slot_unfilled`, `citation_unresolvable`, `pdf_render_failed`, and **`execution_fabricated`** (a §2 execution cell / tester footer, §3 RTM status, or §4 berita-acara/sign-off cell carries non-placeholder text — detected deterministically by `build-uat-scaffold.sh --check-execution`; details carry the script's violation lines; keterangan frames it as a fabricated record). All are subtypes of the existing `quality_gate_failed` — **no new halt TYPES**.

## Handoff emission

When invoked with `--auto`, emit handoff YAML in chat (base schema per `orchestrate-flow/references/handoff-contract.md`):

```yaml
handoff:
  emitted_by: emit-uat
  emitted_at: <ISO8601>
  status: completed | halted
  artifacts:
    - <abs path to <vault>/uat/UAT.md>
    - <abs path to <vault>/uat/UAT.pdf>            # when rendered
    - <abs path to <vault>/uat/UAT-v<version>.xlsx> # when rendered (not refused/skipped)
    - <abs path to <vault>/uat/.citation-map.json>
  next_action:
    suggested_skill: null
    suggested_args: []
    rationale: "UAT emitted at maturity draft; eksekusi + sign-off dilakukan manusia (workbook xlsx / berita acara)."
  blockers: []
  metrics:
    maturity: "draft"
    scenarios: <int>
    steps_total: <int>
    sit_maturity: <"absent" | "unset" | "planned" | "partial" | "executed">
    xlsx: <path | "refused" | "skipped">
    scopes: <csv or "-">
```

## Memory layer

Out of scope: emit-uat does NOT participate in the memory layer. UAT generation is deterministic from vault flows + DoD.

## Anti-hallucination rails

1. Execution results are NEVER model-authored — the xlsx workbook + berita acara UAT are the HUMAN capture surfaces; a filled §2 execution cell / §3 RTM status / §4 berita-acara or sign-off cell is a fabricated record → deterministic `execution_fabricated` halt (Step 4.7), never a prose-trusted check.
2. §2 Aksi step rows trace 1:1 to the flow's Mermaid nodes (business language, one step per meaningful node/edge) — never an invented step; a flow with no derivable steps gets ONE `[Pending — …]` row, never fabricated content.
3. The flow's Mermaid diagram + DoD items ride VERBATIM from the scaffold fragment — never redrawn, never summarized into prose (the Mermaid-flows hard rule extends to UAT). Expected Result cells are the DoD items verbatim.
4. Every section traces to sources via the SCRIPT-COMPUTED citation map (`--doc=uat`); the model emits only the literal `(sha256: pending)`.
5. Maturity is ALWAYS `draft` at emit; the `version` / `status` / **Riwayat Revisi** region are script-owned (`refresh-doc-stamps.sh`) — the model never types them and never self-promotes the maturity rung.
