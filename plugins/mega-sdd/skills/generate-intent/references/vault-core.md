# Vault Core — the drafting contract (§schema + §OQ-conventions + §id-stability)

Shared definitions referenced by all `mega-sdd` skills — the DRAFTING CORE split out of `vault-contract.md` (v7 Fase 4 R2: this is the half every OQ/schema consumer needs; the conditional overlays — §Starterkit-binding (`--scan` only), §Multi-scope — stay in `vault-contract.md`). **Single source of truth** — when this file changes, every skill that references it inherits the change.

> **Maintenance rule**: edits to this file are breaking changes for sibling skills. Bump the affected skill versions + CHANGELOG entry whenever you touch this file.

## Contents

- §schema — `vault.json` manifest (incl. phase fields, design_system, stages-propagation, concurrency contract)
- §OQ-conventions — Open Question tagging (category / resolution mode / classification confidence / auto-classifier)
- Auto-Classification Review
- §constitution — Project-Facing Rules (§A–§F clause template + lifecycle)
- §boilerplate — Skill instruction language
- §id-stability — ID conventions

## §schema — `vault.json` manifest

Every `mega-sdd` vault has a `vault.json` alongside the 7 markdown files. The markdown is human-authoritative; the JSON is a derived structural index optimized for AI consumers (Claude Code, Cursor, automated agents).

**`vault.json` is SCRIPT-DERIVED by `scripts/derive-vault-json.sh` — a model/hand write is an authoring bug.** Three lanes:

- **Derive lane (md-authoritative):** `entities[]` (DBML `Table` blocks + the `// Purpose:` comment), `flows[]` (`### F-*-NNN:` headings + DoD + `**Source**:` AC harvest + `**_kb_source**:`), `adrs[]` (`### D-NNN:` + `Status:` line, absent → `accepted`), `open_questions[]` skeletons (the checkbox grammar + brackets incl. `[origin: <file>#<anchor>]`; the legacy 00-index roll-up header is a category fallback on 7-file vaults only), `open_questions_summary`, `vault_version` + the five Vault Lock enums. md is authoritative for existence — an OQ tag absent from the markdown is dropped (WARN), EXCEPT entries carrying `defer_to: binding` (no md home — preserved with a WARN, never dropped).
- **Carry-forward lane (at-generation pins + unknown-key tolerance):** `prd_sha256`, `prd_path_at_generation`, `constitution_hash`/`constitution_version` (pinned at generation — recomputing would silently re-baseline; the script computes them fresh ONLY when absent and WARNs when the carried hash differs from the current `constitution.md`), legacy `mode` (carried verbatim even when it contradicts the md-derived `implementation_mode` — never reconciled), `title`, `scope`/`scope_metadata`, `source_documents`, `phase`/`phase_total`, `design_system_flags`, `design_system`, `advisor`, `changelog`, per-OQ JSON-only fields — and ANY prior key the deriver does not own, verbatim.
- **Patch lane (`--patch <file.json>`):** the fields the model still authors — the carry-forward roster above when NEW values are being supplied (initial generation metadata, diff-vault `source_documents` replacement) + the per-OQ classifier records (`scan_query`, `recommendation`, `rationale`, `scan_citations`, `fallback_if_wrong`) + `defer_to`. Setting a derived key in a patch exits 2 (anti-laundering — the markdown stays the single grammar). `--event '<json>'` appends one changelog event under the same lock. **Md-hint fallback (field-test hardening):** when a patch never supplied those five per-OQ fields but they exist as hint lines inside the OQ's markdown block (`` `scan_query: "…"` `` etc.), the deriver picks them up at the LOWEST precedence — a patched/carried value always wins; the patch remains the authoring lane.

`resolved_at`/`deferred_at` are **script-stamped on status transition** (never model-written). `generated_at` is **preserved when a re-derive produces otherwise-identical content** (idempotent no-op derives keep the sha256(vault.json) doc-control stamp stable) — this supersedes the diff-procedure's older "only `generated_at` updates" wording: on a true no-op, NOTHING updates.

