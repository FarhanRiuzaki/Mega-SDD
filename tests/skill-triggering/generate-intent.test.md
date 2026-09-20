# generate-intent Triggering Test

Manual-run fixture for Mode A (structured) and Mode B (free-text).

## Mode A — Structured input

### Case A1: Explicit slash with PRD path
- **Prompt:** `/mega-sdd:generate-intent ./prd.md`
- **Expect:** Skill invocation, Mode A, no Q&A unless PRD is incomplete

### Case A2: Indonesian trigger phrase + PRD in CWD
- **Setup:** `prd.md` exists in CWD
- **Prompt:** `pecah PRD ini buat dev`
- **Expect:** Skill invocation, Mode A on the detected PRD

## Mode B — Free-text input

### Case B1: Explicit --from-prompt flag
- **Prompt:** `/mega-sdd:generate-intent --from-prompt "build a clinic appointment system"`
- **Expect:** Skill invocation, Mode B, ≤10 adaptive Q&A questions

### Case B2: Natural language brief, no PRD in CWD
- **Setup:** empty CWD (no .md files)
- **Prompt:** `I only have an idea, not a PRD. Let me describe it...`
- **Expect:** Skill invocation, Mode B, opens Q&A flow

## Pass criteria

All 4 cases invoke `generate-intent` skill with correct mode selected.

## Mode auto-detect (v1.2+)

Manual-run fixture for the 6 detection rules. Each case maps to one rule.

### AD1: Rule 1 — Explicit flag wins
- **Prompt:** `/mega-sdd:generate-intent --from-prompt "build a TODO CLI"`
- **Expect:** Mode B activates; no path-detection attempted on the flag value

### AD2: Rule 2 — Existing file path → Mode A
- **Setup:** Create `./prd.md` in CWD
- **Prompt:** `/mega-sdd:generate-intent ./prd.md`
- **Expect:** Mode A activates; parses the existing file

### AD3: Rule 3 — Path-like with missing file → Mode A with warning
- **Setup:** No file at `./missing-prd.md`
- **Prompt:** `/mega-sdd:generate-intent ./missing-prd.md`
- **Expect:** Skill warns `"File ./missing-prd.md not found. Treating as Mode A path. To use free-text, wrap in quotes or use --from-prompt."` and offers to abort. If user proceeds, Mode A attempted on the missing path (which will fail downstream — but the detection is correct).

### AD4: Rule 4 — Quoted brief → Mode B
- **Prompt:** `/mega-sdd:generate-intent "build a TODO CLI in python"`
- **Expect:** Mode B activates; treats the quoted string as a brief; opens Q&A flow

### AD5: Rule 4 — Whitespace brief → Mode B
- **Prompt:** `/mega-sdd:generate-intent build a TODO CLI in python`
- **Expect:** Mode B activates (positional has whitespace, no path-like chars); treats as brief

### AD6: Rule 5 — Bare single word → Mode B
- **Prompt:** `/mega-sdd:generate-intent dashboard`
- **Expect:** Mode B activates (no path separator, no extension); treats `dashboard` as brief. Skill may prompt for more detail since the brief is sparse.

### AD7: Rule 6 — Empty arg, single PRD in CWD → Mode A
- **Setup:** Exactly one `.md` file (e.g., `prd.md`) in CWD
- **Prompt:** `/mega-sdd:generate-intent`
- **Expect:** Skill auto-detects the candidate, confirms with user, then Mode A on confirmation

### AD8: Rule 6 — Empty arg, multiple candidates → prompt
- **Setup:** CWD has `prd.md`, `seed-PRD.md`, and `notes.md`
- **Prompt:** `/mega-sdd:generate-intent`
- **Expect:** Skill prompts user to pick which to use as Mode A input, or offers Mode B brief input

### AD9: Edge case — Quoted single word
- **Prompt:** `/mega-sdd:generate-intent "buildTodoCLI"`
- **Expect:** Mode B (Rule 4 matches: wrapped in quotes); does NOT treat as path

### AD10: Edge case — Flag + positional
- **Prompt:** `/mega-sdd:generate-intent --from-prompt "build X" ./prd.md`
- **Expect:** Mode B (Rule 1 wins); skill warns `"--from-prompt set; ignoring positional ./prd.md. Provide just the brief or just a path, not both."`

### GI-KB-CFG — Shared KB via `knowledge_base:` in config.yaml (7.30.0)

