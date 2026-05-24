# Memory Schema

Full schemas for mega-sdd memory files across three scopes. Schema version `1`. Future iters that change schemas MUST bump version + provide auto-migrate path per MEMORY-OQ-1.

---

## 1. Schema version stamp

Every memory file has a header:

```yaml
---
memory_schema: 1
generated_by: mega-sdd
generated_at: <ISO8601>
scope: user | project | vault
---
```

Skills reading memory check `memory_schema`. Mismatch → invoke migration helper from `mega-sdd:memory` skill.

## 2. File format conventions

- Markdown for narrative + tables (human-reviewable, git-trackable)
- JSON only for high-volume structured data (classifier metrics, bolt outcomes)
- YAML frontmatter on every file (schema version + generation metadata)
- Every entry CITES source run (`source_run` identifier or `run_at: <ISO8601>`)

## 3. Architecture — three scopes

### USER scope (`~/.mega-sdd/memory/`)

**Cross-project**. Opt-in: NEVER auto-populated; explicit `promote` action required. Lives in user's home dir.

| File | Purpose | Format |
|---|---|---|
| `preferences.md` | Observed flag/mode picks across all projects | Markdown table per category |
| `patterns.md` | Cross-project learned patterns + pending suggestions | Markdown sections |
| `learning-log.md` | Audit log of accepted/rejected/rolled-back learnings | Markdown chronological log |
| `config.yaml` | User configuration (thresholds, opt-outs) | YAML key/value |

### PROJECT scope (`<project-root>/.mega-sdd/memory/`)

**Per-repo**. Git-trackable per-file (per MEMORY-OQ-2 resolved per-file decision). Survives vault lifecycle.

> **Path resolution (v3.4+ Iter 10 canonical, enforced v1.2.1 Iter 25)**: write-side default is `<project-root>/.mega-sdd/memory/` per `plugins/mega-sdd/references/paths.md`. Legacy path `<project-root>/.mega-sdd-memory/` honored for read-side back-compat only — when both exist, NEW writes go to `.mega-sdd/memory/`. Use `/mega-sdd:migrate-paths` to consolidate.

| File | Purpose | Format | Default gitignore |
|---|---|---|---|
| `decisions.md` | OQ resolutions, CONFLICT actions, ACCEPTs | Markdown tables | Tracked (team-shared knowledge) |
| `conventions.md` | Detected conventions (test framework, naming, error format) | Markdown sections | Tracked (team-shared) |
| `outcomes.md` | Halt patterns, retry counts, success rates per run | Markdown chronological log | Gitignored (per-dev noise) |
| `routing-outcomes.md` | Orchestrator routing decisions + outcomes log (v1.3.0+, Iter 33) | Markdown append-only rows | Gitignored (per-dev noise) |

### `<project>/.mega-sdd/memory/routing-outcomes.md` (v1.3.0+, Iter 33)

```markdown
# Routing Outcomes

## Schema

Per row: `<date> | <project-fingerprint> | <chain-used> | <duration-min> | <converged> | <halts-fired>`

## Entries

<append-only rows>
```

Schema fully defined at `plugins/mega-sdd/skills/memory/references/routing-outcomes.md`.

### VAULT scope (`<vault-path>/.memory/`)

**Per-vault, ephemeral**. Lives with vault; deleted/archived with vault per MEMORY-OQ-5 (b) — moved to `<project>/.mega-sdd/memory/archived-vaults/<vault-id>/` (v3.4+ canonical) when vault deleted.

| File | Purpose | Format |
|---|---|---|
| `classifier-accuracy.json` | Auto-classifier tag-rate + user-override metrics | JSON |
| `bind-history.md` | Per-binding-run verdicts + state map summaries | Markdown chronological log |
| `bolt-outcomes.json` | Per-bolt success/failure + Hard Rule violations | JSON |

---

## 4. Per-file schemas