```json
{
  "vault_version": "1.1",
  "generated_at": "YYYY-MM-DDTHH:MM:SSZ",
  "phase": 1,
  "phase_total": 1,
  "project_shape": "web-app",
  "implementation_mode": "new",
  "prd_status": "draft",
  "output_mode": "compact",
  "mode_migrate_after": "first commit lands on main branch (mode=new only)",
  "source_documents": [
    {"type": "PRD", "path": "examples/timeoff/PRD.pdf", "version": "1.0", "date": "YYYY-MM-DD"}
  ],
  "entities": [
    {"name": "leave_request", "purpose": "Lifecycle entity for a leave request", "doc": "model.md", "fields_count": 13}
  ],
  "flows": [
    {"id": "F-U-001", "title": "Submit leave request", "type": "user", "doc": "flows.md", "dod_count": 7, "source_acs": ["AC1-1","AC1-2","AC1-3","AC1-4","AC1-5"]}
  ],
  "adrs": [
    {"id": "D-001", "title": "Multi-tenant SaaS-only deployment", "doc": "vault.md", "status": "accepted"}
  ],
  "open_questions": [
    {"tag": "OQ-AR-1", "priority": "P1", "doc": "constraints.md", "origin": "vault.md#Architecture", "status": "open", "category": "tech", "resolver_owner": "Mike Patel"}
  ],
  "open_questions_summary": {
    "total": 48,
    "by_priority": {"P1": 12, "P2": 22, "P3": 14},
    "by_status": {"open": 48, "resolved": 0, "deferred": 0, "out_of_scope": 0}
  },
  "design_system_flags": {
    "HAS_UI_COMPONENTS": false,
    "HAS_TOKENS": false,
    "HAS_A11Y": false,
    "HAS_VOICE_BRAND": true
  },
  "design_system": {
    "style": "minimalism",
    "palette": "primary #2563EB, accent #EA580C",
    "typography": "Modern Professional (Poppins/Open Sans)",
    "a11y_level": "WCAG AA",
    "source": "design-intelligence-recommend",
    "provenance": "recommend:OQ-DESIGN-SOURCE-1 (plugins/mega-sdd/references/design-intelligence/product-style-map.yaml#saas-general + PRD §1)"
  }
}
```

### §design_system

Present when a design system has been resolved for the vault — from a scanned template, an accepted Design-Source recommendation, or an explicit PRD source. Absent otherwise — never a silent default. Fields:

- `style` / `palette` / `typography` / `a11y_level` — the resolved design system, each traceable to its source.
- `source` — one of `prd` | `scanned-template` | `design-intelligence-recommend`. **Precedence (highest→lowest): `prd` > `scanned-template` > `design-intelligence-recommend`.** When a template was scanned (`starterkit-context.yaml §ui_ux`), `source: scanned-template` and the values are DERIVED FROM the template — ui-ux-pro-max never overrides it, only gap-fills.
- `provenance` — the source citation: the resolving OQ tag + design-intelligence citation + PRD signal (for `design-intelligence-recommend`), or the `starterkit-context.yaml §ui_ux` anchor (for `scanned-template`). Required when the block is present (anti-halu: no design system without provenance).

`vault_version` is bumped to `1.1` because this block is additive to the manifest. Consumers on `1.0` simply do not see it (backward compatible).

### Phase fields

```yaml
phase: <int>          # which phase this vault represents (1, 2, 3, ...). Default 1 if not legacy-rebuild.
phase_total: <int>    # total phases planned (parsed from suggested-phasing.md `## Phase` heading count). Default 1 if not legacy-rebuild.
```

### Field rules

- `phase` + `phase_total`: REQUIRED. Defaults `phase: 1, phase_total: 1` for back-compat (greenfield + Mode A PRD-driven + single-phase Mode B). Mode B with `--kb` parses `<KB>/99-rebuild-architecture/suggested-phasing.md` for phase count. Missing field on an older vault.json → treat as `phase: 1, phase_total: 1`.
- Every entity in the data-model doc (`model.md`; legacy `03-data-model.md`) DBML must have a row in `entities[]`. Same for `flows[]` (one per `F-{prefix}-NNN`), `adrs[]` (one per `D-NNN`), `open_questions[]` (one per `OQ-{CODE}-{N}`). The deriver enforces this by construction (md-authoritative existence).
- **G1 — entities mirror rule:** each `Table` block carries a `// Purpose: <1 line>` DBML comment immediately above it (the compact-mode Purpose line, machine-read into `entities[].purpose`); the parser falls back to the full-mode `### <entity>` + `- **Purpose**:` block, else `null` — never fabricated.
- `open_questions[].status` mirrors the markdown checkbox: `[ ]` → `open`, `[x]` → `resolved`, `[~]` → `out_of_scope`. A `[ ]` with a `**Deferred**:` annotation maps to `deferred`.
- `open_questions[].category` is **bracket-first**: the `[tech / scan]` / `[business]` marker on the OQ line wins (`tech` / `business`); the legacy 00-index roll-up category header is the fallback on 7-file vaults only (startswith-tolerant); layout-2 has no roll-up — the bracket is mandatory there.
- `open_questions[].resolver_owner` is best-effort — extracted from the OQ entry's `— resolve: ...` hint when present; otherwise `null`.
- `mode_migrate_after` is informational metadata for `mode=new` vaults only. For `mode=existing`, use `null`.
- Re-run `scripts/derive-vault-json.sh` after every markdown round (regeneration / `diff-vault` / `resolve-oq`). The markdown is canonical; `vault.json` is a derived index — never hand-synced.