**Setup:**
- Monorepo: session cwd is `apps/api/` (own `.mega-sdd/`, NO local `knowledge-base/`)
- `apps/api/.mega-sdd/config.yaml` has `knowledge_base: ../../knowledge/mcf-domain-knowledge/.mega-sdd/knowledge-base/`
- That directory exists (git submodule) and holds `README.md` + `census.json` + `modules/*.prd.md`

**Trigger:** `/mega-sdd:generate-intent` (no positional arg, no `--from-prompt`)

**Expected:**
- `derive-state` reports `knowledge_base: present (path: ../../knowledge/.../README.md, source: config)`
- Mode B KB sub-mode auto-detected with `--kb=../../knowledge/mcf-domain-knowledge/.mega-sdd/knowledge-base` implicit; user confirmation still asked
- PRD-kontrak grammar detected (census.json present) — consumption per kb-submode.md, unchanged

**Variant (configured but missing):** same config, submodule NOT initialised (directory empty).
- `knowledge_base: absent`, state.json `probes.knowledge_base.configured_missing: true`, `derived.notes` names the configured path
- generate-intent does NOT silently pick `apps/web`-style local copies; it halts with the note (init the submodule / fix the path)

**Variant (config + stale local copy):** cwd `apps/web/` with an old `.mega-sdd/knowledge-base/` AND the config key set.
- Configured KB wins (`source: config`); the local copy is never auto-selected

## Pass criteria (Mode auto-detect)

All 10 cases above invoke the correct mode per the rule table. No false positives where a path-looking string opens Q&A, or a brief gets treated as a file path. Ambiguous cases (AD3, AD8) prompt the user; do not silently proceed.

## OQ Auto-classifier (v1.4+, Iter 2)

### CL1: Tech-scan high-confidence
- **Setup:** PRD requires "API uses standard error response shape"; ambiguity → OQ candidate "what HTTP error envelope?"
- **Expect:** generate-intent's auto-classifier tags it `category: tech`, `resolution_mode: recommend`, `classification_confidence: medium` (recommend mode, not scan, because "error envelope shape" requires AI judgment)
- vault.json populates `recommendation`, `rationale`, `scan_citations` (cites closest existing pattern), `fallback_if_wrong`
- **The OQ is written DECIDED, never asked:** `[x]` + `→ **Resolved v{X.Y}** (AI decision, <date>): <pick>`; vault.json `status: resolved`, `resolved_by: ai`
- vault.md "## Auto-Classification Review" lists it AND "## AI Technical Decisions" carries its row

### CL2: Pure scan-mode tech OQ
- **Setup:** OQ candidate "what test framework should new tests use?"
- **Expect:** Tagged `category: tech`, `resolution_mode: scan`, `classification_confidence: high`
- `scan_query` populated as `codebase-map §test_frameworks`
- bind-codebase will auto-resolve later via Iter 2 logic

### CL3: Business OQ (default)
- **Setup:** OQ candidate "does cancellation refund prior payments?"
- **Expect:** Tagged `category: business`, `resolution_mode: blocking`, `classification_confidence: high`
- No recommendation / scan_query fields populated
- Listed in main OQ roll-up, NOT in Auto-Classification Review

### CL4: No-pattern-match → conservative default
- **Setup:** OQ candidate with text that matches NO heuristic pattern
- **Expect:** Tagged `category: business`, `resolution_mode: blocking`, `classification_confidence: low`
- Listed in Auto-Classification Review (low confidence flagged for review)
- User can flip to tech if appropriate

### CL5: No codebase context (greenfield) — still decided, honestly cited
- **Setup:** PRD has a tech CHOICE (e.g. "which test runner?") and there is no related pattern at all in the codebase-map or KB
- **Expect:** decided per the pick order — the citation names the REAL basis (`pack:<framework> §…` / `docs:<lib>@<ver>` / `PRD §X`), never a fabricated codebase anchor; NOT handed to a human just because there is no code

### CL5b: The answer is a FACT no source contains
- **Setup:** tech-sounding OQ whose answer only a person knows ("what hour does the legacy settlement job cut off?")
- **Expect:** `category: business`, `resolution_mode: blocking`, note "fact absent from every source; only a human knows" — never decided, never guessed

### CL5c: Business wins ties / source-vs-code contradiction
- **Setup:** (a) OQ matches a tech row AND a business row ("which library enforces the max value for transfer amount?"); (b) "the PRD names Bun + Postgres but the repo is Next.js + MySQL — which is authoritative?"
- **Expect:** both `category: business` / `blocking` — never an AI decision; if one slipped through decided, `validate-vault-oqs.sh` FAILs `oq_decided_business_signal`

