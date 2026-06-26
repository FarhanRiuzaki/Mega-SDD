---
name: emit-fsd
version: 1.2.1
description: Generate a Hybrid Confluence-format FSD (Functional Specification Document) — Markdown + PDF — from a mega-sdd vault. Grounded on actual vault/units/bolts/binding artifacts with sha256-stamped citation discipline per `.citation-map.json`. Mode auto-detect — pre-development (vault only) vs post-development (vault + bolts). PDF via pandoc + xelatex/tectonic; HTML fallback when LaTeX absent; markdown-only when pandoc absent. Triggers — "generate FSD", "emit FSD", "buat FSD", "FSD untuk confluence", or paraphrases.
---

# Emit-FSD — Functional Specification Document Generator

**Announce at start:** "I'm using the emit-fsd skill to generate the FSD from the current vault."

## When to use

- "generate FSD" / "emit FSD" / "buat FSD" / "FSD untuk confluence"
- Pre-development sign-off: after generate-intent stabilizes the vault, before bolts run
- Post-development as-built record: after execute-bolts completes
- Re-emission on PRD revision (diff-vault) or OQ resolution (resolve-oq)

## Inputs

- `<vault-path>` (positional, optional — defaults to first vault detected via `plugins/mega-sdd/references/paths.md` priority order)
- `--mode={pre-dev|post-dev|auto}` (default: `auto` — detect from CWD state)
- `--no-pdf` (markdown-only; useful when pandoc/LaTeX absent)
- `--styling=<path-to-yaml>` (override default `FSD.styling.yaml`)
- `--sections=<comma-list>` (emit subset; e.g., `--sections=1,2,5,7,8,10`)
- `--auto` (orchestrator-invoked; emit handoff YAML in chat per `mega-sdd:orchestrate-flow/references/handoff-contract.md`)

## Outputs

```
<vault-path>/fsd/
├── FSD.md                      # source markdown (10-section Hybrid Confluence template)
├── FSD.pdf                     # rendered PDF via pandoc (absent if pandoc/LaTeX unavailable)
├── FSD.styling.yaml            # styling config (generated on first run; preserved on re-emit)
└── .citation-map.json          # vault-section → FSD-section citation trace
```

## Pre-flight checks

1. **vault_present_for_fsd**: `test -f <vault-path>/vault.json` — required (halt `dep_missing` if absent)
2. **pandoc_installed**: `command -v pandoc` — warn if absent (degraded to markdown-only)
3. **pandoc_latex_engine_present**: `command -v xelatex || command -v tectonic` — warn if absent (degraded to HTML fallback)

Full preflight catalog: `mega-sdd:orchestrate-flow/references/predictive-checks.md` §emit-fsd preflight checks.

## Procedure

### Step 0: Mode detection

Inspect CWD state per `references/section-mapping.md §Mode determination`:

```
IF <vault>/bolts/ exists AND has ≥1 U-*/bolt-report.md → mode = post-dev
ELIF <vault>/units/ exists AND has ≥1 U-*.md → mode = pre-dev (with breakdown)
ELSE → mode = pre-dev (vault-only)
```

User flag `--mode={pre-dev|post-dev|auto}` overrides detection. `auto` (default) uses detection result.

Emit detected mode + reasoning to chat: `"FSD mode: <mode> (detected via: <CWD state evidence>)"`.

### Step 1: Read styling config

1. Check `<vault>/fsd/FSD.styling.yaml` — if exists, load.
2. Else, copy `references/styling-config.yaml` to `<vault>/fsd/FSD.styling.yaml` and load.
3. If `--styling=<path>` flag passed, load that path instead (overrides both).
4. Resolve template variables: `project_name` from `vault.json.project_name` if styling has null; `vault_version` from `vault.json.vault_version`; `generation_date_*` from current ISO8601.

### Step 2: Read prior citation map (drift detection)

1. Check `<vault>/fsd/.citation-map.json` — if exists, parse as `prior_citation_map`.
2. Else, `prior_citation_map = null` (first emit; no drift to detect).

### Step 3: Per-section emission loop

For each section N in 1-10 (filter by `styling.include_sections` if not "all"):

