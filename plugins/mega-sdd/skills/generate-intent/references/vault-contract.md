# Vault Contract

Shared definitions referenced by all `mega-sdd` skills. **Single source of truth** — when this file changes, every skill that references it inherits the change.

> **Maintenance rule**: edits to this file are breaking changes for sibling skills. Bump the affected skill versions + CHANGELOG entry whenever you touch this file.

## §schema — `vault.json` manifest

Every `mega-sdd` vault has a `vault.json` alongside the 7 markdown files. The markdown is human-authoritative; the JSON is a derived structural index optimized for AI consumers (Claude Code, Cursor, automated agents).

```json
{
  "vault_version": "1.0",
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
    {"name": "leave_request", "purpose": "Lifecycle entity for a leave request", "doc": "03-data-model.md", "fields_count": 13}
  ],
  "flows": [
    {"id": "F-U-001", "title": "Submit leave request", "type": "user", "doc": "04-flows.md", "dod_count": 7, "source_acs": ["AC1-1","AC1-2","AC1-3","AC1-4","AC1-5"]}
  ],
  "adrs": [
    {"id": "D-001", "title": "Multi-tenant SaaS-only deployment", "doc": "05-decisions.md", "status": "accepted"}
  ],
  "open_questions": [
    {"tag": "OQ-AR-1", "priority": "P1", "doc": "02-architecture.md", "status": "open", "category": "Tech stack & architecture", "resolver_owner": "Mike Patel"}
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
  }
}
```

### Phase fields (v1.14+, Iter 35)

```yaml
phase: <int>          # NEW v1.14.0+ Iter 35 — which phase this vault represents (1, 2, 3, ...). Default 1 if not legacy-rebuild.
phase_total: <int>    # NEW v1.14.0+ Iter 35 — total phases planned (parsed from suggested-phasing.md `## Phase` heading count). Default 1 if not legacy-rebuild.
```

### Field rules

- `phase` + `phase_total`: REQUIRED v1.14.0+. Defaults `phase: 1, phase_total: 1` for back-compat (greenfield + Mode A PRD-driven + single-phase Mode B). Mode B with `--kb` parses `<KB>/99-rebuild-architecture/suggested-phasing.md` for phase count. Missing field on old vault.json (pre-v3.26.0) → treat as `phase: 1, phase_total: 1`.
- Every entity in `03-data-model.md` DBML must have a row in `entities[]`. Same for `flows[]` (one per `F-{prefix}-NNN`), `adrs[]` (one per `D-NNN`), `open_questions[]` (one per `OQ-{CODE}-{N}`).
- `open_questions[].status` mirrors the markdown checkbox: `[ ]` → `open`, `[x]` → `resolved`, `[~]` → `out_of_scope`. A `[ ]` with a `**Deferred**:` annotation maps to `deferred`.
- `open_questions[].category` matches the category header used in the `00-index.md` Open Questions roll-up.
- `open_questions[].resolver_owner` is best-effort — extract from the OQ entry's "Resolve: ..." or "owner" hint when present; otherwise `null`.
- `mode_migrate_after` is informational metadata for `mode=new` vaults only. For `mode=existing`, use `null`.
- Keep this file in sync with the markdown on every regeneration / `diff-vault` / `resolve-oq` round. The markdown is canonical; `vault.json` is a derived index.

### Operator-workflow-UX capture + Design-Source OQ (v1.17+, code-delivery slice G)

Two CAPTURE-stage rails enforced by `validate-vault-oqs.sh` (PostToolUse re-validates every vault doc write; PreToolUse Branch 10 blocks `mega-sdd:execute-bolts` on a miss). Both are **vault-FORMAT conventions** — stack-neutral, evaluated pre-binding — so they need NO framework pack (a new target stack does not change these vault conventions). Both preserve the anti-hallucination rail: the fix is always an Open Question, **never a defaulted value**.

- **Workflow flow signal (closed grammar).** A user-facing flow (`F-U-` prefix, or prefix-less; the `F-S-` / `F-C-` / `F-X-` internal classes are excluded) is a **multi-stage approval / maker-checker / workflow** flow when EITHER its actor/title line shows a maker→checker hand-off chain (a `maker … checker|approver|confirmer|reviewer|…` chain joined by `->` / `→` arrows) OR its step body carries **≥ 2 distinct decision transition steps** (approve / reject / review / confirm). One decision step alone is a simple submit; two or more is multi-stage.

- **Operator-surface requirement (the four first-class surfaces).** When a workflow flow exists, the vault MUST model the operator-facing surface as requirements **grounded in the flows** (never invented): (1) **worklist / inbox**, (2) **decision affordance** (approve/reject actions in the current state), (3) **human-readable workflow-state labels**, (4) **audit timeline** of transitions. Presence is detected by the operator-surface vocabulary in the vault's prose docs (`02-architecture.md`, `01-overview.md`, `03-data-model.md`, `04-flows.md`). (The Design-Source OQ check below additionally scans `vault.json`.)
  - **Halt `operator_surface_missing`** — workflow flow present AND no operator-surface requirement AND no Design-Source OQ → FAIL.

- **Design-Source OQ (anti-hallucination escape hatch).** When `design_system_flags.HAS_UI_COMPONENTS = true` but `HAS_TOKENS`, `HAS_A11Y`, and `HAS_VOICE_BRAND` are **all `false`**, the vault MUST carry a high-priority Design-Source Open Question (recommended tag shape `OQ-DESIGN-SOURCE-{N} [P1]`, or any OQ whose tag/text names a design-source concern — tokens / a11y / voice-brand source). **DO NOT default WCAG/Material/token values** — capture the gap as an OQ only.
  - **Halt `design_source_oq_missing`** — UI components present AND all three design flags false AND no Design-Source OQ → FAIL. (This was the captured trade-finance Phase-2 miss.)

A Design-Source OQ also satisfies the `operator_surface_missing` rail (it is the accepted "captured the miss" signal): a vault that has not yet decided its operator surface may carry a Design-Source OQ instead of inventing the surface, and the gate passes.

### When skills must regenerate `vault.json`

- `generate-intent` Step 3 — initial generation.
- `resolve-oq` Step 2c step 9 — after every Resolve / Out-of-Scope / Defer outcome.
- `diff-vault` Step 6.5 — after applying approved changes (added/changed/removed entities, flows, ADRs, auto-resolved or new OQs).
- `bind-codebase` Step 6 — audit log append (small append, not full regen, but still subject to lock per §Concurrency below).
- `detect-drift` — does NOT regenerate. detect-drift produces reports only; vault.json regen happens via `resolve-oq` (for OQ-tagged actions) or manual + generate-intent re-run (for entity/flow/ADR additions).

### Concurrency contract (v0.15+, Iter 49 — closes audit D3-012)

All `vault.json` writers MUST acquire an exclusive advisory file lock before writing. This prevents data corruption from concurrent-tab / concurrent-session writes that previously raced silently. Lock semantics REUSE the existing Iter 5 memory file-lock pattern — no new mechanism.

**Writers subject to lock (4 total):**
- `generate-intent` Step 11 (initial vault.json write)
- `bind-codebase` Step 6 (audit log append)
- `diff-vault` Step 8 (regen from markdown)
- `resolve-oq` Step 2c step 9 (regen after Resolve / Out-of-Scope / Defer outcome — v0.9.3+ Iter 52 fix-forward added explicit inline lock acquisition note; pre-v0.9.3 versions had no explicit lock note despite being listed here)

**Lock acquisition pattern (per `mega-sdd:memory` SKILL.md §file-lock):**

```
1. Compute lock_path = <vault>/vault.json.lock
2. Attempt exclusive lock: create lock_path with O_EXCL | O_CREAT
3. On collision (file exists): backoff (100ms / 500ms / 1500ms) + retry 3 attempts
4. If all 3 retries fail → emit halt `memory_in_use` blocker with details {file: "vault.json", attempts: 3}
5. On lock success: perform vault.json write atomically (temp file + rename)
6. Release lock: rm lock_path
```

**Halt envelope (reuses `memory_in_use` — no new halt type):**

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

**detect-drift exception:** detect-drift NEVER writes vault.json (existing convention per detect-drift SKILL.md §writes). No lock acquisition required.

**Backward compatibility:** pre-Iter-49 writers (any skill version that pre-dates this iter) MAY race; concurrent-write users should upgrade all skills atomically (single plugin version bump).

### OQ status tracking (v1.1+)

OQ entries in vault.json now support optional status-tracking fields. The full OQ entry shape:

```yaml
oqs:
  - id: OQ-DATA-001
    priority: P1 | P2 | P3
    section: <vault-filename.md>
    text: <question text>
    # NEW in v1.1 — additive, backwards compatible:
    status: pending | resolved | deferred | out-of-scope    # default: pending if absent
    # When status=resolved:
    resolved_at: <ISO8601 timestamp>
    resolution: <answer text>
    # When status=deferred:
    defer_to: binding | stakeholder                         # binding = brownfield code-aware; stakeholder = waiting on human (e.g., legal review, target date)
    deferred_at: <ISO8601 timestamp>
    deferred_reason: <reason / PIC / target date — e.g., "waiting on legal review by 2026-06-01">
    # When status=out-of-scope:
    out_of_scope_reason: <text>