### Operator-workflow-UX capture + Design-Source OQ

Two CAPTURE-stage rails checked by `validate-vault-oqs.sh` (PostToolUse re-validates every vault doc write; surfaced as **advisory** via `analyze` — v4 Hybrid demoted this from a hard-block, so it no longer blocks `mega-sdd:execute-bolts`). Both are **vault-FORMAT conventions** — stack-neutral, evaluated pre-binding — so they need NO framework pack (a new target stack does not change these vault conventions). Both preserve the anti-hallucination rail: the fix is always an Open Question, **never a defaulted value**.

- **Workflow flow signal (closed grammar).** A user-facing flow (`F-U-` prefix, or prefix-less; the `F-S-` / `F-C-` / `F-X-` internal classes are excluded) is a **multi-stage approval / maker-checker / workflow** flow when EITHER its actor/title line shows a maker→checker hand-off chain (a `maker … checker|approver|confirmer|reviewer|…` chain joined by `->` / `→` arrows) OR its step body carries **≥ 2 distinct decision transition steps** (approve / reject / review / confirm). One decision step alone is a simple submit; two or more is multi-stage.

- **Operator-surface requirement (the four first-class surfaces).** When a workflow flow exists, the vault MUST model the operator-facing surface as requirements **grounded in the flows** (never invented): (1) **worklist / inbox**, (2) **decision affordance** (approve/reject actions in the current state), (3) **human-readable workflow-state labels**, (4) **audit timeline** of transitions. Presence is detected by the operator-surface vocabulary in the vault's prose docs (layout-2: `vault.md`, `model.md`, `flows.md`; legacy: 02/01/03/04). (The Design-Source OQ check below additionally scans `vault.json`.)
  - **Halt `operator_surface_missing`** — workflow flow present AND no operator-surface requirement AND no Design-Source OQ → FAIL.

- **Design-Source OQ (anti-hallucination escape hatch).** When `design_system_flags.HAS_UI_COMPONENTS = true` but `HAS_TOKENS`, `HAS_A11Y`, and `HAS_VOICE_BRAND` are **all `false`**, the vault MUST carry a high-priority Design-Source Open Question (recommended tag shape `OQ-DESIGN-SOURCE-{N} [P1]`, or any OQ whose tag/text names a design-source concern — tokens / a11y / voice-brand source). **DO NOT default WCAG/Material/token values** — capture the gap as an OQ only.
  - **Halt `design_source_oq_missing`** — UI components present AND all three design flags false AND no Design-Source OQ → FAIL. (This was the captured trade-finance Phase-2 miss.)

A Design-Source OQ also satisfies the `operator_surface_missing` rail (it is the accepted "captured the miss" signal): a vault that has not yet decided its operator surface may carry a Design-Source OQ instead of inventing the surface, and the gate passes.

### Staged-input preservation + `_kb_source` propagation (§stages-propagation)

A multi-step workflow (wizard, maker→checker, multi-page form) **stages** its inputs: which fields enter at which step, in what order, by which role, gated by which transition. When that structure is flattened to a single "Inputs: A,B,C,D,E,F" list, the downstream bolt builds ONE form instead of the multi-step wizard (the captured trade-finance regression). To prevent it, staging is carried as a **stable structured field** and propagated the SAME way as OQ-IDs (§id-stability) and constitution clauses — copied verbatim, never re-derived:

- **Source of truth.** `extract-intelligence` captures staging in the KB workflow file's `## 3a. Staged inputs` section as a `stages:` YAML block (see `extract-intelligence/references/knowledge-base-schema.md §3a`). Each stage cites its own `_source` anchor.
- **Preservation rule (generate-intent).** When a KB workflow domain has a `stages:` block, generate-intent MUST copy it **verbatim** into the matching `flows.md` flow entry (`**Stages**` block), emit the corresponding Mermaid `stateDiagram`, and stamp the flow with `_kb_source: [20-workflows/<file>.md]`. It MUST NOT re-flatten the staging into prose. (The flow body itself is the Mermaid `stateDiagram` / flowchart — never a prose Steps list, per the Mermaid-flows hard rule; the `stages:` block is authoritative for the staged fields.)
- **Enriched-stages preservation.** The KB `stages:` block MAY carry an enriched form: `input_fields` as objects (`{name, mutability, visibility, conditional}`) instead of bare strings, plus per-stage delta fields (`new_fields_vs_prior`, `hidden_fields_vs_prior`, `promoted_to_mutable_vs_prior`, `dynamic_disclosures`) — see `extract-intelligence/references/knowledge-base-schema.md §3a`. "Verbatim" **includes these**: generate-intent MUST preserve whichever form the KB used and MUST NOT downgrade enriched `input_fields` objects to bare strings (a silent drop of the maker→checker field-promotion / show-hide intent the extractor captured). generate-intent does not itself *act on* the delta semantics — those are consumed at UI/bolt time per the UI/UX-design-intelligence integration (`docs/superpowers/specs/2026-06-05-ui-ux-design-intelligence-integration-design.md`); carrying them through unmodified is precisely what makes that downstream consumption possible. Bare-string KBs are unaffected (nothing to preserve).
- **Back-reference (`_kb_source`).** This field is the deterministic link from a vault flow to its originating KB workflow — the analog of an OQ tag. `validate-vault-flow-staging.sh` follows it: if the cited KB workflow has a `stages:` block and the vault flow does not, it raises a `vault_flow_staging_drop` finding, surfaced as **advisory** via `analyze` (v4 Hybrid demoted this from a hard-block — it no longer blocks execute-bolts). No KB present, or no `_kb_source` on the flow (legacy vault) → the check **skips** (backward-compatible by construction; pre-staging vaults never trip it).
- **Advisory at the source.** the kb flows surface (`validate-kb.sh --surface=flows`) raises an advisory `kb_flow_staging_missing` (never status-flipping) when a workflow KB file looks multi-step but carries no `stages:` block, pointing the user to `enrich-semantics` to retro-fit staging without a full re-extract.

> **Walking-skeleton scope:** only the staged-input dimension is enforced. The `conditions:` field captures per-transition guards best-effort; richer conditional / role-matrix / transition-guard enforcement is Fork-B-future.

### When skills must regenerate `vault.json`

Every writer regenerates by **running the script** — never by editing the JSON:

- `generate-intent` Step 3.8 — initial derive, single run after constitution (3.4) / classifier (3.5) / advisor (3.7) complete: `derive-vault-json.sh --vault <dir> --patch <authored-patch>` (metadata + classifier/advisor writebacks).
- `resolve-oq` — after every Resolve / Out-of-Scope / Defer outcome's markdown edits: `derive-vault-json.sh --vault <dir> --event '<round-event-json>'` (+ `--patch <tmp-patch>` carrying `defer_to` for binding-defers).
- `diff-vault` Step 6.5 — after applying approved changes: `derive-vault-json.sh --vault <dir> --patch <sources-patch>` (the replaced `source_documents` entry + updated `prd_sha256`/`prd_path_at_generation` when the PRD changed).
- `bind-codebase` Step 6 — audit log append: `derive-vault-json.sh --vault <dir> --event '{"event":"bind",…}'`.
- `detect-drift` — dual-lane. The **diagnostic lane** never regenerates (reports only — DRIFT-REPORT.md / PENDING-SYNC.md). The **`--auto-apply=safe` explicit-ACCEPT write-back lane** regenerates like every writer: after applying the accepted vault patches it runs `derive-vault-json.sh --vault <vault-dir>` (script-held lock; per the §Concurrency detect-drift exception + detect-drift SKILL Step 6).

### Concurrency contract (closes audit D3-012)

The exclusive advisory file lock on `<vault>/vault.json.lock` is acquired **BY `scripts/derive-vault-json.sh` itself** — a single implementation, no per-skill lock dance. This prevents data corruption from concurrent-tab / concurrent-session writes that previously raced silently. Lock semantics REUSE the memory file-lock pattern (per `mega-sdd:memory`) — no new mechanism.

**Writers (4 total — each invokes the script; none touches the lock directly):**
- `generate-intent` Step 3.8 (initial derive, `--patch`)
- `bind-codebase` Step 6 (`--event` audit append) — and bind-codebase still writes `binding.md` in the same Step-6 window (binding.md has no separate lock; the script-held derive is the serialization point for the manifest, and two concurrent binds are upgrade-your-plugin territory per Backward compatibility below)
- `diff-vault` Step 6.5 (derive + `--patch` sources)
- `resolve-oq` (derive + `--event` after every Resolve / Out-of-Scope / Defer outcome)

**Lock behavior (implemented in the script):**