a. Look up extraction rules in `references/section-mapping.md §Section N`.
b. For each declared source artifact: check existence + read content + compute sha256.
c. Apply extraction rules to produce slot content.
d. If any source artifact absent: emit `[Pending — <source> not yet generated]` placeholder per anti-hallucination rule.
e. Compute `emitted_text_sha256` of slot content.
f. Compare `source_sha256` vs `prior_citation_map.sections[].source_sha256` (if applicable):
   - Mismatch → flag section for drift callout; insert callout block quote BEFORE section content
   - Match → no callout
   - First emit (no prior) → no callout
g. Append entry to in-memory `citation_map.sections[]`.
h. Substitute slot in `references/fsd-template.md §Section N` template.

### Step 4: Assemble FSD.md

1. Start from `references/fsd-template.md` (full template).
2. For each `{{slot_name}}` marker: replace with computed slot content from Step 3.
3. Add YAML frontmatter at top (per fsd-template.md §Document control header) with resolved styling + vault metadata.
4. Write to `<vault>/fsd/FSD.md`.

### Step 4.5: Post-emission unfilled-slot scan

After Step 4 writes `<vault>/fsd/FSD.md`, scan the file for any remaining `{{...}}` slot markers (defensive check — should be impossible if Step 3 extracted all slots correctly).

```bash
# Defensive scan:
grep -oE '\{\{[a-z0-9_-]+\}\}' <vault>/fsd/FSD.md
```

If ANY match found → emit halt `quality_gate_failed` with `subtype: template_slot_unfilled` per vault-contract.md §quality_gate_failed subtypes:

```yaml
type: quality_gate_failed
source_skill: emit-fsd
details:
  subtype: template_slot_unfilled
  unfilled_slots: ["{{section-3-stakeholders-table}}", "{{section-7-binding-confirmed-content}}"]
  fsd_path: <vault>/fsd/FSD.md
next_action: "Internal bug: fsd-template.md has slot marker(s) that section-mapping.md has no extraction rule for. File plugin bug at github.com/FarhanRiuzaki/Mega-SDD/issues. Meanwhile, skip affected section via --sections=<csv> excluding the failing section."
```

STOP — do NOT proceed to Step 5 (pandoc render). Shipping unfilled `{{...}}` literals to PDF OR allowing pandoc to interpret them as template variables would be an anti-hallucination rail break.

### Step 5: Render PDF via pandoc

1. Check `pandoc` availability:
   - Absent → skip Step 5; log warning to chat: `"⚠ pandoc not installed — skipping PDF render. Run: brew install pandoc"`; proceed to Step 6.
2. Check LaTeX engine:
   - `xelatex` present → engine = xelatex
   - `tectonic` present → engine = tectonic
   - Neither → fallback to HTML output: `pandoc <vault>/fsd/FSD.md -o <vault>/fsd/FSD.html --standalone --self-contained`; log warning: `"⚠ no LaTeX engine — emitted FSD.html instead of FSD.pdf. Print-to-PDF from browser. Install: brew install tectonic"`; proceed to Step 6.
3. Run pandoc:
   ```bash
   pandoc <vault>/fsd/FSD.md \
     -o <vault>/fsd/FSD.pdf \
     --template=plugins/mega-sdd/skills/emit-fsd/references/pandoc-template.tex \
     --pdf-engine=<engine> \
     --toc \
     --toc-depth=<styling.toc_depth> \
     --variable=<styling-key>=<value>... \
     --listings
   ```
4. On pandoc non-zero exit: emit halt `quality_gate_failed` with subtype `pdf_render_failed`, details `{pandoc_stderr_tail: <last 500 chars>}`; STOP.
5. On success: log `"✓ FSD.pdf rendered (<N> pages, <size_kb>KB)"`.

### Step 5.5: Populate `missing_sources[]`

The citation-map schema declares a `missing_sources[]` array; this step populates it. Adds population logic:

During Step 3.d (per-section emission), when a source artifact is missing AND the section emits a `[Pending — X not yet generated]` placeholder, ALSO append an entry to in-memory `citation_map.missing_sources[]`:

```yaml
- section: "9"                                    # FSD section number
  expected_source: "bolts/U-*/bolt-report.md"     # source artifact path/pattern that was missing
  reason: "pre-dev mode (no bolts yet)"           # short rationale
```

Common reasons:
- `"pre-dev mode (no bolts yet)"` — section 9 in pre-dev mode
- `"vault file not generated yet"` — generic missing vault artifact
- `"binding.md absent — bind-codebase not run"` — section 7 design without binding
- `"codebase-map.md absent — scan-codebase not run"` — section 8 API/data without codebase scan