```

**Backwards compatibility:** OQ entries without a `status` field are treated as `status: pending` by all skills. vault.json writers MAY omit `status` for pending OQs to minimize diff churn. Existing v1.0.x vaults load unchanged.

## §OQ-conventions — Open Question tagging

Every Open Question MUST have a unique tag and priority marker.

**Tag format**: `OQ-{DOC_CODE}-{N}` where:

| Doc | Code |
|-----|------|
| `01-overview.md` | `OV` |
| `02-architecture.md` | `AR` |
| `03-data-model.md` | `DM` |
| `04-flows.md` | `FL` |
| `05-decisions.md` | `DC` |
| `06-constraints.md` | `CN` |

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

### Category (v1.3+, Iter 1 — tagging; v1.4+, Iter 2 — auto-resolution activates)

Every OQ carries `category`:

- `business` — needs stakeholder judgment. Examples: feature scope, edge-case behavior, regulatory threshold, UI copy, pricing logic.
- `tech` — answerable from codebase or convention. Examples: test framework, error code format, naming convention, library version, file location.

**Default**: `business`.

### Resolution mode (v1.4+, Iter 2 — required when category=tech)

Tech OQs carry a `resolution_mode` describing how the OQ is answered without blocking human review:

- `scan` — answer deterministically found by probing codebase-map / KB. Requires `scan_query`. `bind-codebase` auto-resolves on single unambiguous match.
- `recommend` — AI picks with rationale. Requires `recommendation` + `rationale` + `scan_citations` (≥1 citation). `bind-codebase` surfaces in `binding.md` review section; user ACCEPTS / OVERRIDES / REJECTS.
- `hard_rule` — encoded as bolt-time constraint (Iter 3). Requires `hard_rule` string. `execute-bolts` validates via pre-flight scan.
- `blocking` — explicit "no auto-resolve; still needs human". Rare for tech (used when scan is inconclusive AND no safe default).

A tech OQ MUST specify `resolution_mode`; absence is a generate-intent validation error (halt with `oq_tech_missing_mode` blocker).

### Classification confidence (v1.4+, Iter 2 — DESIGN-OQ-3 resolved)

Auto-classification per Iter 2's heuristic carries a confidence label:

- `high` — heuristic matched strongly (single clear pattern hit)
- `medium` — partial match (some signal, but not unambiguous)
- `low` — fallback default; classifier defaulted to `business/blocking` because no strong signal

**Auto-resolve gate**: only `high`-confidence tech OQs auto-resolve in `bind-codebase`. `medium`/`low` confidence OQs go to `00-index.md` "## Auto-Classification Review" section. User reviews tags one-pass before binding runs; any OQ user flips from tech-to-business stays human-decided.

### Auto-classifier heuristics (v1.4+, Iter 2)

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

### Auto-Classification Review section in `00-index.md`

After OQ classification, `00-index.md` MUST include a new section before the main OQ roll-up:

```markdown
## Auto-Classification Review (v1.4+)

> Total classified: {N} OQs. Auto-resolution active: {M} (tech, high-confidence).
> Manual review recommended: {K} (tech medium/low-confidence + any flipped from business to tech).

| OQ-ID | Question | Auto-tagged | Confidence | Action |
|---|---|---|---|---|
| OQ-AR-1 | which test framework? | tech / scan | high | will auto-resolve via scan |
| OQ-AR-7 | what HTTP error envelope? | tech / recommend | medium | needs review — confirm recommend mode |
| OQ-FL-3 | does cancellation refund? | business / blocking | high | blocking — needs stakeholder |
```

User can override tags inline (e.g., flip OQ-AR-7 to `business / blocking` if "what error envelope" actually needs a product call, not a tech recommendation). Override mechanism: user edits `00-index.md` OR `vault.json`; `bind-codebase` re-reads at run time.

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
  "doc": "02-architecture.md",
  "status": "pending"
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
  "doc": "02-architecture.md",
  "status": "pending"
}
```

### Validation rules (enforced by generate-intent at write time)

- Every OQ with `category: tech` MUST have `resolution_mode` set; absence → halt `oq_tech_missing_mode`.
- Every OQ with `resolution_mode: scan` MUST have `scan_query` populated.
- Every OQ with `resolution_mode: recommend` MUST have `recommendation` + `rationale` + at least one `scan_citations` entry + `fallback_if_wrong`. Missing any → halt `oq_recommend_underspecified`.
- Every OQ with `resolution_mode: hard_rule` MUST have `hard_rule` populated (Iter 3 enforces grammar).
- `classification_confidence` MUST be one of `high | medium | low`.

**Backwards compatibility**: OQs without a `category` field → treated as `business` by all skills. OQs with `category: business` and no `resolution_mode` → defaults to `blocking`. Existing v1.0–v1.5 vaults load unchanged.

## §constitution — Project-Facing Rules (v1.8+, Iter 17)

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

- A-001: All API endpoints MUST use Sanctum auth middleware (see binding §scan_results)
- A-002: Naming: PascalCase for classes; kebab-case for routes; camelCase for JS identifiers
- A-003: Test files MUST be co-located in tests/ matching app/ structure
- A-004: No `dd()` / `var_dump()` / `console.log()` in committed code

## §B. Security baselines

- B-001: All user input passes through Form Request validators (no inline validation in controllers)
- B-002: Database queries via Eloquent ORM; raw SQL only in clearly-flagged repositories
- B-003: No secrets in code; use config('app.key') / env() abstraction
- B-004: PII fields encrypted at rest (per regulatory mandate; see 06-constraints.md §regulatory)

## §C. Architecture invariants

- C-001: Controllers MUST NOT call other Controllers; use Services
- C-002: Models MUST NOT have side effects (events emit via Observer pattern only)
- C-003: Mailables MUST be queued (not sync)
- C-004: Background jobs MUST be idempotent

## §D. Anti-patterns (from legacy / past projects)

- D-001: NEVER replicate the cfkdhl→CFKDDL silent typo from legacy customer-edit flow (per knowledge-base §critical-findings)
- D-002: NEVER add new package.json dependencies without team review
- D-003: NEVER bypass middleware via direct request manipulation

## §E. Performance constraints

- E-001: API response time median < 200ms
- E-002: Database queries within request handler < 5 (use eager loading)
- E-003: Background job execution < 30s; longer = split into smaller jobs

## §F. Compliance

