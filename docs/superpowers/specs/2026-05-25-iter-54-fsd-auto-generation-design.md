# Iter 54 — FSD Auto-Generation Design

**Status:** Design approved 2026-05-25
**Iter target:** v3.36.0 → v3.37.0 (MINOR — new skill)
**Driver:** user need — corporate Confluence FSD is mandatory deliverable; mega-sdd should auto-generate accurate FSD from vault/units/bolts state
**Spec author:** brainstorming session (auto mode active, user-confirmed each section)

---

## 1. Goal

One sentence: **Auto-generate a Hybrid Confluence-format FSD (PDF) from a mega-sdd vault, grounded on actual vault/units/bolts/binding artifacts with anti-hallucination citation discipline.**

## 2. Non-Goals

- Confluence REST API direct push (user uploads PDF to Confluence manually per their corporate flow)
- Cross-scope FSD consolidation (each scope vault gets its own FSD; manual concat if needed)
- FSD-to-FSD diff tooling (could add later as `mega-sdd:diff-fsd`)
- Multi-language FSD (English only — Indonesian translation deferred)
- Interactive FSD editing UI

## 3. User-facing surfaces

### 3.1 New skill: `mega-sdd:emit-fsd`

Standalone skill invocable via `/mega-sdd:emit-fsd [vault-path]`. Flags:
- `--mode={pre-dev|post-dev|auto}` (default: `auto` — detect from CWD state)
- `--no-pdf` (markdown-only output; useful when pandoc absent)
- `--styling=<path-to-yaml>` (override default `FSD.styling.yaml`)
- `--sections=<comma-list>` (emit subset; e.g., `--sections=1,2,5,7,8,10`)

### 3.2 Auto-invocation in `/mega-sdd:auto` pipeline

Added to `orchestrate-flow/SKILL.md` Step 6 auto-integrated diagnostics table (analog to existing `emit-agents-md` auto-invoke pattern, Iter 13). Disable via `--no-fsd` flag on `auto` / `orchestrate-flow`.

### 3.3 Command: `/mega-sdd:emit-fsd`

Slash command wrapper at `plugins/mega-sdd/commands/emit-fsd.md` (~30 lines, follows existing emit-agents-md.md pattern).

## 4. Skill anatomy

```
plugins/mega-sdd/skills/emit-fsd/
├── SKILL.md                    # main procedure (~200 lines)
├── references/
│   ├── fsd-template.md         # Hybrid Confluence section structure (10 sections, canonical)
│   ├── pandoc-template.tex     # LaTeX template for PDF styling
│   ├── section-mapping.md      # vault artifact → FSD section mapping rules + citation format
│   └── styling-config.yaml     # default styling config (overridable per-project)
```

No `_vendored/`, no runtime code — markdown-driven per plugin design principle.

## 5. Output structure

```
<vault-path>/fsd/
├── FSD.md                      # source markdown (10-section Hybrid template)
├── FSD.pdf                     # rendered PDF via pandoc
├── FSD.styling.yaml            # styling config (generated on first run; user-editable)
└── .citation-map.json          # vault-section → FSD-section citation trace (auditability)
```

Path co-located with vault for natural grouping; falls under `.gitignore`-able sub-tree if user wants (FSD.pdf often binary-large).

## 6. The 10 FSD sections + source-artifact grounding

Each section auto-generated from a source artifact with inline citation footnote `[¹]` linking back to source. Citation includes file path + line range + sha256 stamp.

| # | Section | Source artifact(s) | Citation format |
|---|---|---|---|
| 1 | **Overview** | `vault/01-overview.md` §Purpose + §Scope | `[¹] Source: vault/01-overview.md:L12-30 (sha256: abc...)` |
| 2 | **Goals & Non-Goals** | `vault/01-overview.md` §Goals + §Non-Goals | inline footnote |
| 3 | **Stakeholders / Owners** | `vault/_meta/squads.yaml` (when present) + `vault.json` author field | inline footnote |
| 4 | **User Stories** | Per unit: `units/U-NNN.md` frontmatter (`as_a` / `i_want` / `so_that` derived from description) | `[²] Source: units/U-007.md` |
| 5 | **Functional Requirements** | `vault/02-functional.md` FR-NNN entries | direct FR-id citation `[FR-007 → vault/02-functional.md:L78-92]` |
| 6 | **Non-Functional Requirements** | `vault/02-functional.md` §NFR + `vault/_meta/constitution.md` performance/security clauses | inline footnote |
| 7 | **Design / Architecture** | `binding.md` §Confirmed Claims + `codebase-map.md` §Entities + §Modules | sha256-stamped citation |
| 8 | **API & Data Contracts** | `codebase-map.md` §Public interfaces + `binding.md` Interface ref entries | per-endpoint citation `[API auth.login → codebase-map.md §Public interfaces:L142]` |
| 9 | **Test Plan & UAT** | Per unit: `bolts/U-NNN/bolt-report.md` acceptance_test result + self-assessment; **pre-dev mode**: from unit `acceptance_test` field only | bolt commit sha citation |
| 10 | **Risks & Open Issues** | `vault/03-open-questions.md` unresolved OQs (status≠resolved) + bolt-report `acceptance_test_concerns[]` (Iter 53) | per-OQ ID citation |

