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

## §halt-protocol — Unified `blocker` envelope (v0.14)

When a skill running in `--auto` mode hits something that requires human judgment (unresolved P1 OQ blocking downstream work, vault-diff conflict, framework mismatch), it emits a structured YAML artifact called a **blocker**. The orchestrator (`/mega-sdd:orchestrate-flow`) catches blockers, pauses the chain, and surfaces the artifact in chat for the user to act on.

The envelope is uniform across types so a single consumer can handle all of them.

### Schema

```yaml
blocker:
  type: oq_blocker | diff_conflict | drift_framework_mismatch
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