Step 6 writes `missing_sources[]` to `.citation-map.json` alongside `sections[]`.

**Consumer:** orchestrate-flow Step 7 final summary (when emit-fsd handoff received) can surface `len(missing_sources) > 0` as informational: "FSD emitted with N pending sections — full coverage available after running [scan-codebase / bind-codebase / execute-bolts]". Closes D4 (field was declared but unpopulated → consumer couldn't surface coverage gaps).

### Step 6: Write citation map

Write `<vault>/fsd/.citation-map.json` with `citation_map` assembled in Step 3, per `references/section-mapping.md §Citation map schema`.

### Step 7: Emit handoff (when --auto flag)

Per `mega-sdd:orchestrate-flow/references/handoff-contract.md`, emit handoff YAML in chat (NOT to file — chat-block semantics).

See §Handoff emission below for template.

### Step 8: Summary to user (always)

Emit chat summary:

```
FSD generated (<mode>):
  Sections: <N>/<10> emitted (<excluded_count> excluded per --sections OR include_sections)
  Citations: <N> source-grounded entries
  Drift callouts: <N> sections changed since last emit
  PDF: <path OR "skipped (pandoc absent)" OR "fallback HTML (LaTeX absent)">
  Suggested next: <Confluence upload OR re-emit after diff-vault OR no action>
```

## Halt protocol

Per `mega-sdd:generate-intent/references/vault-contract.md §halt-protocol`. emit-fsd emits these halts:

- `dep_missing` — `vault_present_for_fsd` predictive check fails (no vault.json found)
- `quality_gate_failed` with subtype `pdf_render_failed` — pandoc exits non-zero in Step 5.3
- `quality_gate_failed` with subtype `template_slot_unfilled` — internal bug: a `{{slot}}` marker in fsd-template.md has no extraction rule in section-mapping.md (impossible if reference files are consistent; defensive check)

No new halt types added by emit-fsd; all halts reuse existing taxonomy.

## Handoff emission

When invoked with `--auto` flag (typically by `orchestrate-flow --deep` or `/mega-sdd:auto`), emit handoff YAML at end of skill output per `mega-sdd:orchestrate-flow/references/handoff-contract.md`:

```yaml
handoff:
  emitted_by: emit-fsd
  emitted_at: <ISO8601 timestamp>
  status: completed | halted
  artifacts:
    - <absolute path to <vault>/fsd/FSD.md>
    - <absolute path to <vault>/fsd/FSD.pdf>     # OR FSD.html if LaTeX absent; OR absent line if pandoc absent
    - <absolute path to <vault>/fsd/.citation-map.json>
    - <absolute path to <vault>/fsd/FSD.styling.yaml>
  next_action:
    suggested_skill: null
    suggested_args: []
    rationale: "FSD emitted; upload <vault>/fsd/FSD.pdf to Confluence per corporate workflow."
  blockers: []   # populated on quality_gate_failed
  metrics:
    sections_emitted: <int>          #
    sections_excluded: <int>         # per --sections / include_sections filter
    citations_count: <int>           # total citations in .citation-map.json
    drift_callouts_count: <int>      # sections changed since last emit; 0 on first emit
    mode: <"pre-dev" | "post-dev">   #
    pdf_emitted: <true | false>      #
    fallback_format: <null | "html" | "markdown">  # when pandoc/LaTeX absent
  scope:                             # OPTIONAL — when vault has scope_metadata
    id: <scope id>
    name: <scope name>
    sibling_scopes: []
    prd_sha256: <sha256>
```

Status `halted` on `quality_gate_failed`. Required ONLY under `--auto`.

## Memory layer

Out of scope: emit-fsd does NOT participate in mega-sdd memory layer (no reads, no writes). FSD generation is deterministic from vault state; no learning needed.

## Anti-hallucination rails

1. EVERY section text MUST trace to a source artifact via `.citation-map.json` entry
2. Missing source MUST emit `[Pending — <source> not yet generated]` — NEVER fabricate content
3. Slot markers `{{slot_name}}` MUST all be filled OR explicitly placeholdered — empty slot = halt `quality_gate_failed:template_slot_unfilled`
4. sha256 stamps in citations MUST be computed at emit-time (not cached) — drift detection depends on freshness
5. Drift callouts MUST surface in PDF — silent regeneration would hide content changes from reviewers