### `~/.mega-sdd/memory/preferences.md`

```markdown
---
memory_schema: 1
generated_by: mega-sdd
scope: user
---

# Mega-SDD User Preferences (observed; not enforced)

## Flag defaults

| Flag | Most-picked value | Count | Last picked |
|---|---|---|---|
| OUTPUT_MODE | compact | 5/5 | 2026-05-20 |
| PRD_STATUS | draft | 4/5 | 2026-05-20 |
| --auto | true | 7/7 | 2026-05-20 |

## Project-shape preferences

| Shape | Count | Last used |
|---|---|---|
| web-app | 3 | 2026-05-15 |
| mobile-app | 2 | 2026-05-10 |

## Pending suggestions

- After 5/5 OUTPUT_MODE=compact: propose Step 0.7 default = compact. See `learning-log.md` candidate #3.
```

### `~/.mega-sdd/memory/patterns.md`

```markdown
---
memory_schema: 1
generated_by: mega-sdd
scope: user
---

# Mega-SDD Learned Patterns (cross-project, suggestions only)

## CONFLICT resolution patterns

| Pattern (regex on claim) | Most-picked resolution | Count | Confidence | Projects observed |
|---|---|---|---|---|
| `auth\|session\|login\|token` | KEEP_CODE | 8/10 | 0.80 | 3 |
| `data-model.*rename` | KEEP_VAULT | 5/5 | 1.00 | 1 |

## Hard Rule violation patterns

| Rule pattern | Violation count | Most-common resolution | Confidence |
|---|---|---|---|
| `DO NOT modify src/Models/User.php` | 3 | user_edited_unit (task_type=extend) | 0.66 |

## Recommendation acceptance patterns

| Category | ACCEPT count | OVERRIDE count | REJECT count | ACCEPT-rate |
|---|---|---|---|---|
| RFC 7807 error envelope | 4 | 0 | 0 | 1.00 |
| Latest stable Laravel | 1 | 2 | 0 | 0.33 |

## Pending suggestions

- **#1** On next auth-pattern CONFLICT: pre-fill KEEP_CODE in resolve-oq AskUserQuestion (user still confirms). Source: 8/10 observations.
- **#2** After 3rd revert of Hard Rule "DO NOT modify User.php": propose removing from Suggested Unit Hard Rules. Source: 3 violations.
- **#3** Switch RFC 7807 recommendation from `tech/recommend` to `tech/scan` (use as default). Source: 4/4 ACCEPT.
```

### `~/.mega-sdd/memory/learning-log.md`

```markdown
---
memory_schema: 1
generated_by: mega-sdd
scope: user
---

# Learning Log (audit trail)

## Learning #1 — 2026-05-15T10:00:00Z

- **Source observations**: `<proj-a>/.mega-sdd/memory/decisions.md` rows 1-5
- **Suggested action**: Pre-fill `OUTPUT_MODE=compact` at Step 0.7
- **User decision**: ACCEPT
- **Applied to**: `~/.mega-sdd/memory/config.yaml` (key: `default_output_mode: compact`)
- **Effective from**: 2026-05-15
- **Rollback**: Set `rolled_back_at: <date>` here; mega-sdd skips this learning.

## Learning #2 — 2026-05-18T14:00:00Z

- **Source observations**: ...
- **Suggested action**: ...
- **User decision**: REJECT
- **Reason**: <user-provided>
- **Effective from**: never (rejected)
```

### `~/.mega-sdd/memory/config.yaml`

```yaml
memory_schema: 1

# Thresholds for self-learning suggestions (per MEMORY-OQ-4 — configurable)
thresholds:
  classifier_override_count: 5             # default per-project; 3 cross-project
  conflict_pattern_count: 5                # consecutive same-resolution before suggesting
  hard_rule_revert_count: 3                # before suggesting rule removal
  recommend_reject_count: 3                # before suggesting flip to blocking
  convention_detection_count: 2            # before promoting "detected" to "established"
  confidence_minimum: 0.80                 # min consistency ratio before suggestion fires

# Default opt-outs
defaults:
  memory_enabled: true                     # honored unless --memory-off on skill
  cross_project_promotion: opt-in          # never automatic

# Skill-applied learnings (from learning-log.md ACCEPTs)
applied:
  - learning_id: 1
    target: default_output_mode
    value: compact
```