## 7. Mode auto-detection

Skill reads CWD state to determine FSD mode:

| CWD state | Mode | Section behavior |
|---|---|---|
| Vault only (no units, no bolts) | **Pre-development FSD** | Sections 1-8 + 10 fully populated; section 9 = "TBD — pending bolt execution"; section 7 partial (no binding.md → design comes from vault only) |
| Vault + units (no bolts) | **Pre-development FSD (with breakdown)** | Sections 1-8 + 10 fully populated; section 4 (User Stories) populated from units; section 9 = "Specified — pending execution" with per-unit acceptance_test descriptions |
| Vault + units + bolts | **Post-development FSD** | All 10 sections fully populated; section 9 includes actual test results + as-built per-FR status table |

**Watermark in PDF header:** "Pre-development draft" OR "Post-development as-built" + `vault.json.vault_version` + generation timestamp ISO8601.

**Override:** `--mode=pre-dev` / `--mode=post-dev` forces specific mode regardless of CWD state (useful for re-emitting prescriptive doc after bolts done).

## 8. Anti-hallucination mechanism (the "akurat" guarantee)

**Rule:** Every FSD sentence MUST trace to source artifact via `.citation-map.json`. No inferred / fabricated content.

**Generation algorithm (per section):**

1. Read source artifact (e.g., `vault/02-functional.md` FR-007)
2. Extract verbatim claim text + line range
3. Compute sha256 of source artifact at generation time
4. Emit FSD section text with inline footnote citation
5. Append entry to `.citation-map.json`:
   ```json
   {
     "fsd_section": "5.FR-007",
     "source_path": "vault/02-functional.md",
     "source_lines": "L78-92",
     "source_sha256": "abc...",
     "emitted_text_sha256": "def..."
   }
   ```

**Missing source handling:**
- If source artifact absent → emit `"[Pending — <source path> not yet generated]"` placeholder. Do NOT fabricate.
- Section excluded from output if source artifact absent AND mode-incompatible (e.g., section 9 in pre-dev mode just says "TBD" rather than placeholder-per-FR).

**Drift detection:**
- Re-running `emit-fsd` reads existing `.citation-map.json`, compares current artifact sha256 vs stored sha256.
- Sections with sha256 change get `⚠ Updated since last emit (was: <old-sha-prefix>, now: <new-sha-prefix>)` callout in PDF margin.
- New halt type NOT needed — reuses `quality_gate_failed` envelope if user runs with `--strict-citation` flag (out of scope for Iter 54).

## 9. Predictive preflight checks (added to predictive-checks.md)

```markdown
## emit-fsd preflight checks (v3.5.0+, Iter 54)

- check_id: `vault_present_for_fsd`
  command: `test -f <vault-path>/vault.json`
  expected: file exists
  on_fail: "emit-fsd requires a vault. Run generate-intent first."
  fatal: yes
  predicts_halt: (chain order error)

- check_id: `pandoc_installed`
  command: `command -v pandoc`
  expected: exit 0
  on_fail: "pandoc not installed; emit-fsd will produce FSD.md only (no PDF). Install: brew install pandoc"
  fatal: no
  predicts_halt: (no halt; degraded output — markdown-only)

- check_id: `pandoc_latex_engine_present`
  command: `command -v xelatex || command -v tectonic`
  expected: exit 0
  on_fail: "no LaTeX engine found; pandoc PDF render needs xelatex (brew install --cask basictex) OR tectonic (brew install tectonic — recommended, lighter). Falls back to HTML output for manual print-to-PDF."
  fatal: no
  predicts_halt: (no halt; degraded — HTML fallback)
```

## 10. Styling & customization

**Default styling (ID corporate-friendly defaults):**
- A4 page, 2.5cm margins
- Cover page: project name (from `vault.json.project_name`), version (`vault.json.vault_version`), date, "Generated by mega-sdd v3.x.x" footer
- Table of Contents after cover
- Body: Helvetica/Arial 11pt, 1.15 line spacing
- Tables for FR matrix, API spec, UAT scenarios (with header row shading)
- Footer: page number + project name + classification stamp ("Confidential" by default)
- No company logo by default

**Override via `<vault>/fsd/FSD.styling.yaml`:**

```yaml
# Generated on first run; user-editable. Subsequent runs preserve user edits.
company_name: "PT XYZ"                    # appears on cover page
logo_path: ./assets/company-logo.png      # 200px wide, top-left of cover; absent = no logo
classification: "Internal"                 # OR "Confidential" | "Public"
font_family: "Arial"                       # OR "Times" | "Helvetica" | "Calibri"
accent_color: "#003366"                    # heading + table header color
include_sections: all                      # OR list, e.g., [1,2,5,7,8,10]
include_citation_footnotes: true           # set false for cleaner output (drops [¹] markers)
include_drift_callouts: true               # set false for clean re-emit
```