```
1. lock_path = <vault>/vault.json.lock, created with O_EXCL | O_CREAT
2. On collision: backoff (100ms / 500ms / 1500ms) + retry 3 attempts
3. All retries fail → exit 4 (stderr carries the orphaned-lock hint);
   the INVOKING SKILL maps exit 4 to the `memory_in_use` halt envelope below
4. On success: derive + atomic write (temp file + os.replace), release lock
   on ALL exit paths
```

**Halt envelope (reuses `memory_in_use` — no new halt type; emitted by the skill when the script exits 4, keterangan verbatim):**

```yaml
type: memory_in_use
source_skill: <bind-codebase | diff-vault | generate-intent | resolve-oq>
details:
  file: "<vault>/vault.json"
  lock_path: "<vault>/vault.json.lock"
  attempts: 3
  lock_holder_pid: <int OR "unknown — orphaned lock; rm lock_path manually if no concurrent run">
next_action:
  type: wait_or_orphan_check
  hint: "Another mega-sdd skill is writing vault.json concurrently. Wait 5s + retry. If no other run is active, check for orphaned lock file: `ls -la <lock_path>` — if its mtime > 30s old and no PID owner, rm + re-run."
```

**Reader behavior:** vault.json readers (any skill that reads it) DO NOT need the lock — POSIX rename is atomic, so readers always see a consistent view (pre-write OR post-write, never mid-write). Lock is exclusive for writers only.

**detect-drift exception:** detect-drift's diagnostic lane NEVER writes vault.json (reports only). Its explicit-ACCEPT write-back lane refreshes vault.json the same way as every writer — by running `derive-vault-json.sh` (script-held lock) — never by hand.

**Backward compatibility:** writers from plugin versions predating this contract MAY race; concurrent-write users should upgrade all skills atomically (single plugin version bump).

### OQ status tracking

OQ entries in vault.json support status-tracking fields. **Status vocabulary is ONE closed set: `open | resolved | out_of_scope | deferred`** (G3 — the legacy `pending` / `out-of-scope` spellings are retired from the contract; the deriver and `open_questions_summary.by_status` use only this set). The full OQ entry shape:

```yaml
oqs:
  - id: OQ-DATA-001
    priority: P1 | P2 | P3
    section: <vault-filename.md>
    text: <question text>
    status: open | resolved | deferred | out_of_scope       # default: open if absent
    # When status=resolved:
    resolved_at: <ISO8601 timestamp>    # SCRIPT-STAMPED by derive-vault-json.sh on the transition into resolved — never model-written
    resolution: <answer text>
    # When status=deferred:
    defer_to: binding | stakeholder                         # binding = brownfield code-aware; stakeholder = waiting on human (e.g., legal review, target date)
    deferred_at: <ISO8601 timestamp>    # SCRIPT-STAMPED on the transition into deferred
    deferred_reason: <reason / PIC / target date — e.g., "waiting on legal review by 2026-06-01">
    # When status=out_of_scope:
    out_of_scope_reason: <text>
```

**Backwards compatibility:** OQ entries without a `status` field are treated as `status: open` by all skills (legacy `pending` values in pre-W5 manifests read the same way). Existing v1.0.x vaults load unchanged; the next derive rewrites them into the unified vocabulary from the markdown checkboxes.

## §OQ-conventions — Open Question tagging

Every Open Question MUST have a unique tag and priority marker.

**Tag format**: `OQ-{DOC_CODE}-{N}` where:

| Doc | Code |
|-----|------|
| `vault.md ## Overview` (legacy `01-overview.md`) | `OV` |
| `vault.md ## Architecture` (legacy `02-architecture.md`) | `AR` |
| `model.md` (legacy `03-data-model.md`) | `DM` |
| `flows.md` (legacy `04-flows.md`) | `FL` |
| `vault.md ## Decisions` (legacy `05-decisions.md`) | `DC` |
| `constraints.md` (legacy `06-constraints.md`) | `CN` |

`N` is sequential within each doc (1, 2, 3 …). Tags are stable identifiers — once assigned, do not renumber when adding new questions.

**Priority levels**:

- **P1 — Sprint-0 blocker**: Must be answered before any coding starts. Examples: tech stack, API contracts, source-data inconsistencies, missing sign-off, regulatory/compliance scope.
- **P2 — Feature blocker**: Blocks a specific feature/flow but not the whole project. Examples: edge-case behavior, channel mapping for notifications, max value limits.
- **P3 — Refinement**: Useful to clarify but project can move without it. Examples: future-proofing, optimization details, optional analytics.

**Status markers** (in markdown):

- `[ ]` — open
- `[x]` — resolved (followed by `→ Resolved v{X.Y}: <answer or pointer>`)
- `[~]` — out of scope (followed by `→ Out of Scope v{X.Y}: <reason>`)
- `[ ]` + `**Deferred (v{X.Y})**: <reason>` — deferred (still open, but waiting on something specific)