### `<project>/.mega-sdd/memory/decisions.md`

```markdown
---
memory_schema: 1
generated_by: mega-sdd
scope: project
---

# Project Decision History

## CONFLICT resolutions

| date | conflict-id | claim | resolution | rationale | source-run |
|---|---|---|---|---|---|
| 2026-05-20 | C-007 | Auth uses Bearer vs session cookies | KEEP_CODE | Legacy auth flow stable | bind-codebase v1.5, vault leave-mgmt v3 |

## OQ resolutions

| date | oq-id | category | resolution | source-run |
|---|---|---|---|---|
| 2026-05-20 | OQ-AR-7 | tech/recommend | ACCEPT: use RFC 7807 problem+json | bind-codebase v1.5 + resolve-oq v1.1, vault leave-mgmt v3 |
| 2026-05-20 | OQ-FL-3 | business/blocking | resolved: refund prior payments yes | resolve-oq v1.1, vault leave-mgmt v3 |

## Recommendation outcomes

| date | oq-id | recommendation | action | rationale | source-run |
|---|---|---|---|---|---|
| 2026-05-20 | OQ-AR-7 | RFC 7807 problem+json envelope | ACCEPT | matches industry standard | resolve-oq v1.1 |
```

### PRD Scope Decisions (v1.12+, Iter 28)

Records each invocation's PRD → scope mapping. Drives "silent default" on re-invocation when PRD sha256 + cwd basename match.

```markdown
## PRD Scope Decisions

| PRD sha256 | PRD title | Date | Scope picked | Architect cwd | Override count |
|---|---|---|---|---|---|
| abc123... | Order Mgmt System v1.0 | 2026-05-23 | BE | order-management-be | 0 |
| def456... | Payment Gateway v1.0 | 2026-05-24 | MW | payment-mw | 0 |
```

Write rules:
- First-time scope pick on a PRD → INSERT new row
- Re-invocation on same PRD + same scope → NO write (no change)
- Re-invocation on same PRD + DIFFERENT scope → increment `override_count` on existing row for PRD+old scope; INSERT new row for PRD+new scope

Read rules:
- On generate-intent Step 0.9: lookup PRD sha256 → if found AND cwd basename matches → propose last-used scope as silent default with confirm-once UX
- Lookup is local to project memory; cross-project PRD scope decisions tracked separately (each project has own decisions.md)

### `<project>/.mega-sdd/memory/conventions.md`

```markdown
---
memory_schema: 1
generated_by: mega-sdd
scope: project
---

# Detected Conventions

## Test framework
- **phpunit** (detected 2026-05-20 via scan-codebase v1.1 from `phpunit.xml` + `tests/` dir)
- Confirmation count: 2 (runs #1, #4)
- Status: established

## Naming conventions
- **File case**: PascalCase for PHP classes; kebab-case for routes
- **Test suffix**: `*Test.php`
- Confirmation count: 4 (runs #1-4)
- Status: established

## Error envelope
- **AS-IS**: ad-hoc `{error, message, status}` (runs #1-3)
- **DESIRED**: RFC 7807 problem+json (per OQ-AR-7 ACCEPT in run #4)
- Status: convention-in-transition (suggested hard rule pending — see Suggested Unit Hard Rules)
```

### `<project>/.mega-sdd/memory/outcomes.md`