### CL5e: the Design-Source OQ is the stakeholder's, never the AI's
- **Setup:** greenfield UI PRD, `HAS_UI_COMPONENTS: true`, no tokens / a11y / voice-brand source, no scanned template
- **Expect:** `OQ-DESIGN-SOURCE-1 [P1] [business]` (`resolution_mode: blocking`), left `[ ]`; the product-style-map pick rides in `recommendation` / `rationale` / `scan_citations` / `fallback_if_wrong` ONLY as slot `[1]` of the stakeholder ask; `design_system` is written only after the human accepts
- **FAIL if:** it is tagged `[tech / recommend]` and written `(AI decision …)` — the AI would be picking style / palette / typography / WCAG level (`validate-vault-oqs.sh` → `oq_decided_business_signal`)

### CL5f: greenfield never uses `scan`; a deferred tech OQ is undecided; the marker stays English
- **Expect:** on `implementation_mode: new` a tech OQ is `recommend` + decided (nothing to scan, no bind phase); a tech OQ written `**Deferred …**` fails the gate exactly like an open one; in an Indonesian vault the annotation still reads `(AI decision, <date>)` — never `(Keputusan AI, …)`

### CL5d: Authoring-time gate
- **Setup:** generate-intent leaves a `[tech / recommend]` OQ `[ ]` (or writes `[tech / blocking]`)
- **Expect:** `validate-vault-oqs.sh --strict-tech` exits 1 with `oq_tech_undecided`; the skill decides it (or re-tags a missing fact) and re-runs — the same vault under `analyze` (no flag) is WARN only

### CL6: Halt on recommend-mode missing fields
- **Setup:** Manually-crafted vault.json with OQ `resolution_mode: recommend` but missing `fallback_if_wrong`
- **Run:** `/mega-sdd:generate-intent` (re-generation or validation step)
- **Expect:** HALT with `oq_recommend_underspecified` blocker YAML listing `missing_fields: [fallback_if_wrong]`

### CL7: Auto-Classification Review section exists
- **Setup:** Any PRD producing ≥1 tech-tagged OQ at medium/low confidence
- **Expect:** 00-index.md has `## Auto-Classification Review (v1.4+)` section listing every tech-tagged OQ with confidence column; the confidence column is a glance list for the CATEGORY call — it never turns a tech OQ into an ask

## Pass criteria (Auto-classifier)

All 7 cases above (CL1-CL7) classify correctly per `references/vault-core.md` §Auto-classifier heuristics. No fabricated recommendation citations. Halt fires cleanly on validation failure. Conservative default (business/blocking/low) when no pattern matches.

## Iter 35 — Phase discoverability (v1.14+, v3.26+)

### GI-PH1 — Default phase=1 (Mode B with --kb, no explicit --phase)

**Setup:**
- `.mega-sdd/knowledge-base/` exists with valid extraction
- `<KB>/99-rebuild-architecture/suggested-phasing.md` has 3 `## Phase` headers (Phase 1, 2, 3)
- No `--phase` flag in invocation

**Trigger:** `/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/`

**Expected:**
- Step 2.5 parses suggested-phasing.md → phase_total = 3
- Default --phase=1 applies
- vault.json gets `phase: 1, phase_total: 3`
- 00-index.md `## Phase context` block emitted:
  - "Phase 1 of 3"
  - This vault covers: <1-line Phase 1 summary from suggested-phasing.md>
  - Upcoming phases: Phase 2 + Phase 3 (1-liners each)
  - Next-phase command: `/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/ --phase=2`
  - Full phased plan ref to suggested-phasing.md
- Vault content scoped to Phase 1's deliverables (not all phases mixed)

### GI-PH2 — Explicit --phase=2

**Setup:** Same KB as GI-PH1 (3 phases)

**Trigger:** `/mega-sdd:generate-intent --kb=.mega-sdd/knowledge-base/ --phase=2`

**Expected:**
- Step 2.5 reads `## Phase 2` section from suggested-phasing.md
- vault.json gets `phase: 2, phase_total: 3`
- 00-index.md `## Phase context` block:
  - "Phase 2 of 3"
  - Vault scope reflects Phase 2 deliverables
  - Upcoming: Phase 3 only (Phase 1 already done; not listed as upcoming)
  - Next-phase command: `--phase=3`
- Vault content filtered to Phase 2 scope; not mixed with Phase 1 or 3