- F-001: All financial transactions logged to audit_log table with user_id, timestamp, action, before/after JSON
- F-002: PII access logged separately to security_audit table
- F-003: Data retention per regulatory: 7 years for transactions, 90 days for access logs
```

### How constitution drives bolts

1. **At `generate-intent`** (v1.8+): write constitution.md from PRD + KB constraints sections + user Q&A; user reviews + signs off; updates trigger version bump
2. **At `bind-codebase`** (v1.7+): cite constitution clauses when surfacing CONFLICTs; flag binding entries that violate constitution as halts
3. **At `generate-units`** (v2.2+): for each unit, inject relevant constitution clauses into the unit's `## Hard rules` section as `id: constitution-<clause-id>` rules
4. **At `execute-bolts`** (v2.2+): pre/post-flight Hard Rule scan automatically validates constitution clauses (no separate command)
5. **At `detect-drift`** (v1.1+): flag code that violates constitution as drift findings

### Constitution version pinning

Constitution version pinned to vault:

```yaml
# In vault.json:
"constitution_version": "1.0.0",
"constitution_hash": "abc123def456..."   # sha256 of constitution.md
```

`detect-drift` validates constitution_hash hasn't drifted from current file. If constitution.md changes, ALL units potentially affected — `detect-drift` flags this with halt prompting user to re-bind.

### Anti-halu rails

- Constitution clauses MUST cite source (PRD §, KB section, past project decision, regulatory link)
- Constitution updates require explicit user action; never auto-edited
- `generate-intent` extracts INITIAL constitution from PRD/KB; user MUST review + sign before vault locks
- Constitution overrides codebase reality: if existing code violates constitution, bolt FAILS pre-flight (intentional rail strengthening)
- `--no-constitution` flag opt-out preserves pre-v1.8 behavior (rare; for one-off greenfield demos)

### Backward compatibility

- v3.9 vaults without `constitution.md` → skill detects absence; auto-routes to user prompt "constitution.md missing; create from PRD constraints? Y/n"
- Existing 7-file vault structure unchanged; constitution is 8th additive file
- Tools that hardcoded 7-file count → graceful fallback (treat missing constitution as empty list)

## §Starterkit-binding — Dual-citation format (v1.11+, Iter 27)

When `generate-intent` runs with `--scan=<codebase-map-path>` (orchestrate-flow Mode A/B starterkit-first), vault sections that touch implementation conventions use a DUAL-CITATION format: **Intent** (what the design intends) + **Starterkit binding** (how this scaffold realizes that intent). Greenfield mode skips Starterkit binding entirely.

### Sections affected

| Vault file | When dual-citation applies | What "Intent" describes | What "Starterkit binding" describes |
|---|---|---|---|
| `02-architecture.md` | Always when `--scan` set | Conceptual architecture (auth strategy, layering, integration points) | Concrete scaffold-mapped choices (base classes, framework helpers, package selection) |
| `03-data-model.md` | When framework pack defines DB conventions | Conceptual ERD (entities, relationships, business rules) | Schema realization (PK type, FK convention, timestamps, soft-delete strategy) |
| `06-constraints.md` | Always when `--scan` set | Tech-agnostic constraints (style, naming, idioms inferred from PRD/brief) | Pack-specific Hard Rules + forbidden patterns inherited from framework conventions |

### Format

Within each affected section, every architectural decision gets TWO sub-fields:

```markdown
### <Concern> (e.g., Authentication strategy)

**Intent**: <tech-agnostic statement of what the design needs>
**Starterkit binding** (`<pack-name>`):
  - <concrete realization #1>
  - <concrete realization #2>
  - …
  - Citations: `framework-conventions/<pack>.md §<section>`, `codebase-map.md §<n>`
```

### Example

```markdown
### Authentication strategy

**Intent**: Token-based API auth. Refresh-token rotation. Session-based UI auth for admin pages.

**Starterkit binding** (`laravel-base-26`):
  - API auth via Laravel Sanctum (`composer.json` lists `laravel/sanctum: ^4.0`)
  - Routes inside `auth:sanctum + whitelist.host + verified` group (per starterkit convention; see `routes/web.php` pattern)
  - Tokens stored in `personal_access_tokens` table (Sanctum default schema)
  - Session UI auth via Jetstream (already wired via `pixinvent/vuexy-laravel-bootstrap-jetstream`)
  - Citations: `framework-conventions/laravel-base-26.md §Idioms`, `codebase-map.md §7 Framework`
```

### Anti-halu rails

- **Intent** statements MUST be derivable from PRD / brief / KB. Not invented from framework defaults.
- **Starterkit binding** statements MUST cite pack file:section OR codebase-map.md line. No silent invention.
- If a pack doesn't speak to a concern → Starterkit binding sub-field shows `_None (universal defaults apply — see `_universal.md` §<section>)_` or is omitted entirely (per "omit when source content absent" rule).
- When `--greenfield` set → ONLY Intent fields generated; Starterkit binding fields absent (vault stays stack-agnostic).
- When `--scan` set BUT no pack matches (universal fallback) → Starterkit binding fields cite `_universal.md` defaults only.

### Backward compatibility