Defaults work out-of-box. Styling YAML created on first run with all keys + defaults commented.

## 11. Integration with existing skills

**orchestrate-flow Step 6 diagnostics table (extend):**

```markdown
| After all phases complete | `emit-fsd` (per `commands/emit-fsd.md`, respecting `--no-fsd` flag) | `<vault>/fsd/FSD.pdf` written + chain summary: "FSD emitted: 10 sections, N citations, mode: <pre-dev|post-dev>" |
```

**Handoff emission (when invoked under `--auto`):**

```yaml
handoff:
  emitted_by: emit-fsd
  emitted_at: <ISO8601>
  status: completed | halted
  artifacts:
    - <vault>/fsd/FSD.md
    - <vault>/fsd/FSD.pdf            # absent if pandoc/LaTeX unavailable
    - <vault>/fsd/.citation-map.json
  next_action:
    suggested_skill: null            # FSD is terminal — chain complete
    rationale: "FSD emitted; ready for Confluence upload."
  blockers: []
  metrics:
    sections_emitted: <int>
    citations_count: <int>
    drift_callouts_count: <int>      # ≥0; flags sections changed since last emit
    mode: pre-dev | post-dev
    pdf_emitted: true | false        # false = pandoc absent
```

## 12. Implementation scope (atomic Iter 54)

**Deliverables:**

1. **New skill** `plugins/mega-sdd/skills/emit-fsd/SKILL.md` (~200 lines) — full procedure
2. **Reference files** (4 files):
   - `references/fsd-template.md` — canonical 10-section template
   - `references/pandoc-template.tex` — LaTeX styling template
   - `references/section-mapping.md` — vault artifact → FSD section mapping rules
   - `references/styling-config.yaml` — default styling YAML
3. **New command** `plugins/mega-sdd/commands/emit-fsd.md` (~30 lines)
4. **Wire orchestrate-flow** — extend Step 6 diagnostics table (+1 row); add `--no-fsd` flag support
5. **Wire predictive-checks** — add §emit-fsd preflight checks section (3 checks)
6. **Update auto.md command** — document `--no-fsd` flag
7. **Version bumps**:
   - New skill `emit-fsd` 1.0.0
   - `orchestrate-flow` 3.4.0 → 3.5.0 (MINOR — new diagnostic surface)
   - Plugin `3.36.0 → 3.37.0` (MINOR — new skill)
8. **CHANGELOG.md** + plugin README + root README — Iter 54 entry + version refs

**Total files touched:** ~10 (4 new + ~6 modified).

**Reuse-first principle applied:**
- emit-agents-md skill pattern (same anatomy: SKILL.md + references/)
- Iter 33 predictive-checks pattern (3 new checks)
- Iter 13 auto-integrated diagnostics pattern (extension)
- citation discipline from binding.md (sha256 stamp + line range)
- Iter 53 `acceptance_test_concerns` consumer (section 10 reads it for Risks)

## 13. Out of scope (deferred to future iters)

- **Iter 55+:** Cross-scope FSD consolidation (`/mega-sdd:emit-fsd --consolidate=BE,MW,FE`)
- **Iter 56+:** Confluence REST API direct push (`--push=<confluence-url>` with auth handling)
- **Iter 57+:** FSD-to-FSD diff tool (`/mega-sdd:diff-fsd v1.pdf v2.pdf`)
- **Iter 58+:** Indonesian translation pass
- **Iter 59+:** Strict-citation mode (`--strict-citation` halts on any drift since prior emit)

## 14. Success criteria

- [ ] `/mega-sdd:emit-fsd ./vault/` produces `FSD.md` + `FSD.pdf` in `<vault>/fsd/`
- [ ] PDF renders correctly with cover page, TOC, 10 sections, footer
- [ ] Every section text traces to source artifact via `.citation-map.json` (100% citation coverage)
- [ ] Mode auto-detection works (vault-only → pre-dev; vault+bolts → post-dev)
- [ ] Re-running on unchanged artifacts produces identical PDF (idempotent)
- [ ] Re-running on changed artifact shows `⚠ Updated since last emit` callouts
- [ ] `/mega-sdd:auto ./prd.md` auto-invokes emit-fsd at end of chain (when bolts complete)
- [ ] `--no-fsd` flag on `/mega-sdd:auto` skips emit-fsd cleanly
- [ ] Predictive preflight warns user when pandoc absent (degraded markdown-only output)
- [ ] Styling YAML override works (custom logo + color + font respected in PDF)

---

**Approval:** user approved 2026-05-25 via brainstorming session.
**Next:** writing-plans skill to produce atomic implementation plan.