```markdown
---
memory_schema: 1
generated_by: mega-sdd
scope: project
---

# Pipeline Outcomes Log

## Run #1 — 2026-05-15
- Vault: leave-mgmt v1
- Phases: generate-intent → scan → bind → units (4 phases; halted on conflict)
- Halt: bind_conflict on Auth claim (C-001)
- Resolution: KEEP_CODE
- Resume: Run #2

## Run #2 — 2026-05-15 (resume)
- Vault: leave-mgmt v1
- Phases: bind (re-run) → units → bolts (3 phases; completed)
- Hard Rule violations: 1 in U-007 (DO NOT modify User.php — bolt added field)
- Resolution: edited unit to task_type=extend with Migration notes
- Total duration: 47 min

## Run #3 — 2026-05-18
- Vault: leave-mgmt v2
- Phases: generate-intent (diff-vault from new PRD) → bind → units → bolts (4 phases; completed)
- Hard Rule violations: 0
- Total duration: 32 min
```

### `<vault>/.memory/classifier-accuracy.json`

```json
{
  "memory_schema": 1,
  "vault_id": "leave-management",
  "classifier_version": "1.4.0",
  "runs": [
    {
      "run_at": "2026-05-20T10:00:00Z",
      "source_skill": "generate-intent",
      "total_oqs": 48,
      "tags_emitted": {
        "tech_scan_high": 8,
        "tech_recommend_medium": 2,
        "business_blocking_high": 12,
        "business_blocking_low": 26
      },
      "user_overrides": [
        {
          "oq_id": "OQ-AR-3",
          "auto_tag": "tech_recommend_medium",
          "user_tag": "business_blocking_high",
          "user_reason": "this is a product decision, not a tech recommendation"
        }
      ],
      "accuracy_estimate": 0.979
    }
  ]
}
```

### `<vault>/.memory/bind-history.md`

```markdown
---
memory_schema: 1
generated_by: mega-sdd
scope: vault
---

# Binding History — vault leave-mgmt

## Run #1 — 2026-05-20T10:30:00Z
- claims_total: 24
- confirmed: 22
- conflict: 1
- oq: 1
- Implementation State Map: 18 IMPLEMENTED (high), 4 NEW, 2 UNKNOWN (low)
- Tech-OQ scan-resolved: 8/8
- Tech-OQ recommended: 2/2 (surfaced for review)
- Halt: bind_conflict (C-007 Auth)

## Run #2 — 2026-05-20T11:15:00Z (post-resolve-oq)
- claims_total: 24
- confirmed: 23 (C-007 resolved KEEP_CODE)
- conflict: 0
- oq: 1
- Status: completed; bound-vault produced
```

### `<vault>/.memory/bolt-outcomes.json`

```json
{
  "memory_schema": 1,
  "vault_id": "leave-management",
  "bolts": [
    {
      "unit_id": "U-001",
      "run_at": "2026-05-20T11:30:00Z",
      "task_type": "verify",
      "status": "completed",
      "duration_ms": 8400,
      "tests_passed": true,
      "hard_rules_validated": []
    },
    {
      "unit_id": "U-007",
      "run_at": "2026-05-20T12:00:00Z",
      "task_type": "create",
      "status": "halted_postflight",
      "halt_reason": "hard_rule_violated",
      "violated_rules": [
        {
          "rule": "DO NOT modify src/Models/User.php",
          "evidence": "sha256 mismatch — preflight: abc123, postflight: def456"
        }
      ],
      "resolution": "user_edited_unit",
      "resolution_at": "2026-05-20T12:30:00Z",
      "resolution_note": "Switched task_type to extend; filled Migration notes",
      "retry_status": "succeeded_on_retry_1"
    }
  ]
}
```

---

## 5. Append-only convention (per MEMORY-OQ-6)

All memory writes are append-only by default. Updates require explicit "supersedes" marker:

```markdown
| 2026-05-20 | OQ-AR-7 | tech/recommend | ACCEPT: use RFC 7807 | ... |
| 2026-05-22 | OQ-AR-7 | tech/recommend | OVERRIDE: use JSON:API errors instead | **supersedes** row above per re-evaluation in vault v4 |
```