### Category

Every OQ carries `category`:

- `business` — needs stakeholder judgment. Examples: feature scope, edge-case behavior, regulatory threshold, UI copy, pricing logic.
- `tech` — answerable from codebase or convention. Examples: test framework, error code format, naming convention, library version, file location.

**Default**: `business`.

### Resolution mode (required when category=tech)

Tech OQs carry a `resolution_mode` describing how the OQ is answered without blocking human review:

- `scan` — answer deterministically found by probing ground truth. Requires `scan_query`, which names the PROBE TARGET: on the express spine (default) that is a manifest / symbol-index / file probe (`manifest phpunit.xml`, `symbol-index LeaveRequest`, `file config/auth.php`); on the classic spine a codebase-map section (`codebase-map §test_frameworks`) or KB. `bind-codebase` auto-resolves on single unambiguous match — express re-targets a `codebase-map §` hint to its underlying ground truth (the manifest/config file itself) rather than a map it did not read.
- `recommend` — AI picks with rationale. Requires `recommendation` + `rationale` + `scan_citations` (≥1 citation). `bind-codebase` surfaces in `binding.md` review section; user ACCEPTS / OVERRIDES / REJECTS.
- `hard_rule` — encoded as bolt-time constraint. Requires `hard_rule` string. `execute-bolts` validates via pre-flight scan.
- `blocking` — explicit "no auto-resolve; still needs human". Rare for tech (used when scan is inconclusive AND no safe default).

A tech OQ MUST specify `resolution_mode`; absence is a generate-intent validation error (halt with `oq_tech_missing_mode` blocker).

### Classification confidence

Auto-classification (per the auto-classifier heuristics below) carries a confidence label:

- `high` — heuristic matched strongly (single clear pattern hit)
- `medium` — partial match (some signal, but not unambiguous)
- `low` — fallback default; classifier defaulted to `business/blocking` because no strong signal

**Auto-resolve gate**: only `high`-confidence tech OQs auto-resolve in `bind-codebase`. `medium`/`low` confidence OQs go to the vault.md "## Auto-Classification Review" section (legacy: 00-index.md). User reviews tags one-pass before binding runs; any OQ user flips from tech-to-business stays human-decided.

### Auto-classifier heuristics

`generate-intent` tags new OQs with `category` + `resolution_mode` + `classification_confidence` at generation time. Heuristic table:

| OQ text pattern | Likely category | Resolution mode | Confidence |
|---|---|---|---|
| "what test framework" / "which testing library" / "test runner" | tech | scan | high |
| "naming convention for X" / "case style for Y" / "file naming" | tech | scan | high |
| "file location for Z" / "where should X live" / "directory structure" | tech | scan | high |
| "what error code format" / "what response shape" / "API envelope" | tech | recommend | medium |
| "which library for X" / "which version of Y" / "dependency choice" | tech | recommend | medium |
| "should we support X feature" / "does Y count as in-scope" | business | blocking | high |
| "what is the limit for X" / "how many Y" / "max value for Z" | business | blocking | high |
| "is X regulated" / "POJK reference for Y" / "compliance for Z" | business | blocking | high |
| "edge case: when Z happens" / "behavior on edge case" | business | blocking | high |
| any mention of "stakeholder", "PO", "compliance team", "legal", "finance" | business | blocking | high |
| any mention of "scan codebase", "check existing", "convention", "framework standard" | tech | scan | high |
| anything else (no strong signal) | business | blocking | low (default) |

**Conservative default**: when no heuristic matches → `business / blocking / low`. Safe — preserves current blocking behavior.

### Auto-Classification Review section in `vault.md`

After OQ classification, `vault.md` MUST include the section (layout-2 — there is no roll-up; on a legacy 7-file vault it sits in 00-index.md before the roll-up):

```markdown
## Auto-Classification Review

> Total classified: {N} OQs. Auto-resolution active: {M} (tech, high-confidence).
> Manual review recommended: {K} (tech medium/low-confidence + any flipped from business to tech).

| OQ-ID | Question | Auto-tagged | Confidence | Action |
|---|---|---|---|---|
| OQ-AR-1 | which test framework? | tech / scan | high | will auto-resolve via scan |
| OQ-AR-7 | what HTTP error envelope? | tech / recommend | medium | needs review — confirm recommend mode |
| OQ-FL-3 | does cancellation refund? | business / blocking | high | blocking — needs stakeholder |
```