- Pre-v1.11 vaults (no Starterkit binding fields) → consumed unchanged by bind-codebase + generate-units; conventions resolved from binding step instead.
- Mixed vaults (some sections have Starterkit binding, others don't) → permitted; downstream skills handle absence gracefully.
- `bind-codebase` reading a v1.11+ vault: Starterkit binding fields supplement Hard Rule emission (clauses cited inline as `source: vault §02-architecture > Starterkit binding > Authentication strategy`).

## §Multi-scope vault — Scope tagging schema (v1.12+, Iter 28)

When `generate-intent` runs with `--scope=<id>` flag OR canonical PRD has `scopes:` block, the vault is tagged with scope metadata. Single-scope PRDs without scopes block use current single-vault schema (no scope tagging).

### vault.json extension

```json
{
  "version": "1.0",
  "title": "Order Management System — BE",
  "implementation_mode": "existing",
  "scope": "BE",
  "scope_metadata": {
    "id": "BE",
    "name": "Backend API",
    "pics": ["BE Architect 1", "BE Architect 2"],
    "priority": 1,
    "prd_sections_used": ["§Backend", "§1", "§2", "§3", "§4", "§5", "§6", "§7", "§9"],
    "sibling_scopes_in_prd": ["MW", "FE"],
    "consumed_locked_contracts": [],
    "published_locked_contracts": ["be-mw-event-bus", "be-fe-orders-api"]
  },
  "prd_sha256": "abc123...",
  "prd_path_at_generation": "./shared-docs/prd.md"
}
```

### Field rules

| Field | Required | Set by | Purpose |
|---|---|---|---|
| `scope` | When `scope_metadata` exists | generate-intent Step 0.9 | Quick lookup; matches `scope_metadata.id` |
| `scope_metadata.id` | Yes | generate-intent | Stable id from PRD frontmatter |
| `scope_metadata.name` | Yes | generate-intent | Display name from PRD frontmatter |
| `scope_metadata.pics` | Yes | generate-intent | Array of architect names (team-shared) |
| `scope_metadata.priority` | No (default 1) | generate-intent | Delivery sequencing hint |
| `scope_metadata.prd_sections_used` | Yes | generate-intent | Computed: universal_sections + scope.sections |
| `scope_metadata.sibling_scopes_in_prd` | Yes | generate-intent | Other scopes from PRD (informational) |
| `scope_metadata.consumed_locked_contracts` | Yes | generate-intent | From PRD scope's `depends_on_locked_contracts` |
| `scope_metadata.published_locked_contracts` | Yes | generate-intent | Computed: contracts where this scope is `from` in `cross_scope_dependencies` |
| `prd_sha256` | Yes | generate-intent | For memory-driven scope default on re-invocation |
| `prd_path_at_generation` | Yes | generate-intent | For PRD change tracking via diff-vault |

### 00-index.md header structure

When vault has scope metadata, `00-index.md` header MUST include:

```markdown
# Vault: <Project Name> — <Scope ID>

**Scope**: <scope_metadata.name> (`<scope_metadata.id>`)
**PICs**: <comma-separated pics list>
**Priority**: <scope_metadata.priority> (delivery sequencing hint)
**PRD source**: `<prd_path_at_generation>` (sha256: `<prd_sha256>`)
**Universal sections included**: <comma-separated universal_sections>
**Scope-specific section**: <scope_metadata.sections>

## Sibling scopes (managed externally — NOT in this vault)

- **<sibling_id>** — <sibling_name> (PIC: <name>; priority: <N>)
- ...

> Cross-scope coordination handled OUTSIDE mega-sdd. Each scope generates an independent vault.
> Locked contracts cross-referenced below for awareness, NOT enforcement.

## Locked contracts this scope PUBLISHES

- `<contract-id>` → see PRD §Cross-scope contracts > <contract-id>
- ...

## Locked contracts this scope CONSUMES

- `<contract-id>` → see PRD §Cross-scope contracts > <contract-id>
- ...
```

When vault has NO scope metadata (legacy single-scope PRD), 00-index.md header omits scope/sibling/contracts sections entirely.

### Validation rules (enforced by generate-intent at write time)

- If `scope` field present → `scope_metadata` MUST exist with all required fields
- `scope_metadata.id` MUST match PRD frontmatter `scopes.<id>` key
- `sibling_scopes_in_prd` MUST list ALL other scopes from PRD scopes block (not chosen ones)
- `prd_sha256` MUST be sha256 of PRD content at generation time (used by memory recall)
- When chosen scope == `all` (legacy flag) → vault written without `scope` field (back-compat)

### Backward compatibility

- Pre-v1.12 vaults (no `scope` field) → consumed unchanged by bind-codebase + generate-units
- Mixed vaults (some scoped, some legacy) permitted in same project — orchestrate-flow handles both
- diff-vault reads `prd_sha256` to detect PRD changes; pre-v1.12 vaults skip this check gracefully

## §boilerplate — Skill instruction language

Reusable shim. Each skill's SKILL.md should reference this section:

> **Skill instruction language**: this skill is written in English for reasoning quality. Generated content (vault docs, resolution answers, diff reports, drift findings) is recorded in the vault's existing language — same as the rest of the vault. The skill's chat prompts adapt to the user's language at runtime.

## §id-stability — ID conventions

Across all skills, these identifiers are **stable across rounds**:

- `OQ-{CODE}-{N}` — Open Question tag.
- `F-{prefix}-NNN` — Flow ID. Prefixes: `F-U-` (user), `F-S-` (system/backend), `F-C-` (cross-cutting), `F-P-` (pipeline), `F-X-` (custom).
- `D-NNN` — ADR ID.
- Entity names — DBML table names; preserve casing across edits.

When a sibling skill creates new entries, use **next-available** number, never reuse.

## §halt-escalation-discipline (v3.50.0+, Iter 67.7 — anti-erosion gate)

Halts are classified into THREE operational categories. Categorization is per-halt and authoritative (lives in this doc + per-halt description below). See `docs/superpowers/audits/2026-05-27-halt-escalation-classification.md` and `docs/superpowers/audits/2026-05-27-c1-collapse-attestation.md` for full classification + per-halt reasoning + reviewer attestation.

### Three categories

| Cat | Behavior | When applicable |
|---|---|---|
| **C1 — Self-resolve** | Skill fixes own output, emits `halt_self_resolved` telemetry + chat one-liner, NEVER halts. | Skill emitted bad output (missing field, parse error, citation typo) AND can re-derive from in-context info. NO ground-truth fabrication. NO silent failure hiding (every fix logged). |
| **C2 — Business gate** | Halt + PROPOSE recommendation + sign-off. No raw "what should I do?" questions. | Resolution needs domain/stakeholder intent (scope choice, conflict resolution, business rule). Skill emits halt envelope with `recommendation:` field populated. |
| **C3 — Grounding gate** | Halt — enforce via [HOOK-VALIDATE] slice (deterministic validator), not prose. | Continuing would require hallucinating ground truth (vault↔code conflict, traceability ID drop). Enforced by hook + state file, not skill body text. |

### C1 self-resolve protocol (v3.50.0+, Iter 67.7 Phase A)

When a skill detects a C1 condition during execution:

1. **Apply the documented fix** (per the halt's `C1 SELF-RESOLVE` description in this file).
2. **Emit chat one-liner:** `[self-resolved] <halt_type>: <fix_applied>` (single line, not a halt envelope).
3. **Emit telemetry event:**
   ```json
   {
     "event_type": "halt_self_resolved",
     "payload": {
       "halt_type": "<halt name>",
       "fix_applied": "<short description>",
       "original_emit_site": "<skill_name>:<step_id>",
       "logged_at_chat": true
     }
   }
   ```
4. **Continue execution.** Do NOT emit a `blocker:` envelope. Do NOT pause the chain. Do NOT prompt the human.

### Escalation paths from C1 → C2

A C1 halt MUST escalate to C2 (with proposal) when:
- Resolution would require ground truth the model lacks (e.g., re-picking from empty inventory)
- Documented retry budget exhausted (e.g., `invalid_handoff` after 2 producer re-invokes)
- The fix would silently hide a class of failure the human should know about (catch-all safety)

When escalating, emit standard C2 halt envelope WITH the C1 attempt history in `details.retry_attempts: [...]` for forensics.

### C2 propose-and-confirm discipline (v3.50.0+, Iter 67.7 Phase D candidate — future iter)

Every C2 halt envelope MUST include a `recommendation:` field with the skill's best-effort guess + rationale. The halt should not pose a raw question. Format:

```yaml
blocker:
  type: <C2 halt>
  ...
  recommendation:
    proposed_action: "<one-line>"
    rationale: "<why this is the best guess given context>"
    confidence: "high | medium | low"
    alternatives: ["<option A>", "<option B>"]
  user_response_required: true
```

Implementation deferred to Phase D after Phase A real-run proof. Current C2 halts emit options but rarely propose; Phase D doc-only pass formalizes this.

### C3 enforcement via [HOOK-VALIDATE]

C3 halts are enforced by `plugins/mega-sdd/scripts/validate-handoff-*.sh` validators + `PreToolUse` hooks per `plugins/mega-sdd/references/fork-a-recovery-map.md`. Skill bodies declaring C3 halts can mention them as design vocabulary, but the actual enforcement is the hook layer. Slice 1 shipped Iter 67.6 (binding→units OQ-IDs); slices 2-5 follow the same pattern for CONFLICT-IDs / Hard Rules / vault→binding / units→bolts.

### Backward compatibility

Halts not yet classified (or in older skill bodies) default to legacy behavior (ALWAYS STOP). Phase A formalizes 6 already-soft halts as C1. Phase B (separate iter, contingent on Phase A real-run proof + attestation audit sign-off) expands to remaining 22 C1 candidates.

## §halt-protocol — Unified `blocker` envelope (v0.14, extended v1.1)

When a skill running in `--auto` mode hits something that requires human judgment (unresolved P1 OQ blocking downstream work, diff-vault conflict, framework mismatch), it emits a structured YAML artifact called a **blocker**. The orchestrator (`/mega-sdd:orchestrate-flow`) catches blockers, pauses the chain, and surfaces the artifact in chat for the user to act on.

The envelope is uniform across types so a single consumer can handle all of them.

### Schema

```yaml
blocker:
  type: oq_blocker | diff_conflict | drift_framework_mismatch | bind_conflict | dep_missing | test_fail | cycle_detected | mode_migrate | cross_squad_dep_invalid | interface_ref_missing | cross_squad_ambiguous | cross_squad_interface_draft | deep_scan_subagent_failed | deep_scan_cache_corrupt | deep_scan_subagent_all_failed | starterkit_rule_citation_missing | bind_conflict_constitution_violation | framework_pack_missing | framework_pack_cycle | framework_pack_unparseable | constitution_drift_detected | memory_in_use | dispatch_prompt_too_large | bolt_repeated_partial_failure | provenance_missing | bolt_introduces_locked_drift | self_assessment_missing | oq_recommend_citation_invalid | routing_outcome_corrupt | predictive_check_failed | invalid_handoff | handoff_type_mismatch | model_tier_unknown | pbt_citation_invalid | handoff_missing | artifact_missing | partial_state_corrupt | dedup_ambiguous | hard_rule_unparseable | hard_rule_violated | memory_schema_mismatch | prd_no_scopes_block_user_rejected_retrofit | prd_path_missing | prd_retrofit_low_confidence | quality_gate_failed | scope_not_declared_in_prd | install_failed | pkg_mgr_not_found | oq_tech_missing_mode | oq_recommend_underspecified | oq_scan_missing_query | oq_business_p1_unresolved | no_starterkit_detected | module_blocked_by | hard_rule_unanchored | unit_underspecified | verify_unit_writable
  tag: <stable identifier — OQ-AR-1, D-007, etc.>
  priority: P1 | P2 | P3 | n/a
  context: "<what's blocked, e.g. 'Implementing F-U-001 backend' or 'Applying diff-vault Step 6'>"
  resolver_owner: "<name or role, e.g. 'Mike Patel (Eng Lead)'>"
  resolver_route: "<where to find them, e.g. 'ask in #timeoff-team'>"
  vault_version: "<current vault version, e.g. '1.1'>"
  source_skill: generate-intent | diff-vault | detect-drift | bind-codebase | scan-codebase | generate-units | execute-bolts | extract-intelligence | resolve-oq | orchestrate-flow | emit-agents-md | emit-fsd | install-deps | memory
  # type-specific fields below
  conflict_old: "<vault state>"            # diff_conflict only
  conflict_new: "<new PRD state>"          # diff_conflict only
  options: ["supersede", "keep_vault", "capture_both"]  # diff_conflict only
  detected_framework: "<e.g. 'Java/Spring'>"  # drift_framework_mismatch only
  expected_framework: "<e.g. 'PHP/Laravel'>"  # drift_framework_mismatch only
```

### Canonical `next_action` field shape (v0.15+, Iter 62 per A3-004)

The `next_action` field in halt envelope is documented per-producer with varying shapes (object `{type, hint}`, plain string, or omitted). Consumer dispatch must branch on shape. Iter 62 pins canonical shape:

```yaml
# CANONICAL (preferred for new halts, v0.15+):
next_action:
  type: <action_id>                            # enum (see below)
  hint: "<one-line user-facing instruction>"   # required
  commands: ["<bash command>", ...]            # optional; ordered list of recovery commands

# LEGACY (accepted for backward compat, pre-v0.15):
next_action: "<one-line prose string>"         # plain string form

# OMITTED (NOT accepted v0.15+):
# next_action: <missing>                        → halt invalid_handoff during validation
```

`type` enum (extensible per skill):

- `inspect_subskill_logs` — read chat_tail_excerpt + investigate sub-skill output
- `rename_and_retry` — rename corrupt file to .corrupt-<timestamp> + re-run
- `re_run_producer` — re-run the producer skill standalone to reproduce
- `edit_skill_template` — fix skill body template emission (producer bug)
- `user_install_dep` — user installs missing native binary
- `user_resolve_oq` — user runs `/mega-sdd:resolve-oq` interactively
- `user_review` — user inspects artifact + decides
- `invoke_skill` — orchestrator auto-invokes recovery skill
- `chain_complete` — terminal; no further action
- `file_plugin_bug` — internal bug; user files at gitlab/issue tracker
- `log_and_continue` — soft halt; orchestrator logs + proceeds
- `manual_review` — user reviews state manually (no auto-action)

Consumer dispatch (orchestrate-flow halt displayer):

1. Read `next_action.type` if present → format hint per type semantics (e.g., wrap commands in code fence)
2. Else read `next_action.hint` if it's a string → display as plain text
3. Else (no next_action) → emit `invalid_handoff` halt at validation gate (Iter 60 strict mode)

**Backward compatibility:** all pre-v0.15 halt emit sites work unchanged. The canonical shape is RECOMMENDED for new halts but not enforced — consumers fall back to legacy string-only form.

### Type-specific guidance

**`oq_blocker`** — emitted by `generate-intent` (when generation surfaces a P1 that would block downstream tasks) or by AI consumers reading the vault non-interactively. The `tag` is the OQ identifier. `priority` is always `P1` (lower priorities don't halt).

**`diff_conflict`** — emitted by `diff-vault` Step 5 when a Resolved-OQ conflict or Decision conflict requires stakeholder input. `tag` is the OQ or ADR ID. `priority` is `n/a` (conflicts aren't priority-tagged). `conflict_old`, `conflict_new`, `options` are required.

**`drift_framework_mismatch`** — emitted by `detect-drift` Step 1.5 when the vault implies one framework but the codebase is another. `tag` is `n/a`. `priority` is `n/a`. `detected_framework` and `expected_framework` are required.

- `deep_scan_subagent_failed` — scan-codebase v2.6.0+: a deep-scan subagent (auth/rbac/ui-ux/libs) failed once. Soft halt: auto-retried; on second failure emits partial starterkit-context.yaml with `partial: true`. Pipeline continues (warn-only).
- `deep_scan_cache_corrupt` — scan-codebase v2.6.0+: starterkit-context.yaml exists but fails YAML parse. Soft halt: cache auto-invalidated; subagents re-dispatched. Transparent to user.
- `deep_scan_subagent_all_failed` — scan-codebase v2.6.0+: ALL 4 deep-scan subagents failed (likely API outage). ALWAYS STOP: user re-runs scan-codebase later. Existing starterkit-context.yaml (if any) preserved untouched.
- `starterkit_rule_citation_missing` — generate-units v2.6.0+: a starterkit-derived Hard Rule lacks `Citation: starterkit-context.yaml §<path>` field. ALWAYS STOP: user must edit unit to add citation, then re-run Step 12.5 polished-prompt render pass.
- `bind_conflict_constitution_violation` — bind-codebase v1.8+, Iter 20: claim conflicts with constitution.md security clause. ALWAYS STOP. Resolution: review constitution clauses + reject/accept conflict.
- `framework_pack_missing` — bind-codebase v1.9+, Iter 23: framework convention pack referenced but file absent. ALWAYS STOP. Resolution: create pack or remove reference.
- `framework_pack_cycle` — bind-codebase v1.9+, Iter 23: pack inheritance has cycle (A extends B extends A). ALWAYS STOP.
- `framework_pack_unparseable` — bind-codebase v1.9+, Iter 23: pack file fails YAML/markdown parse. ALWAYS STOP.
- `constitution_drift_detected` — detect-drift v1.4+, Iter 30: §B Security or §F Compliance constitution clause drift detected in code. ALWAYS STOP.
- `drift_framework_mismatch` — detect-drift v1.2+, Iter 12: scanned code framework differs from vault framework. ALWAYS STOP.
- `diff_conflict` — diff-vault v0.3+, Iter 3: Resolved-OQ or Decision conflict requires stakeholder input. ALWAYS STOP (user resolves via diff-vault interactive walk). Emitted by `diff-vault`.
- `memory_in_use` — memory v1.0+: file lock collision; concurrent writer holds lock. **C1 SELF-RESOLVE (v3.50.0+, Iter 67.7 Phase A):** retry budget extended to 10 attempts with exponential backoff (250ms → 500ms → 1s → 2s → 4s → 8s → 8s → 8s → 8s → 8s, total ~40s). If still locked after 10x → log + skip memory update (memory writes are advisory; chain proceeds). Emits `halt_self_resolved` telemetry event with `fix_applied: "retry_exhausted_memory_skipped"`. Human visible via chat one-liner `[self-resolved] memory_in_use: skipped after 10 retries`. NEVER halts the chain.
- `dispatch_prompt_too_large` — execute-bolts v2.6+, Iter 30: assembled bolt dispatch prompt exceeds 10KB hard cap. ALWAYS STOP. Resolution: re-tier context.
- `bolt_repeated_partial_failure` — execute-bolts v2.6+, Iter 30: bolt failed 3 partial-state recovery cycles. ALWAYS STOP. Resolution: review unit spec.
- `provenance_missing` — execute-bolts v2.6+, Iter 30: bolt modified file lacks provenance trailer. ALWAYS STOP.
- `bolt_introduces_locked_drift` — execute-bolts v2.6+, Iter 30: bolt drift hits a LOCKED entity. ALWAYS STOP (eligible for propose-and-confirm override).
- `self_assessment_missing` — execute-bolts v2.6+, Iter 30: bolt-report.md lacks self-assessment section. ALWAYS STOP.
- `dep_missing` — scan-codebase v2.0+, Iter 6: required binary (tree-sitter when --engine=tree-sitter forced) not found. ALWAYS STOP.
- `oq_recommend_citation_invalid` — generate-intent v1.3+, Iter 2: OQ recommendation cites non-existent KB section. ALWAYS STOP.
- `mode_migrate` — orchestrate-flow v1.0+: vault.json `mode` field (greenfield | existing) doesn't match CWD signals (.git present, package.json present, etc.). **C1 SELF-RESOLVE (v3.50.0+, Iter 67.7 Phase A):** re-detect from CWD signals deterministically (.git present + composer.json/package.json/etc. → `existing`; absence → `greenfield`); update `vault.json.mode`; log change to chat. Emits `halt_self_resolved` telemetry with `fix_applied: "mode_redetected: <old> → <new>"`. NEVER halts. User can override by passing explicit `--mode=<value>` flag on next chain invocation. CWD signals are ground truth — no fabrication risk.
- `routing_outcome_corrupt` — orchestrate-flow v3.0.0+, Iter 33: routing-outcomes.md fails parse. **C1 SELF-RESOLVE (v3.52.0+, Iter 67.7.3 — HOOK-LAYER ENFORCED via SessionStart):** at session start, hook checks `<cwd>/.mega-sdd/memory/routing-outcomes.md` for UTF-8 validity + schema header presence (`# Routing Outcomes` marker in first 200 chars). If corrupt → rename to `.corrupt-<ISO8601>`; emit `halt_self_resolved` telemetry with `corruption_reason` (`non-utf8-binary` or `missing_schema_header`); chain proceeds with default routing. Sandbox-proven 2026-05-27. NEVER halts.
- `predictive_check_failed` — orchestrate-flow v3.0.0+, Iter 33: predictive preflight check marked `fatal: yes` failed. ALWAYS STOP. Resolution: user fixes precondition (install dep / add framework pack / etc.) per `next_action.hint`; re-run chain.
- `invalid_handoff` — orchestrate-flow v3.0.0+, Iter 33: handoff YAML from sub-skill fails schema validation (missing REQUIRED field, or CONDITIONAL field missing when condition met, or YAML parse error). **C1 SELF-RESOLVE (v3.53.0+, Iter 67.8 Phase B slice B.1 — HOOK-LAYER ENFORCED via Stop+PreToolUse):** at turn end, Stop hook scans transcript for last assistant message; if it contains `handoff:` block, invokes `plugins/mega-sdd/scripts/validate-handoff-yaml.sh` which parses + validates against this schema and writes `<cwd>/.mega-sdd/.handoff-validation-state.json` (current-truth, overwrite-not-append). PreToolUse Skill matcher `mega-sdd:*` (excluding `mega-sdd:using-mega-sdd` anchor) reads that state — if status=FAIL, blocks the next mega-sdd skill invocation with the validator's reason. Retry counter tracks repeated failures of same skill+halt: 1st failure = self-resolve with "re-invoke producer" recommendation; 2nd failure = escalate to C2 user_review. Producer skill author still fixes handoff template per handoff-contract.md schema for permanent fix; hook is the enforcement layer. NEVER halts the chain on first fail; blocks next-skill consumption deterministically. Sandbox-proven 2026-05-27.
- `handoff_type_mismatch` — orchestrate-flow v3.0.0+, Iter 33 F4: handoff YAML field type doesn't match TYPE annotation in handoff-contract.md schema. ALWAYS STOP. Resolution: producer skill author fixes type emission per handoff-contract.md TYPE annotation; re-run chain.
- `model_tier_unknown` — orchestrate-flow v3.1.0+, Iter 34: model-tier override references a role not in references/model-tiers.md catalog. **C1 SELF-RESOLVE (v3.50.0+, Iter 67.7 Phase A — formalizing pre-existing SOFT semantics):** log + ignore override; chain proceeds with catalog default for unknown roles. Emits `halt_self_resolved` telemetry with `fix_applied: "unknown_role_catalog_default_used"`. Forward-compat for future role additions. NEVER halts.
- `pbt_citation_invalid` — execute-bolts v2.4+, Iter 20: a PBT property block declares `Cites: §Decision-D-NNN` but the cited ADR ID does not exist in the bound vault `decisions/` directory. ALWAYS STOP. Resolution: fix the citation in the unit's PBT block (or remove the property if the underlying decision was rescinded), then re-run the bolt. Closes Iter 38 audit finding D3-004.
- `handoff_missing` — orchestrate-flow v3.2.1+, Iter 40 (semantics corrected Iter 43): sub-skill chat output contains no parseable `handoff:` YAML block (skills emit handoff inline in chat, not to a file). ALWAYS STOP. Resolution: inspect sub-skill chat output (`chat_tail_excerpt` in halt envelope shows last 500 chars) for crash logs / parse errors / OS-level failures; re-run sub-skill standalone to reproduce; report as skill-author bug if reproducible. Closes Iter 38 audit finding D3-001 (silent-failure path closure).
- `artifact_missing` — orchestrate-flow v3.2.0+, Iter 40: handoff YAML lists `artifacts: [paths]` and one or more paths fail existence check (`test -f` for files, `test -d` for directories). ALWAYS STOP. Resolution: re-run producer skill standalone to confirm artifacts actually written; inspect producer chat for mid-write crash logs. Closes Iter 38 audit finding D3-002 (silent-failure path closure).
- `partial_state_corrupt` — execute-bolts v2.7.3+, Iter 40: `--resume` mode loaded `<vault>/bolts/U-XXX/partial-state.json` (canonical path per execute-bolts §Partial-state contract — corrected from initial Iter 40 vault-contract description) and JSON parse failed. **C1 SELF-RESOLVE (v3.51.1+, Iter 67.7.2 — HOOK-LAYER ENFORCED via SessionStart):** at session start, hook scans `<cwd>/.mega-sdd/vaults/*-bound/bolts/U-*/partial-state.json`; any file failing JSON parse is renamed to `partial-state.json.corrupt-<ISO8601>` (forensics preserved); next `--resume` invocation restarts fresh from unit spec. Emits `halt_self_resolved` telemetry with full payload (`unit_id`, `original_path`, `corrupt_path`). Sandbox-tested 2026-05-27 (NOT against TF Import production data per safety rule). NEVER halts.
- `dedup_ambiguous` — generate-units v2.5+, Iter 41 registry closure: dedupe step finds multiple existing units that could match a new claim (target_files overlap >threshold). ALWAYS STOP. Resolution: user picks the canonical unit OR confirms creating a new one. Previously emitted but missing from canonical halt registry — Iter 41 sweep closure.
- `hard_rule_unparseable` — generate-units v2.0+, Iter 6: a unit's `## Hard Rules` block contains ast-grep YAML that fails parse OR an ANCHOR reference that cannot be resolved. ALWAYS STOP. Resolution: user fixes the unit's Hard Rules block syntax. Iter 41 sweep closure (was emitted but missing from canonical registry).
- `hard_rule_violated` — execute-bolts v1.2+, Iter 3: post-flight ast-grep scan found code in working tree violates a unit's Hard Rule. ALWAYS STOP (no auto-retry; user reviews + decides revert vs edit). Resolution: amend the bolt OR override the rule with explicit user approval. Iter 41 sweep closure (was emitted but missing from canonical registry).
- `memory_schema_mismatch` — memory subsystem v1.0+, Iter 5: persisted memory file schema_version differs from current code's expected schema. ALWAYS STOP (presents migration prompt). Resolution: user opts in to migration via `/mega-sdd:memory migrate`. Iter 41 sweep closure.
- `prd_no_scopes_block_user_rejected_retrofit` — generate-intent v1.6+, Iter 28: PRD lacks `scopes:` frontmatter AND user rejected AI retrofit AND chose cancel. ALWAYS STOP. Resolution: user manually retrofits PRD OR re-runs with single-scope fallback. Iter 41 sweep closure (was emitted by Iter 28 but missing from canonical registry).
- `prd_path_missing` — diff-vault v1.3+, Iter 29: `vault.json.prd_path_at_generation` points to non-existent PRD file. ALWAYS STOP. Resolution: user restores the PRD at the recorded path OR regenerates the vault with the current PRD. Iter 41 sweep closure.
- `prd_retrofit_low_confidence` — generate-intent v1.6+, Iter 28: AI retrofit subagent returned `overall_confidence: LOW`. ALWAYS STOP. Resolution: user reviews and accepts anyway / chooses single-scope fallback / cancels. Iter 41 sweep closure.
- `quality_gate_failed` — extract-intelligence v1.0+, Iter 9 (wave-based KB extraction): a wave's quality-gate threshold (citation density / hallucination floor / canonicalization completeness) is not met. ALWAYS STOP. Resolution: user reviews wave output and either accepts (with QA notes recorded) OR re-runs wave with adjusted prompt. Iter 41 sweep closure.
- `scope_not_declared_in_prd` — generate-intent v1.6+, Iter 28: `--scope=<id>` flag references a scope ID that's not in the PRD's `scopes:` frontmatter block. ALWAYS STOP. Resolution: user picks a valid scope from PRD's declared list OR cancels. Iter 41 sweep closure.
- `install_failed` — install-deps v1.0.0+, Iter 55: install command exited non-zero OR `verify_cmd` failed post-install. ALWAYS STOP. Details `{tool, install_cmd, verify_cmd, exit_code, stderr_tail (last 500 chars), subtype: install_command_failed | verify_after_install_failed}`. Resolution: inspect stderr_tail, fix root cause (PATH refresh / repo signing / network), re-run `/mega-sdd:install-deps --tools=<failed-tool>` to retry single tool. Source skill: `install-deps`.
- `pkg_mgr_not_found` — install-deps v1.0.0+, Iter 55: no compatible package manager detected for OS (PKG_MGR=`none` AND no cross-platform fallbacks like cargo/npm/go on PATH). ALWAYS STOP. Details `{os, distro, attempted_pkg_mgrs, fallbacks_attempted}`. Resolution: install brew (macOS) / verify apt is on PATH (Linux) / install WSL Ubuntu (Windows native) → re-run `/mega-sdd:install-deps`. Source skill: `install-deps`.

#### Iter 58 enum closure — 9 halts previously orphan-in-the-wild (Iter 56 audit A1-001)

These 9 halt types were emitted by producers as `→ halt <name>` or `type: <name>` in skill bodies but were missing from the canonical enum. Per Iter 33 schema validation, orchestrate-flow would have rejected them as `invalid_handoff`. Iter 58 added all 9 to the enum + canonical description blocks below.

- `oq_tech_missing_mode` — generate-intent v1.6+, Iter 28: PRD declares technical OQ but `mode` field missing on the OQ entry (can't classify as `tech / scan` vs `tech / recommend`). ALWAYS STOP. Resolution: user adds `mode: scan` or `mode: recommend` to the OQ frontmatter; re-run generate-intent. Source skill: `generate-intent`.

- `oq_recommend_underspecified` — generate-intent v1.6+ / bind-codebase v1.4+, Iter 3: an OQ marked `mode: recommend` lacks one or more required fields (`recommendation`, `rationale`, `citations`). ALWAYS STOP. Details `{oq_id, missing_fields}`. Resolution: user fills missing fields in OQ entry per `vault-contract.md §Tech-OQ Recommendations schema`. Source skill: `generate-intent` (Mode B Q&A) or `bind-codebase` (Tech-OQ auto-resolution).

- `oq_scan_missing_query` — generate-intent v1.6+, Iter 28: an OQ marked `mode: scan` lacks the `scan_target` field that tells `bind-codebase` Tech-OQ auto-resolver what to grep for. ALWAYS STOP. Details `{oq_id}`. Resolution: user adds `scan_target: codebase-map §<section>` or `scan_target: <file-pattern>` to the OQ entry. Source skill: `generate-intent`.

- `oq_business_p1_unresolved` — orchestrate-flow v1.3+, Iter 4 (canonical of `oq_blocker`): a P1 business OQ blocks downstream pipeline; chain pauses until user resolves via `/mega-sdd:resolve-oq`. ALWAYS STOP. Details `{oq_id, priority: P1, category: business, blocked_units}`. Resolution: user answers OQ interactively; vault.json updated; chain resumes. Source skill: `orchestrate-flow` (re-emits from generate-intent's prose claim). **Deprecation note:** older skill bodies may emit `oq_blocker` (legacy name); both are accepted during transition. New code should use `oq_business_p1_unresolved` as canonical name.

- `no_starterkit_detected` — orchestrate-flow v2.4+, Iter 27: starterkit-first mode default but no framework manifest detected (no composer.json / package.json / Gemfile / etc.) AND user did NOT pass `--greenfield` flag. ALWAYS STOP. Details `{cwd, detected_manifests, suggestions}`. Resolution: user picks (a) scaffold starterkit, (b) re-run with `--greenfield`, or (c) cancel. Source skill: `orchestrate-flow`.

- `module_blocked_by` — execute-bolts v2.0+, Iter 11: bolt invocation blocked because prerequisite module hasn't completed yet (module-graph dependency). ALWAYS STOP. Details `{unit_id, blocking_module_id, blocked_status}`. Resolution: user runs prerequisite module first OR adjusts module dependency graph in `vault/_meta/modules.yaml`. Source skill: `execute-bolts`.

- `hard_rule_unanchored` — execute-bolts v2.0+, Iter 6: a unit's `## Hard Rules` block references an ANCHOR (file path / function signature) that cannot be resolved against the current codebase-map. ALWAYS STOP. Details `{unit_id, rule, missing_anchor}`. Resolution: user fixes anchor reference (rename to current symbol) OR removes obsolete rule. Source skill: `execute-bolts`.

- `unit_underspecified` — generate-units v2.0+, Iter 1: a generated unit lacks one or more required spec fields (`target_files`, `acceptance_test`, `depends_on` graph) preventing bolt dispatch. ALWAYS STOP. Details `{unit_id, missing_fields}`. Resolution: user fills missing fields OR re-runs generate-units with `--strict` for stricter generation. Source skill: `generate-units`.

- `verify_unit_writable` — execute-bolts v2.0+, Iter 1: a `task_type: verify` unit has non-empty `target_files` with operation ∈ {create, modify, delete} (verify units should not write code). **C1 SELF-RESOLVE (v3.52.0+, Iter 67.7.4 — HOOK-LAYER DETECTION via SessionStart, DISPATCH-LAYER AUTO-CLEAR in execute-bolts):** at session start, hook scans `<cwd>/.mega-sdd/vaults/*-bound/units/U-*.md` AND `<cwd>/.mega-sdd/vaults/*-bound/units/U-*/unit.md` (both layouts). For each `task_type: verify` unit with forbidden ops → emit `halt_self_resolved` telemetry (`unit_id`, `unit_path`, `forbidden_operations`) + chat notice in anchor injection. On-disk unit NOT modified (preserves bad spec for human review). Dispatch-time auto-clear is execute-bolts's responsibility (separate code path). Detection-only at SessionStart means the warning re-fires on every session until human fixes the unit — intentional visibility. Sandbox-proven 2026-05-27. NEVER halts. Source skill: `execute-bolts`.

#### Iter 58 — `quality_gate_failed` subtypes (Iter 53/54 closure per A1-003)

Iter 53 (`starterkit_metrics_inconsistent`) and Iter 54 (`pdf_render_failed`, `template_slot_unfilled`) extended the existing `quality_gate_failed` halt with a `subtype:` discriminator. Iter 58 documents the canonical subtype enum here:

`quality_gate_failed` subtypes:
- *(omitted OR `wave_quality_threshold_unmet`)* — extract-intelligence v1.0+, Iter 9 (original): wave-based KB extraction quality threshold (citation density / hallucination floor / canonicalization completeness) not met. Resolution: user reviews wave output + accepts (with QA notes) OR re-runs wave with adjusted prompt.
- `starterkit_metrics_inconsistent` — orchestrate-flow v3.4.0+, Iter 53: generate-units handoff reports `units_with_starterkit_rules > 0` but `starterkit-context.yaml` flags `partial: true` (rules pulled from incomplete framework slice may cite missing conventions). Resolution: re-run `scan-codebase --force-deep` then regenerate units.
- `pdf_render_failed` — emit-fsd v1.0.0+, Iter 54: pandoc exited non-zero during PDF render in §Step 5.3. Details include `pandoc_stderr_tail` (last 500 chars). Resolution: inspect stderr, fix LaTeX engine config (typically install tectonic via `/mega-sdd:install-deps`), re-run emit-fsd.
- `template_slot_unfilled` — emit-fsd v1.0.0+, Iter 54: an FSD-template slot marker `{{slot_name}}` remained unfilled in `FSD.md` output (internal bug — section-mapping.md missing extraction rule for the slot). Resolution: file plugin bug; meanwhile run emit-fsd with `--sections=<subset>` to skip the affected section.
- `replan_budget_exceeded` — anti-recursive guard v3.45.0+, Iter 65 (per spec §4.2 meta-tune #5 reuse-first decision): a task's re-plan count exceeded `max_replan_count` cap (default 2; configurable post-Iter-68 telemetry tuning). Details `{task_id, max_replan_count, actual_replan_count, trigger_history: [<closed-enum triggers per RULE 1>]}`. Resolution: user reviews trigger history; if hitting same trigger repeatedly, root-cause the underlying issue (don't just raise the cap); if scope grew beyond original task, restart task with corrected scope.
- `revalidate_budget_exceeded` — anti-recursive guard v3.45.0+, Iter 65: a task's re-validate count exceeded `max_revalidate_count` cap (default 3). Details `{task_id, max_revalidate_count, actual_revalidate_count}`. Resolution: validators are LEAF NODES — repeated validation failure means root issue is in validated artifact, not validation logic. Fix artifact; do not validate the validation.

Consumer dispatch logic MUST branch on `details.subtype` field. If `subtype` is absent OR empty, treat as the original `wave_quality_threshold_unmet` semantic (extract-intelligence).

### Multiple blockers in one run

For multiple blockers in a single sub-skill run, emit an array:

```yaml
blockers:
  - type: oq_blocker
    tag: OQ-AR-1
    priority: P1
    context: "Implementing F-U-001 backend"
    resolver_owner: "Mike Patel"
    resolver_route: "ask in #timeoff-team"
    vault_version: "1.0"
    source_skill: generate-intent
  - type: diff_conflict
    tag: OQ-DC-2
    priority: n/a
    context: "Applying diff-vault to PRD-v2.pdf"
    resolver_owner: "Mike Patel"
    resolver_route: "ask in #timeoff-team"
    vault_version: "1.1"
    source_skill: diff-vault
    conflict_old: "Idempotency 24h TTL (D-010)"
    conflict_new: "Idempotency 7d TTL (PRD §X.Y)"
    options: ["supersede", "keep_vault", "capture_both"]
```

### Backward compatibility

Vaults generated under v0.13 still emit the legacy `oq_blocker:` YAML form (without the unified envelope). AI consumers reading vaults should accept both shapes for one release cycle:

```yaml
# Legacy v0.13 form (still valid):
oq_blocker:
  tag: OQ-AR-1
  priority: P1
  ...

# New v0.14 form:
blocker:
  type: oq_blocker
  tag: OQ-AR-1
  priority: P1
  ...
```

Vaults regenerated under v0.14+ produce only the new form.

### Field rules

- `tag` mirrors the markdown identifier (OQ tag, ADR ID, or `n/a`). Never invent.
- `resolver_owner` is best-effort; use `null` if not declared in the OQ entry.
- `vault_version` is the current vault version at emit time, not the target post-resolution version.
- `source_skill` identifies the emitting skill — needed because consumers may dispatch differently per source.
- `context` is human-readable; keep it short (one line). It's not a structured field.
- For `diff_conflict`, `options` MUST list the user choices verbatim from the diff report (e.g., "supersede", "keep_vault", "capture_both").

### Type-specific schemas (v1.1 additions)

```yaml
# bind_conflict — emitted by bind-codebase when CONFLICT count > 0
details:
  vault: <path>
  conflict_count: N
  conflicts:
    - id: C-001
      vault_claim: <text>
      codebase_reality: <text>
      suggested_action: KEEP_VAULT | KEEP_CODE | DEFER | SPLIT

# dep_missing — emitted by execute-bolts when superpowers AND vendored fallback both absent
details:
  required_skills: [executing-plans, subagent-driven-development, test-driven-development, using-git-worktrees]
  missing_real: [...]
  missing_vendored: [...]
  install_command: "/plugin install superpowers"

# test_fail — emitted by execute-bolts after max retries
details:
  unit_id: U-XXX
  retries_attempted: N
  test_command: <cmd>
  last_failure_output: <verbatim test output>
  files_touched: [...]

# cycle_detected — emitted by generate-units when dependency DAG has cycle
details:
  cycle_path: [U-001, U-002, U-001]

# mode_migrate — emitted by orchestrate-flow on vault.mode vs CWD signal mismatch
details:
  vault_mode: greenfield | existing
  cwd_signals: [.git, package.json, ...]
  resolution: "update vault mode" | "re-detect"

# cross_squad_dep_invalid — emitted by generate-units in multi-squad mode
# when a unit's depends_on references a unit in a different squad
details:
  unit_id: U-XXX
  unit_squad: <squad-id>
  dependency_id: U-YYY
  dependency_squad: <squad-id-different>

# interface_ref_missing — emitted by generate-units when a unit's
# produces_interfaces or consumes_interfaces references an interface ID
# that has no corresponding file in <vault>/interfaces/
details:
  unit_id: U-XXX
  missing_interface_id: <kebab-id>
  referenced_in: consumes_interfaces | produces_interfaces

# cross_squad_ambiguous — emitted by generate-units when two or more
# squads in _meta/squads.yaml claim ownership of the same artifact at
# the same precedence level
details:
  artifact: <flow-id or entity-name or component-name>
  artifact_kind: flow | entity | component | adr | oq
  claimed_by_squads: [<id-1>, <id-2>, ...]
  matched_via: owns_layers | owns_components | owns_flow_prefixes | owns_feature_tags

# cross_squad_interface_draft — emitted by execute-bolts (specifically
# --per-squad or --squad=<id> modes) when a unit consumes an interface
# whose status is draft, blocking consumer execution until producer locks
details:
  unit_id: U-XXX
  unit_squad: <consumer-squad-id>
  consumed_interface_id: <kebab-id>
  producer_squad: <producer-squad-id>
  interface_status: draft
```