The "supersedes" marker = explicit; the original row STAYS for audit trail. Pruning may remove superseded rows after a grace period (default 180 days; configurable in `config.yaml`).

## 6. Race-condition tolerance (per MEMORY-OQ-6)

Append-only writes are atomic if each write is a single fs.append. Concurrent runs in same project:
- Each writer appends with its own timestamp + source_run identifier
- No write conflicts at fs level
- Reader may see a partially-completed run's writes — acceptable, since runs are still in progress

If a write fails (disk full, permission), skill logs the failure and continues — memory is OPTIONAL.

### Append mechanism (v0.6+, Iter 9 Bug 3 fix)

**CRITICAL**: Memory writes MUST use POSIX append (`>>`) for atomicity, NOT Claude Code's `Write` tool (which is overwrite, not atomic-append).

**Correct (Iter 9+)**:
```bash
# Single-line append (atomic on POSIX file systems for small writes):
echo "| 2026-05-21 | OQ-AR-7 | tech/recommend | ACCEPT: ... | resolve-oq@<timestamp> |" >> "$PROJECT_MEM/decisions.md"

# Multi-line block append (uses heredoc; still single fs operation):
cat >> "$VAULT_MEM/bind-history.md" << 'APPENDEOF'

## Run #N — <ISO8601>
- claims_total: 24
- confirmed: 22
- ...
APPENDEOF
```

**Wrong (pre-Iter-9 mistake)**: Using `Write` or `Edit` tools to append. These read-modify-write the entire file → two concurrent runs would overwrite each other.

### Per-skill memory write protocol

Each writer skill's `## Memory layer` section MUST specify: "Append to `<path>` via Bash `>>` heredoc". NEVER `Write` or `Edit` for memory files.

For schema initialization (first write to a new memory file), use `Write` tool ONCE to create the file with frontmatter + empty section headers. Subsequent writes append below those headers via `>>`.

## 7. Schema migration (per MEMORY-OQ-1)

When `memory_schema` version bumps in future iters:

1. `mega-sdd:memory` skill detects mismatch on first read
2. Migration helper at `~/.mega-sdd/migrations/<from>-to-<to>.sh` (shipped per release)
3. User prompted to run migration: "Memory schema v1 → v2. Run migration? (Y/N)"
4. On confirm: backup memory dir to `~/.mega-sdd/memory.backup.YYYYMMDD/`, run migration, write log to `learning-log.md`
5. On skip: skill operates in read-only mode for that file until migration done

## 8. Memory consumption by orchestrate-flow (Iter 4 integration, per MEMORY-OQ-7)

Per AUTONOMY-OQ-7 + MEMORY-OQ-7 (both resolved single-read-at-orchestrator):

1. `/mega-sdd:auto --deep` reads all relevant memory ONCE at chain start
2. Memory slices passed to each skill via handoff YAML `metadata.memory_context` field (see `orchestrate-flow/references/handoff-contract.md` §metadata extension)
3. Skills read from in-memory slice (no disk re-read per skill)
4. Skills emit writes via handoff YAML `metadata.memory_writes` array
5. Orchestrator batches writes at chain end OR per-phase on halt (atomic per file)

This keeps autonomy mode fast AND memory-aware.

## 9. Privacy + opt-out

- `--memory-off` flag on ANY skill disables both reads and writes
- Global opt-out via `~/.mega-sdd/config.yaml` `defaults.memory_enabled: false`
- Per-scope opt-out via `<project>/.mega-sdd/memory/.disabled` (empty file; v3.4+ canonical)
- Per-vault opt-out via `<vault>/.memory/.disabled` (empty file)
- USER scope memory is plain markdown (per MEMORY-OQ-3 resolved) — do NOT run mega-sdd on shared infra without opt-out if patterns are sensitive