User can override tags inline (e.g., flip OQ-AR-7 to `business / blocking` if "what error envelope" actually needs a product call, not a tech recommendation). Override mechanism: user edits `vault.md` (legacy: 00-index.md) OR `vault.json`; `bind-codebase` re-reads at run time.

### Updated OQ schema in markdown body

```markdown
- [ ] **OQ-AR-1** [P1] [tech / scan] [conf: high]: which test framework? — resolve: scan codebase-map §test_frameworks
- [ ] **OQ-AR-7** [P2] [tech / recommend] [conf: medium]: what HTTP error envelope shape? — resolve: see Auto-Classification Review
- [ ] **OQ-FL-3** [P1] [business] [conf: high]: does the cancellation flow refund prior payments? — resolve: PM/finance team
```

### Updated `vault.json` OQ schema

```json
{
  "tag": "OQ-AR-1",
  "priority": "P1",
  "category": "tech",
  "resolution_mode": "scan",
  "classification_confidence": "high",
  "scan_query": "codebase-map §test_frameworks",
  "doc": "constraints.md",
  "status": "open"
}
```

For `resolution_mode: recommend`:
```json
{
  "tag": "OQ-AR-7",
  "priority": "P2",
  "category": "tech",
  "resolution_mode": "recommend",
  "classification_confidence": "medium",
  "recommendation": "Use RFC 7807 problem+json envelope",
  "rationale": "Industry standard; integrates with most HTTP clients. Existing pattern at app/Http/Resources/ErrorResource.php uses ad-hoc shape — recommendation moves toward consistency.",
  "scan_citations": ["app/Http/Resources/ErrorResource.php:12"],
  "fallback_if_wrong": "If RFC 7807 doesn't fit client expectations, revisit and consider JSON:API error format",
  "doc": "constraints.md",
  "status": "open"
}
```

### Validation rules (enforced by generate-intent at write time)

- Every OQ with `category: tech` MUST have `resolution_mode` set; absence → halt `oq_tech_missing_mode`.
- Every OQ with `resolution_mode: scan` MUST have `scan_query` populated.
- Every OQ with `resolution_mode: recommend` MUST have `recommendation` + `rationale` + at least one `scan_citations` entry + `fallback_if_wrong`. Missing any → halt `oq_recommend_underspecified`.
- Every OQ with `resolution_mode: hard_rule` MUST have `hard_rule` populated (grammar enforced at execute-bolts pre-flight).
- `classification_confidence` MUST be one of `high | medium | low`.

**Backwards compatibility**: OQs without a `category` field → treated as `business` by all skills. OQs with `category: business` and no `resolution_mode` → defaults to `blocking`. Existing v1.0–v1.5 vaults load unchanged.


## §constitution — Project-Facing Rules

Per Spec Kit `/speckit.constitution` + AWS Kiro "steering files" pattern (independent convergence in spec-driven-dev tools 2025-2026). Mega-sdd adopts as **8th vault file**: `constitution.md`.

Constitution is **project-facing rules** distinct from `AGENTS.md` (agent-facing flattened export). It captures non-negotiable project invariants that EVERY bolt must respect:

- Coding standards (naming case, file organization, comment style)
- Security baselines (auth requirements, input validation, secret handling)
- Architecture invariants (layered architecture rules, allowed dependencies)
- Anti-patterns to NEVER replicate (drawn from legacy gotchas or team learnings)
- Performance constraints (response time targets, query patterns to avoid)
- Compliance rules (regulatory requirements, audit trail mandates)

### Schema

`<vault>/constitution.md`:

```markdown
# Project Constitution

**Status**: Active
**Version**: 1.0
**Last reviewed**: 2026-05-21
**Sign-off**: Tech Lead / Product / Security (when relevant)

---

## §A. Coding standards (Non-negotiable)

- A-001: <auth rule — e.g. all endpoints require the project's auth middleware> (source: PRD §<security> / binding §scan_results)
- A-002: <naming convention — case styles for the stack's identifiers/routes/files> (source: <team decision> / codebase-map §conventions)
- A-003: <test-file organization rule> (source: codebase-map §test_conventions)

## §B. Security baselines

- B-001: <input-validation rule — where/how untrusted input is validated> (source: PRD §<security>)
- B-002: <data-access rule — ORM/query-layer boundary> (source: binding §scan_results)
- B-003: <secret-handling rule — no secrets in code; config/env abstraction> (source: PRD §<security>)
- B-004: <PII-at-rest rule> (source: constraints.md §regulatory — mandated by <regulation>)

## §C. Architecture invariants

- C-001: <layering rule — e.g. controllers must not call controllers> (source: D-<NNN> / KB §architecture)
- C-002: <side-effect / event-emission rule> (source: KB §critical-findings)

## §D. Anti-patterns (from legacy / past projects)

- D-001: NEVER replicate <specific named legacy gotcha> (source: knowledge-base §critical-findings)
- D-002: <dependency-review rule — no new deps without review> (source: <team decision>)

## §E. Performance constraints
<!-- NFR numbers are NOT defaults — every target MUST trace to a source (PRD SLA, KB perf finding).
     If no source states a number, the target is an Open Question, never an invented value. -->

- E-001: <latency target — value FROM a source, e.g. "median < NNNms per PRD SLA"> (source: PRD §<nfr>)
- E-002: <query-budget / N+1 rule — value from a source> (source: PRD §<nfr> / KB §performance)

## §F. Compliance

- F-001: <audit-logging rule — what is logged, where> (source: constraints.md §regulatory)
- F-002: <PII-access-logging rule> (source: PRD §<compliance>)
- F-003: <data-retention rule — period FROM a source> (source: constraints.md §regulatory — mandated by <regulation>)
```

