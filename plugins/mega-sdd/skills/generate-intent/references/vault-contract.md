# Vault Contract

Shared definitions referenced by all `grand-design-spec` skills. **Single source of truth** — when this file changes, every skill that references it inherits the change.

> **Maintenance rule**: edits to this file are breaking changes for sibling skills. Bump the affected skill versions + CHANGELOG entry whenever you touch this file.

## §schema — `vault.json` manifest

Every `grand-design-spec` vault has a `vault.json` alongside the 7 markdown files. The markdown is human-authoritative; the JSON is a derived structural index optimized for AI consumers (Claude Code, Cursor, automated agents).

```json
{
  "vault_version": "1.0",
  "generated_at": "YYYY-MM-DDTHH:MM:SSZ",
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

### Field rules

- Every entity in `03-data-model.md` DBML must have a row in `entities[]`. Same for `flows[]` (one per `F-{prefix}-NNN`), `adrs[]` (one per `D-NNN`), `open_questions[]` (one per `OQ-{CODE}-{N}`).
- `open_questions[].status` mirrors the markdown checkbox: `[ ]` → `open`, `[x]` → `resolved`, `[~]` → `out_of_scope`. A `[ ]` with a `**Deferred**:` annotation maps to `deferred`.
- `open_questions[].category` matches the category header used in the `00-index.md` Open Questions roll-up.
- `open_questions[].resolver_owner` is best-effort — extract from the OQ entry's "Resolve: ..." or "owner" hint when present; otherwise `null`.
- `mode_migrate_after` is informational metadata for `mode=new` vaults only. For `mode=existing`, use `null`.
- Keep this file in sync with the markdown on every regeneration / `vault-diff` / `resolve-oq` round. The markdown is canonical; `vault.json` is a derived index.

### When skills must regenerate `vault.json`

- `grand-design-spec` Step 3 — initial generation.
- `resolve-oq` Step 2c step 9 — after every Resolve / Out-of-Scope / Defer outcome.
- `vault-diff` Step 6.5 — after applying approved changes (added/changed/removed entities, flows, ADRs, auto-resolved or new OQs).
- `drift-detect` — does NOT regenerate. Drift-detect produces reports only; vault.json regen happens via `resolve-oq` (for OQ-tagged actions) or manual + grand-design-spec re-run (for entity/flow/ADR additions).

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

## §halt-protocol — Unified `blocker` envelope (v0.14, extended v1.1)

When a skill running in `--auto` mode hits something that requires human judgment (unresolved P1 OQ blocking downstream work, vault-diff conflict, framework mismatch), it emits a structured YAML artifact called a **blocker**. The orchestrator (`/mega-sdd:orchestrate-flow`) catches blockers, pauses the chain, and surfaces the artifact in chat for the user to act on.

The envelope is uniform across types so a single consumer can handle all of them.

### Schema

```yaml
blocker:
  type: oq_blocker | diff_conflict | drift_framework_mismatch | bind_conflict | dep_missing | test_fail | cycle_detected | mode_migrate | cross_squad_dep_invalid | interface_ref_missing | cross_squad_ambiguous | cross_squad_interface_draft
  tag: <stable identifier — OQ-AR-1, D-007, etc.>
  priority: P1 | P2 | P3 | n/a
  context: "<what's blocked, e.g. 'Implementing F-U-001 backend' or 'Applying vault-diff Step 6'>"
  resolver_owner: "<name or role, e.g. 'Mike Patel (Eng Lead)'>"
  resolver_route: "<where to find them, e.g. 'ask in #timeoff-team'>"
  vault_version: "<current vault version, e.g. '1.1'>"
  source_skill: grand-design-spec | vault-diff | drift-detect
  # type-specific fields below
  conflict_old: "<vault state>"            # diff_conflict only
  conflict_new: "<new PRD state>"          # diff_conflict only
  options: ["supersede", "keep_vault", "capture_both"]  # diff_conflict only
  detected_framework: "<e.g. 'Java/Spring'>"  # drift_framework_mismatch only
  expected_framework: "<e.g. 'PHP/Laravel'>"  # drift_framework_mismatch only
```

### Type-specific guidance

**`oq_blocker`** — emitted by `grand-design-spec` (when generation surfaces a P1 that would block downstream tasks) or by AI consumers reading the vault non-interactively. The `tag` is the OQ identifier. `priority` is always `P1` (lower priorities don't halt).

**`diff_conflict`** — emitted by `vault-diff` Step 5 when a Resolved-OQ conflict or Decision conflict requires stakeholder input. `tag` is the OQ or ADR ID. `priority` is `n/a` (conflicts aren't priority-tagged). `conflict_old`, `conflict_new`, `options` are required.

**`drift_framework_mismatch`** — emitted by `drift-detect` Step 1.5 when the vault implies one framework but the codebase is another. `tag` is `n/a`. `priority` is `n/a`. `detected_framework` and `expected_framework` are required.

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
    source_skill: grand-design-spec
  - type: diff_conflict
    tag: OQ-DC-2
    priority: n/a
    context: "Applying vault-diff to PRD-v2.pdf"
    resolver_owner: "Mike Patel"
    resolver_route: "ask in #timeoff-team"
    vault_version: "1.1"
    source_skill: vault-diff
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