> **Every clause carries an inline `(source: …)`.** This is not decoration — `validate-constitution.sh`
> deterministically FAILs any clause whose block has no source token (`§` / `(source:…)` / a KB/PRD anchor /
> a `file:line` citation / a link). A clause with no source is a defaulted or invented rule; because clauses
> become BLOCKING Hard rules at `execute-bolts`, an uncited clause would enforce fabrication as ground truth.
> If a rule (especially an NFR number) is not stated by a source, it is an Open Question — never an invented value.

### How constitution drives bolts

1. **At `generate-intent`**: write constitution.md from PRD + KB constraints sections + user Q&A; user reviews + signs off; updates trigger version bump
2. **At `bind-codebase`**: cite constitution clauses when surfacing CONFLICTs; flag binding entries that violate constitution as halts
3. **At `generate-units`**: for each unit, inject relevant constitution clauses into the unit's `## Hard rules` section as `id: constitution-<clause-id>` rules
4. **At `execute-bolts`**: pre/post-flight Hard Rule scan automatically validates constitution clauses (no separate command)
5. **At `detect-drift`**: flag code that violates constitution as drift findings

### Constitution version pinning

Constitution version pinned to vault:

```yaml
# In vault.json:
"constitution_version": "1.0.0",
"constitution_hash": "abc123def456..."   # sha256 of constitution.md
```

`detect-drift` validates constitution_hash hasn't drifted from current file. If constitution.md changes, ALL units potentially affected — `detect-drift` flags this with halt prompting user to re-bind.

### Anti-halu rails

- Constitution clauses MUST cite source (PRD §, KB section, past project decision, regulatory link) — enforced deterministically by `validate-constitution.sh` (per-clause source-token check; uncited clause → FAIL), re-asserted in the generate-intent Step 4 self-check
- Constitution updates require explicit user action; never auto-edited
- `generate-intent` extracts INITIAL constitution from PRD/KB; user MUST review + sign before vault locks
- Constitution overrides codebase reality: if existing code violates constitution, bolt FAILS pre-flight (intentional rail strengthening)
- `--no-constitution` flag opt-out skips constitution emission entirely (rare; for one-off greenfield demos)

### Backward compatibility

- v3.9 vaults without `constitution.md` → skill detects absence; auto-routes to user prompt "constitution.md missing; create from PRD constraints? Y/n"
- Existing vault file structure unchanged (layout-2: 4 files; legacy: 7); constitution is an additive file
- Tools that hardcoded the file count → graceful fallback (treat missing constitution as empty list)

## §boilerplate — Skill instruction language

Reusable shim. Each skill's SKILL.md should reference this section:

> **Skill instruction language**: this skill is written in English for reasoning quality. Generated content (vault docs, resolution answers, diff reports, drift findings) is recorded in the vault's existing language — same as the rest of the vault. The skill's chat prompts default to **Indonesian + English technical terms**; precedence = explicit request > the language the user writes in > Indonesian for short/ambiguous input. Tier-1 structural tokens stay English (→ `plugins/mega-sdd/references/output-language.md`).

## §id-stability — ID conventions

Across all skills, these identifiers are **stable across rounds**:

- `OQ-{CODE}-{N}` — Open Question tag.
- `F-{prefix}-NNN` — Flow ID. Prefixes: `F-U-` (user), `F-S-` (system/backend), `F-C-` (cross-cutting), `F-P-` (pipeline), `F-X-` (custom).
- `D-NNN` — ADR ID.
- Entity names — DBML table names; preserve casing across edits.

When a sibling skill creates new entries, use **next-available** number, never reuse.

